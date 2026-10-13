#!/usr/bin/env python3
"""Render the Grafana import JSON with environment-specific defaults."""
import json
import os
import re
from pathlib import Path

source = Path(__file__).with_name("api-usage-billing.json")
dashboard = json.loads(source.read_text())

def set_custom_variable(name: str, value: str) -> None:
    for variable in dashboard["templating"]["list"]:
        if variable["name"] == name:
            variable["query"] = value
            variable["current"] = {"text": value, "value": value}
            variable["options"] = [{"selected": True, "text": value, "value": value}]
            return
    raise SystemExit(f"Dashboard variable not found: {name}")

job = os.environ.get("METRICS_JOB", "ai-gateway/internal-ai-gateway")
reporter = os.environ.get("METRICS_REPORTER", "source")
price = os.environ.get("ESTIMATED_PRICE_PER_REQUEST", "0.05")
currency = os.environ.get("CURRENCY", "USD").upper()
try:
    if float(price) < 0:
        raise ValueError
except ValueError:
    raise SystemExit("ESTIMATED_PRICE_PER_REQUEST must be a non-negative number")
if not re.fullmatch(r"[A-Z]{3}", currency):
    raise SystemExit("CURRENCY must be a three-letter ISO-style code, for example USD")

set_custom_variable("job", job)
set_custom_variable("reporter", reporter)
set_custom_variable("price_per_request", price)
dashboard["panels"][1]["fieldConfig"]["defaults"]["unit"] = f"currency{currency}"
dashboard["uid"] = os.environ.get("GRAFANA_DASHBOARD_UID", dashboard["uid"])
dashboard["title"] = os.environ.get("GRAFANA_DASHBOARD_TITLE", dashboard["title"])
print(json.dumps(dashboard, indent=2))
