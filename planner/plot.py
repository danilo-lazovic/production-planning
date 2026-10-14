"""Dashboard figure."""

from __future__ import annotations

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402


def plot_dashboard(inp, result, buckets, path) -> None:
    weeks = np.unique(inp.week_of_day)
    wl = [f"CW{w:02d}" for w in weeks]
    by_week = lambda v: np.array([v[inp.week_of_day == w].sum() for w in weeks])  # noqa: E731
    end_of_week = lambda v: np.array([v[inp.week_of_day == w][-1] for w in weeks])  # noqa: E731

    produced = result.release.sum(axis=0)
    demand = inp.demand.sum(axis=0)
    days = np.arange(1, len(produced) + 1)

    fig, ax = plt.subplots(2, 3, figsize=(17, 9.5))
    fig.suptitle(f"Plan proizvodnje: {inp.path.name}", fontsize=14, fontweight="bold")

    a = ax[0, 0]
    x = np.arange(len(weeks))
    a.bar(x - 0.27, by_week(inp.capacity), 0.27, label="Kapacitet", color="#c8c8c8")
    a.bar(x, by_week(demand), 0.27, label="Tražnja", color="#f2a541")
    a.bar(x + 0.27, by_week(produced), 0.27, label="Proizvodnja", color="#2f7fc1")
    a.set_xticks(x, wl)
    a.set_title("Nedeljno: kapacitet, tražnja, proizvodnja")
    a.legend()

    a = ax[0, 1]
    a.bar(x - 0.2, end_of_week(result.inventory.sum(axis=0)), 0.4, label="Zalihe", color="#4caf50")
    a.bar(x + 0.2, end_of_week(result.backlog.sum(axis=0)), 0.4, label="Backlog", color="#d9534f")
    a.set_xticks(x, wl)
    a.set_title("Zalihe i backlog na kraju nedelje")
    a.legend()

    a = ax[0, 2]
    with np.errstate(divide="ignore", invalid="ignore"):
        util = np.where(inp.capacity > 0, produced / inp.capacity * 100, np.nan)
    a.bar(days, np.nan_to_num(util), color="#2f7fc1")
    a.axhline(100, color="crimson", ls="--", lw=1.2)
    a.set_ylim(0, 115)
    a.set_title("Dnevna iskorišćenost kapaciteta (%)")
    a.set_xlabel("Dan")

    a = ax[1, 0]
    a.step(days, np.cumsum(demand), where="post", label="Kumulativna tražnja", color="#f2a541")
    a.step(days, np.cumsum(produced), where="post", label="Kumulativna proizvodnja", color="#2f7fc1")
    a.step(days, np.cumsum(inp.capacity), where="post", label="Kumulativni kapacitet", color="#999", ls=":")
    a.set_title("Kumulativno")
    a.set_xlabel("Dan")
    a.legend()

    a = ax[1, 1]
    labels = ["Isti dan", "1 dan", "2 dana", "3+ dana", "Kasni"]
    colors = ["#2f7fc1", "#7fb3e0", "#b9d5ee", "#e6eef7", "#d9534f"]
    totals = buckets.sum(axis=0)
    a.bar(labels, totals, color=colors, edgecolor="#555")
    a.set_title("Koliko ranije je proizvedeno (jedinice, FIFO)")

    a = ax[1, 2]
    top = np.argsort(-buckets[:, 1:4].sum(axis=1))[:5][::-1]
    a.barh([inp.pn_names[i] for i in top], buckets[top, 1:4].sum(axis=1), color="#7fb3e0", label="Unapred")
    a.barh([inp.pn_names[i] for i in top], buckets[top, 4], left=buckets[top, 1:4].sum(axis=1),
           color="#d9534f", label="Kasni")
    a.set_title("Top 5 PN po proizvodnji unapred")
    a.legend()

    for a in ax.flat:
        a.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)
