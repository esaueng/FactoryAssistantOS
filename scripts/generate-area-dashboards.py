#!/usr/bin/env python3
"""Generate read-only Factory Assistant area dashboards from a site model."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import yaml


class IndentedDumper(yaml.SafeDumper):
    """Emit block sequences indented enough for strict yamllint."""

    def increase_indent(self, flow: bool = False, indentless: bool = False) -> None:
        return super().increase_indent(flow, False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate native read-only Lovelace area dashboards from "
            "onboarding/site_model.example.yaml."
        )
    )
    parser.add_argument(
        "--site-model",
        required=True,
        type=Path,
        help="Path to a Factory Assistant site_model YAML file.",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Output Lovelace dashboard YAML path.",
    )
    return parser.parse_args()


def load_site_model(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise SystemExit("site model must be a YAML mapping")
    return data


def first_matching(entities: list[str], suffix: str) -> str | None:
    for entity in entities:
        if entity.endswith(suffix):
            return entity
    return None


def machine_cards(line: dict[str, Any]) -> list[dict[str, Any]]:
    cards: list[dict[str, Any]] = []
    for cell in line.get("cells") or []:
        for station in cell.get("stations") or []:
            for machine in station.get("machines") or []:
                entities = machine.get("entities") or []
                status_entity = first_matching(entities, "_running")
                if not status_entity:
                    raise SystemExit(f"machine {machine.get('id')} lacks a *_running entity")
                cards.append(
                    {
                        "type": "custom:fa-machine-card",
                        "title": machine["name"],
                        "line": line["name"],
                        "cell": cell["name"],
                        "machine": machine["name"],
                        "status_entity": status_entity,
                        "tap_action": "detail_only",
                        "control_affordances_allowed": False,
                    }
                )
    return cards


def alert_cards(line: dict[str, Any]) -> list[dict[str, Any]]:
    alerts: list[dict[str, Any]] = []
    for cell in line.get("cells") or []:
        for station in cell.get("stations") or []:
            for machine in station.get("machines") or []:
                for entity in machine.get("entities") or []:
                    if entity.endswith("_alert"):
                        alerts.append(
                            {
                                "entity": entity,
                                "name": f"{machine['name']} alert",
                                "severity": "warning",
                            }
                        )
    return alerts


def telemetry_entities(line: dict[str, Any]) -> list[str]:
    entities: list[str] = []
    for cell in line.get("cells") or []:
        for station in cell.get("stations") or []:
            for machine in station.get("machines") or []:
                for entity in machine.get("entities") or []:
                    if entity.startswith("sensor.") and entity not in entities:
                        entities.append(entity)
    return entities


def build_dashboard(model: dict[str, Any]) -> dict[str, Any]:
    views: list[dict[str, Any]] = []
    for line in model.get("lines") or []:
        cards: list[dict[str, Any]] = []
        cards.extend(machine_cards(line))
        cards.append(
            {
                "type": "custom:fa-andon-view",
                "title": f"{line['name']} alerts",
                "acknowledge_is_bookkeeping": True,
                "safety_alarm_claim_allowed": False,
                "alerts": alert_cards(line),
            }
        )

        history_entities = telemetry_entities(line)
        if history_entities:
            cards.append(
                {
                    "type": "history-graph",
                    "title": f"{line['name']} telemetry - last 8 hours",
                    "hours_to_show": 8,
                    "entities": history_entities,
                }
            )

        cards.append(
            {
                "type": "markdown",
                "content": (
                    "**Factory Assistant is a monitoring tool, not a safety device.** "
                    "Generated area dashboards are read-only and provide no machine "
                    "control affordances."
                ),
            }
        )
        views.append(
            {
                "title": line["name"],
                "path": line["id"],
                "icon": "mdi:factory",
                "cards": cards,
            }
        )

    return {
        "title": "Factory Assistant area dashboards",
        "views": views,
    }


def write_dashboard(path: Path, dashboard: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    yaml_text = yaml.dump(
        dashboard,
        Dumper=IndentedDumper,
        allow_unicode=False,
        sort_keys=False,
        width=88,
    )
    header = (
        "# Factory Assistant generated area dashboards.\n"
        "# Generated from onboarding/site_model.example.yaml by\n"
        "# scripts/generate-area-dashboards.py. Monitoring only; no control paths.\n"
    )
    path.write_text(header + yaml_text, encoding="utf-8")


def main() -> None:
    args = parse_args()
    model = load_site_model(args.site_model)
    write_dashboard(args.output, build_dashboard(model))


if __name__ == "__main__":
    main()
