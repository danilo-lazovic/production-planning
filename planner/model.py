"""Mixed-integer model for the daily release plan.

For every part number p and day d:

    x  release (production), integer
    S  inventory up to the safety-stock target      cost safety_stock_cost / unit / day
    E  inventory above the safety-stock target      cost excess_inventory_cost / unit / day
    B  backlog (demand not yet delivered)           cost backlog_penalty / unit / day
    U  shortfall below the safety-stock target      cost safety_shortfall_cost / unit / day

    S + E - B = (S + E - B)[d-1] + x - demand          inventory balance
    S + U >= safety_stock,  0 <= S <= safety_stock     soft safety-stock target
    sum_p x[p, d] <= capacity[d]                       shared daily capacity

Backlog is the most expensive, so the solver builds ahead when capacity runs out,
but only as far ahead as needed, because every unit in stock costs something.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.optimize import Bounds, LinearConstraint, milp
from scipy.sparse import lil_matrix


@dataclass
class Config:
    backlog_penalty: float = 100.0
    excess_inventory_cost: float = 5.0
    safety_stock_cost: float = 0.1
    safety_shortfall_cost: float = 1.0
    safety_stock: float = 20.0
    initial_inventory: float = 0.0
    integer_release: bool = True
    time_limit: float = 300.0


@dataclass
class PlanResult:
    release: np.ndarray     # (pn, days)
    inventory: np.ndarray   # on-hand stock at end of day, >= 0
    backlog: np.ndarray     # undelivered demand at end of day, >= 0
    objective: float


def solve(demand: np.ndarray, capacity: np.ndarray, config: Config | None = None) -> PlanResult:
    cfg = config or Config()
    demand = np.asarray(demand, dtype=float)
    capacity = np.asarray(capacity, dtype=float)
    P, D = demand.shape
    K = 5  # variable blocks: x, S, E, B, U
    n = P * D * K

    def idx(block, p, d):
        return (block * P + p) * D + d

    X, S, E, B, U = range(K)

    c = np.zeros(n)
    for block, cost in ((S, cfg.safety_stock_cost), (E, cfg.excess_inventory_cost),
                        (B, cfg.backlog_penalty), (U, cfg.safety_shortfall_cost)):
        c[block * P * D:(block + 1) * P * D] = cost

    lb = np.zeros(n)
    ub = np.full(n, np.inf)
    ub[S * P * D:(S + 1) * P * D] = cfg.safety_stock

    rows = 2 * P * D + D
    A = lil_matrix((rows, n))
    lo = np.empty(rows)
    hi = np.empty(rows)
    r = 0
    for p in range(P):
        for d in range(D):
            # balance: S + E - B - x - (S + E - B)[d-1] = -demand
            A[r, idx(S, p, d)] = 1
            A[r, idx(E, p, d)] = 1
            A[r, idx(B, p, d)] = -1
            A[r, idx(X, p, d)] = -1
            rhs = -demand[p, d]
            if d > 0:
                A[r, idx(S, p, d - 1)] = -1
                A[r, idx(E, p, d - 1)] = -1
                A[r, idx(B, p, d - 1)] = 1
            else:
                rhs += cfg.initial_inventory
            lo[r] = hi[r] = rhs
            r += 1
            # safety target: S + U >= safety_stock
            A[r, idx(S, p, d)] = 1
            A[r, idx(U, p, d)] = 1
            lo[r], hi[r] = cfg.safety_stock, np.inf
            r += 1
    for d in range(D):
        for p in range(P):
            A[r, idx(X, p, d)] = 1
        lo[r], hi[r] = -np.inf, capacity[d]
        r += 1

    integrality = np.zeros(n)
    if cfg.integer_release:
        integrality[: P * D] = 1

    res = milp(
        c,
        constraints=LinearConstraint(A.tocsr(), lo, hi),
        bounds=Bounds(lb, ub),
        integrality=integrality,
        options={"time_limit": cfg.time_limit},
    )
    if res.x is None:
        raise RuntimeError(f"Optimization failed: {res.message}")

    sol = res.x.reshape(K, P, D)
    release = np.round(sol[X]) if cfg.integer_release else sol[X]
    on_hand = sol[S] + sol[E]
    backlog = sol[B]
    # S, E and B can be split arbitrarily at zero cost difference only if both
    # stock and backlog are positive, which is never optimal; net them anyway.
    net = on_hand - backlog
    return PlanResult(
        release=release,
        inventory=np.clip(np.round(net, 6), 0, None),
        backlog=np.clip(np.round(-net, 6), 0, None),
        objective=float(res.fun),
    )
