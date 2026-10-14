"""Build the daily production plan from a planning workbook.

    python -m planner                          # data/primer_ulaz.xlsx
    python -m planner moj_plan.xlsx --backlog-penalty 200 --safety-stock 0
"""

from __future__ import annotations

import argparse
from dataclasses import fields
from pathlib import Path

from .analysis import fifo_lead_buckets
from .io import read_input, write_report
from .model import Config, solve

REPO_ROOT = Path(__file__).resolve().parents[1]


def main(argv=None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input", nargs="?", type=Path, default=REPO_ROOT / "data" / "primer_ulaz.xlsx")
    p.add_argument("--out", type=Path, default=REPO_ROOT / "results")
    p.add_argument("--no-plot", action="store_true")
    for f in fields(Config):
        flag = "--" + f.name.replace("_", "-")
        if f.type in ("bool", bool):
            p.add_argument(flag, type=lambda s: s.lower() in ("1", "true", "yes", "da"), default=f.default)
        else:
            p.add_argument(flag, type=float, default=f.default)
    args = p.parse_args(argv)
    cfg = Config(**{f.name: getattr(args, f.name) for f in fields(Config)})

    inp = read_input(args.input)
    P, D = inp.demand.shape
    print(f"Učitano: {P} PN, {D} dana ({inp.week_of_day[-1]} nedelja), "
          f"tražnja {inp.demand.sum():.0f}, kapacitet {inp.capacity.sum():.0f}")

    result = solve(inp.demand, inp.capacity, cfg)
    buckets = fifo_lead_buckets(result.release, inp.demand, cfg.initial_inventory)

    print(f"Proizvedeno: {result.release.sum():.0f}")
    print(f"Backlog (zbir po danima): {result.backlog.sum():.0f}, na kraju: {result.backlog[:, -1].sum():.0f}")
    print(f"Zalihe (zbir po danima): {result.inventory.sum():.0f}")
    print(f"Isporučeno na vreme: {buckets[:, :4].sum():.0f}, sa kašnjenjem: {buckets[:, 4].sum():.0f}")
    print(f"Vrednost funkcije cilja: {result.objective:.1f}")

    stem = args.input.stem
    xlsx = write_report(inp, result, buckets, args.out / f"plan_{stem}.xlsx")
    print(f"\nSačuvano: {xlsx}")
    if not args.no_plot:
        from .plot import plot_dashboard

        png = args.out / f"plan_{stem}.png"
        plot_dashboard(inp, result, buckets, png)
        print(f"Sačuvano: {png}")


if __name__ == "__main__":
    main()
