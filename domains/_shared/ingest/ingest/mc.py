"""Layer 3 — quantitative model layer (NumPy Monte-Carlo + sensitivity).

A model is a committed YAML in domains/_shared/models/*.yaml: an output expression over named params,
each param a distribution (point/normal/triangular/lognormal/uniform) given by p10/p50/p90. `run`
samples N draws (fixed seed → reproducible), evaluates the expression, and records percentiles to
<domain>.model_runs + the assumptions to <domain>.model_assumptions. Deterministic from committed
inputs + seed, so figures are reproducible and auditable (vs. an opaque point estimate).
"""

import math
from pathlib import Path

import duckdb
import numpy as np
import yaml

from ingest.paths import SHARED_DIR

MODELS_DIR = SHARED_DIR / "models"


def load_model(model_id: str) -> dict | None:
    p = MODELS_DIR / f"{model_id}.yaml"
    return yaml.safe_load(p.read_text(encoding="utf-8")) if p.is_file() else None


def _f(x: object) -> float | None:
    # YAML parses "90.0e9" as a string (needs 9.0e+9 to be a float); coerce defensively.
    return None if x is None else float(x)


def _sample(rng: np.random.Generator, a: dict, n: int) -> np.ndarray:
    dist = a.get("distribution", "triangular")
    p10, p50, p90 = _f(a.get("p10")), _f(a.get("p50")), _f(a.get("p90"))
    if dist == "point":
        return np.full(n, p50)
    if dist == "uniform":
        return rng.uniform(p10, p90, n)
    if dist == "normal":
        sigma = (p90 - p10) / 2.563  # p90-p10 spans 2.563 sigma
        return rng.normal(p50, max(sigma, 1e-9), n)
    if dist == "lognormal":
        lp10, lp50, lp90 = math.log(p10), math.log(p50), math.log(p90)
        sigma = (lp90 - lp10) / 2.563
        return rng.lognormal(lp50, max(sigma, 1e-9), n)
    # triangular: map p10/p90 to bounds (approx left/right = p10/p90, mode = p50)
    left = p10 - (p50 - p10)
    right = p90 + (p90 - p50)
    return rng.triangular(min(left, p10), p50, max(right, p90), n)


def run(con: duckdb.DuckDBPyConnection, domain: str, model_id: str, seed: int = 42, n: int = 10000) -> dict:
    model = load_model(model_id)
    if model is None:
        return {"error": f"no model {model_id} under {MODELS_DIR}"}
    rng = np.random.default_rng(seed)
    env = {a["param"]: _sample(rng, a, n) for a in model["assumptions"]}
    env["np"] = np
    out = eval(model["expr"], {"__builtins__": {}}, env)  # noqa: S307 — expr is committed, sandboxed env
    out = np.asarray(out, dtype=float)
    p10, p50, p90 = (float(x) for x in np.percentile(out, [10, 50, 90]))
    mean, stdev = float(np.mean(out)), float(np.std(out))
    # persist assumptions + the run (idempotent on id)
    for a in model["assumptions"]:
        con.execute(
            f"INSERT INTO {domain}.model_assumptions "
            f"(id, model, param, distribution, p10, p50, p90, unit, rationale, source_ids) "
            f"VALUES (?,?,?,?,?,?,?,?,?,?) ON CONFLICT (id) DO UPDATE SET "
            f"distribution=excluded.distribution, p10=excluded.p10, p50=excluded.p50, p90=excluded.p90",
            [f"{domain}.assume.{model_id}.{a['param']}", model_id, a["param"], a.get("distribution", "triangular"),
             a.get("p10"), a.get("p50"), a.get("p90"), a.get("unit"), a.get("rationale"), a.get("source_ids", [])],
        )
    rid = f"{domain}.run.{model_id}.{seed}"
    con.execute(
        f"INSERT INTO {domain}.model_runs "
        f"(id, model, seed, n_draws, output_metric, p10, p50, p90, mean, stdev, created_at) "
        f"VALUES (?,?,?,?,?,?,?,?,?,?,CURRENT_DATE) ON CONFLICT (id) DO UPDATE SET "
        f"p10=excluded.p10, p50=excluded.p50, p90=excluded.p90, mean=excluded.mean, stdev=excluded.stdev",
        [rid, model_id, seed, n, model.get("output_metric", "output"), p10, p50, p90, mean, stdev],
    )
    return {"run_id": rid, "metric": model.get("output_metric"), "p10": p10, "p50": p50, "p90": p90,
            "mean": mean, "stdev": stdev}
