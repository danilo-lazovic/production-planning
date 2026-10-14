"""Plan diagnostics."""

from __future__ import annotations

from collections import deque

import numpy as np


def fifo_lead_buckets(release, demand, initial_inventory: float = 0.0) -> np.ndarray:
    """How many days before its due date each unit was produced, FIFO.

    Returns an array (pn, 5) with units delivered
    [same day, 1 day early, 2 days early, 3+ days early, late].
    Units still undelivered at the end of the horizon count as late.
    """
    release = np.asarray(release, dtype=float)
    demand = np.asarray(demand, dtype=float)
    P, D = demand.shape
    out = np.zeros((P, 5))
    for p in range(P):
        lots = deque()  # [day produced, qty]
        if initial_inventory > 0:
            lots.append([-1_000_000, initial_inventory])  # old stock counts as 3+ early
        open_orders = deque()  # [due day, qty]
        for d in range(D):
            if release[p, d] > 0:
                lots.append([d, release[p, d]])
            if demand[p, d] > 0:
                open_orders.append([d, demand[p, d]])
            while lots and open_orders:
                lot, order = lots[0], open_orders[0]
                q = min(lot[1], order[1])
                early = order[0] - lot[0]
                if early < 0:
                    out[p, 4] += q
                else:
                    out[p, min(early, 3)] += q
                lot[1] -= q
                order[1] -= q
                if lot[1] <= 1e-9:
                    lots.popleft()
                if order[1] <= 1e-9:
                    open_orders.popleft()
        out[p, 4] += sum(q for _, q in open_orders)
    return out
