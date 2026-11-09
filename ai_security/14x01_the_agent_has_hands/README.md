# Puppet-Strings — Larkspur Assist assessment

This workspace is for the authorized Puppet-Strings lab at `10.42.234.168`. Run the client from the provided Ubuntu lab machine, where Assist is available at `http://localhost`.

## Credentials

Set the Gemini key in the lab shell at runtime. Do not put it in a source file or deliverable:

```sh
export GEMINI_API_KEY='your-key'
```

## Client

`client.py` sends requests to Assist and prints the complete JSON response, including `tool_calls`, `retrieved`, token use, and failure details. It supports chat, knowledge-base ingestion/search, victim runs/logs, audit, metrics, configuration, and approval endpoints. Review all returned side effects and preserve live evidence in the task deliverables.

Examples from the lab machine:

```sh
python3 client.py chat --message "What is the status of my order?"
python3 client.py kb-search --q "order status"
python3 client.py victim --query-id 0
python3 client.py config
```

## Lab boundaries

Use only the provided lab. Keep tools and retrieval at the supplied configuration except when a task explicitly asks for a mitigation retest. Reset configuration after retests where appropriate. Dynamic flags and audit events must come from this live lab session; do not substitute examples or values from another run.

Deliverables belong under `ai_security/14x01_the_agent_has_hands` in the course repository. Each file must end with a newline.
