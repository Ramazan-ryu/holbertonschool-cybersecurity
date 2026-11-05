#!/usr/bin/env python3
"""Minimal client for the course Gemini proxy."""

import json
import os
import sys

import requests


PROXY = "http://localhost:8080"
KEY = os.environ["GEMINI_API_KEY"]  # read at runtime; never write the key to a file


def ask(text, temperature=0.7, history=None):
    contents = list(history or []) + [
        {"role": "user", "parts": [{"text": text}]}
    ]
    response = requests.post(
        f"{PROXY}/v1/generate",
        headers={"x-goog-api-key": KEY},
        json={
            "student_id": "student",
            "mode": "probe",
            "contents": contents,
            "temperature": temperature,
            "max_output_tokens": 200,
        },
        timeout=120,
    )
    if response.status_code != 200:
        sys.exit(f"HTTP {response.status_code}: {response.text}")
    return response.json()


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Say hello in five words."
    print(json.dumps(ask(prompt), indent=2))
