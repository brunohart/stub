#!/usr/bin/env python3
"""Judge a performance run against perf/budgets.json (docs/decisions/004-budgets.md).

Usage: scripts/budgets.py <result.xcresult> <lane> [--markdown out.md]
  lane: "device" (the oldest phone Stub supports: the budgets) or "simulator" (regression guards for CI).

Reads every measurement out of the result bundle with xcresulttool, averages each metric over its iterations, and compares
it with the lane's ceiling. Exits 1 if any metric is over, or if a budgeted metric was not measured at all: a budget that
silently stops being measured has been lowered, and that is the one thing this file must never let happen.
"""
import json, subprocess, sys, statistics, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
args = sys.argv[1:]
if len(args) < 2:
    sys.exit(__doc__)
bundle, lane = args[0], args[1]
markdown = args[args.index("--markdown") + 1] if "--markdown" in args else None

raw = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "metrics", "--path", bundle],
                     capture_output=True, text=True, check=True).stdout
measured = {}
for test in json.loads(raw):
    name = test["testIdentifier"]
    for run in test.get("testRuns", []):
        for metric in run.get("metrics", []):
            values = metric.get("measurements") or []
            if values:
                measured[(name, metric["identifier"])] = (statistics.mean(values), metric.get("unitOfMeasurement", ""), values)

budgets = json.loads((root / "perf" / "budgets.json").read_text())
rows, failed = [], False
for b in budgets["budgets"]:
    ceiling = b.get(lane)
    if ceiling is None:
        continue
    key = (b["test"], b["metric"])
    if "match" in b:
        # Metrics whose identifiers are only seen on a phone (hitches) are found by pattern.
        import re
        found = [k for k in measured if k[0] == b["test"] and re.search(b["match"], k[1])]
        key = found[0] if found else key
    if key not in measured:
        if b.get("required", {}).get(lane, True):
            rows.append((b["name"], "not measured", ceiling, b.get("unit", ""), "FAIL"))
            failed = True
        else:
            rows.append((b["name"], "not available", ceiling, b.get("unit", ""), "n/a"))
        continue
    mean, unit, values = measured[key]
    scale = b.get("scale", 1)
    value = mean * scale
    verdict = "ok" if value <= ceiling else "OVER"
    failed |= verdict == "OVER"
    rows.append((b["name"], f"{value:.3f}", ceiling, b.get("unit", unit), verdict))

width = max(len(r[0]) for r in rows) if rows else 10
print(f"Budgets, {lane} lane ({budgets['lanes'][lane]})")
for name, value, ceiling, unit, verdict in rows:
    print(f"  {name.ljust(width)}  {str(value).rjust(12)}  ≤ {ceiling} {unit}  {verdict}")
if markdown:
    lines = [f"| Budget | Measured | Ceiling | |", "|---|---|---|---|"]
    lines += [f"| {n} | {v} | {c} {u} | {verdict} |" for n, v, c, u, verdict in rows]
    pathlib.Path(markdown).write_text("\n".join(lines) + "\n")
sys.exit(1 if failed else 0)
