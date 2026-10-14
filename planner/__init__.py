"""Capacity-constrained production planning (backlog vs. inventory trade-off)."""

from .io import PlanInput, read_input, write_report
from .model import Config, PlanResult, solve
from .analysis import fifo_lead_buckets

__all__ = [
    "Config",
    "PlanInput",
    "PlanResult",
    "fifo_lead_buckets",
    "read_input",
    "solve",
    "write_report",
]
