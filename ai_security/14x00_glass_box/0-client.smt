Task 0 — successful request through the school proxy

Request:
POST http://localhost:8080/v1/generate
x-goog-api-key: loaded from the GEMINI_API_KEY environment variable at runtime (value omitted)
JSON body:
{"student_id":"student","mode":"probe","temperature":0.7,"max_output_tokens":200,"contents":[{"role":"user","parts":[{"text":"Say hello in five words."}]}]}

HTTP 200; the client exits on any non-200 response. The proxy returned this completed response:
{
  "text": "Hello, it is nice meeting.",
  "model": "gemini-3.1-flash-lite",
  "tokens_consumed": {
    "prompt": 7,
    "output": 7,
    "total": 14
  },
  "finish_reason": "STOP",
  "temperature": 0.7,
  "request_structure": [
    {
      "role": "user",
      "chars": 24
    }
  ]
}

Roles visible in the request structure, one per line:
user — set by my client in `contents`; my client controls this role and its message text.

This probe request contains one client-authored user message. It does not show a separate system or model role. The model's generated response is output, not a request role set by my client. The API key is read from the runtime environment and is not recorded here.
