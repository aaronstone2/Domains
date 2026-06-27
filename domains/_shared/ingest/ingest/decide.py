"""Layer 9 — decide. Turn the prioritized `strategy.recommendations` into an actual budget-constrained
decision: a 0/1 knapsack that picks the action set maximizing total priority within an effort budget.

Effort is measured in points (s=1, m=2, l=3, xl=5). `ingest decide --budget <pts>` returns the optimal
selected set, the dropped set, and the realized priority — so a quarter's capacity yields a committed plan,
not just a ranking. Deterministic (exact DP). Read-only.
"""

import duckdb

EFFORT_PTS = {"s": 1, "m": 2, "l": 3, "xl": 5}


def decide(con: duckdb.DuckDBPyConnection, budget: int) -> dict:
    rows = con.execute(
        """SELECT id, kind, statement, priority_score, effort, is_experiment
           FROM strategy.recommendations ORDER BY id"""
    ).fetchall()
    items = [
        {"id": r[0], "kind": r[1], "statement": r[2], "value": float(r[3] or 0.0),
         "w": EFFORT_PTS.get((r[4] or "m"), 2), "effort": r[4], "is_experiment": r[5]}
        for r in rows
    ]
    # 0/1 knapsack DP (values scaled to ints for exactness)
    SCALE = 10000
    cap = max(0, int(budget))
    n = len(items)
    dp = [[0] * (cap + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        w, v = items[i - 1]["w"], int(round(items[i - 1]["value"] * SCALE))
        for c in range(cap + 1):
            dp[i][c] = dp[i - 1][c]
            if w <= c:
                dp[i][c] = max(dp[i][c], dp[i - 1][c - w] + v)
    # backtrack
    chosen, c = [], cap
    for i in range(n, 0, -1):
        if dp[i][c] != dp[i - 1][c]:
            chosen.append(items[i - 1])
            c -= items[i - 1]["w"]
    chosen.reverse()
    chosen_ids = {it["id"] for it in chosen}
    dropped = [it for it in items if it["id"] not in chosen_ids]
    return {
        "budget_pts": cap,
        "spent_pts": sum(it["w"] for it in chosen),
        "realized_priority": round(sum(it["value"] for it in chosen), 4),
        "selected": [{"id": it["id"], "kind": it["kind"], "effort": it["effort"],
                      "priority": round(it["value"], 4), "is_experiment": it["is_experiment"]} for it in chosen],
        "deferred": [{"id": it["id"], "kind": it["kind"], "effort": it["effort"],
                      "priority": round(it["value"], 4)} for it in sorted(dropped, key=lambda d: -d["value"])],
    }
