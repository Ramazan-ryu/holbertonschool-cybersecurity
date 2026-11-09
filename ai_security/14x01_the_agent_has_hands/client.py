#!/usr/bin/env python3
"""Small credential-safe client for the Puppet-Strings lab API."""

import argparse
import json
import os
import sys
from typing import Any

import requests


BASE_URL = os.environ.get("LARKSPUR_URL", "http://localhost").rstrip("/")


def call(method: str, path: str, payload: dict[str, Any] | None = None) -> int:
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        print("Set GEMINI_API_KEY in the lab environment first.", file=sys.stderr)
        return 2

    try:
        response = requests.request(
            method,
            f"{BASE_URL}{path}",
            headers={"x-goog-api-key": key},
            json=payload,
            timeout=120,
        )
    except requests.RequestException as exc:
        print(f"Request failed: {exc}", file=sys.stderr)
        return 1

    print(f"HTTP {response.status_code}")
    try:
        print(json.dumps(response.json(), indent=2, ensure_ascii=False))
    except ValueError:
        print(response.text)
    return 0 if response.ok else 1


def parse_history(raw: str) -> list[dict[str, Any]]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise argparse.ArgumentTypeError(f"invalid JSON history: {exc}") from exc
    if not isinstance(value, list):
        raise argparse.ArgumentTypeError("history must be a JSON array")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    chat = sub.add_parser("chat", help="send a chat request")
    chat.add_argument("--message", required=True)
    chat.add_argument("--ticket")
    chat.add_argument("--history", type=parse_history, default=[])
    chat.add_argument("--session", default="default")

    for name, path in (("kb-ticket", "/kb/ticket"), ("kb-faq", "/kb/faq-suggestion")):
        ingest = sub.add_parser(name, help=f"ingest content through {path}")
        ingest.add_argument("--title", required=True)
        ingest.add_argument("--body", required=True)

    search = sub.add_parser("kb-search", help="inspect retrieval without a model call")
    search.add_argument("--q", required=True)

    victim = sub.add_parser("victim", help="trigger one scripted victim query")
    victim.add_argument("--query-id", type=int, choices=range(6), required=True)

    sub.add_parser("victim-log", help="read recent victim runs")
    sub.add_parser("metrics", help="read lab metrics")
    sub.add_parser("config", help="read current configuration")
    sub.add_parser("reset-config", help="reset retest settings")

    audit = sub.add_parser("audit", help="read a filtered audit log")
    audit.add_argument("--kind", required=True)

    config_set = sub.add_parser("set-config", help="set allowed retest knobs")
    config_set.add_argument("--json", required=True, help="JSON object containing only fields being changed")

    approve = sub.add_parser("approve", help="approve a queued tool action")
    approve.add_argument("--approval-id", required=True)

    args = parser.parse_args()
    if args.command == "chat":
        payload: dict[str, Any] = {
            "message": args.message,
            "history": args.history,
            "session": args.session,
        }
        if args.ticket is not None:
            payload["ticket"] = args.ticket
        return call("POST", "/chat", payload)

    if args.command in ("kb-ticket", "kb-faq"):
        path = "/kb/ticket" if args.command == "kb-ticket" else "/kb/faq-suggestion"
        return call("POST", path, {"title": args.title, "body": args.body})
    if args.command == "kb-search":
        return call("GET", f"/kb/search?q={requests.utils.quote(args.q, safe='')}")
    if args.command == "victim":
        return call("POST", "/victim/run", {"query_id": args.query_id})
    if args.command == "victim-log":
        return call("GET", "/victim/log")
    if args.command == "audit":
        return call("GET", f"/audit/log?kind={requests.utils.quote(args.kind, safe='')}")
    if args.command == "metrics":
        return call("GET", "/metrics")
    if args.command == "config":
        return call("GET", "/config")
    if args.command == "reset-config":
        return call("POST", "/config/reset")
    if args.command == "set-config":
        try:
            payload = json.loads(args.json)
        except json.JSONDecodeError as exc:
            print(f"Invalid config JSON: {exc}", file=sys.stderr)
            return 2
        if not isinstance(payload, dict):
            print("Config payload must be a JSON object.", file=sys.stderr)
            return 2
        return call("POST", "/config", payload)
    if args.command == "approve":
        return call("POST", "/tools/approve", {"approval_id": args.approval_id})
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
