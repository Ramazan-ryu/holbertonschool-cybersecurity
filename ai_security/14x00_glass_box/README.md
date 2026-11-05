# Larkspur Assist Glass Box

Project workspace for the Larkspur Assist assessment. Run lab requests from the provided Ubuntu lab machine, where the model proxy is available at `http://localhost:8080` and Assist is available at `http://localhost`.

## Credentials

Set `GEMINI_API_KEY` in the lab terminal before running the client. The client reads it from the environment and never writes it to disk or prints it:

```sh
export GEMINI_API_KEY='your-key'
python3 client.py
```

Do not commit the key or place it in a source file.

## Task 0 client

`client.py` makes one request to the school proxy using the documented `student_id`, `mode`, temperature, and `contents` structure, then prints the response. Its request contains a `user` role set by the client. The proxy supplies its server-side system instructions; the client does not set those.

Run it only from the lab machine. The remaining numbered deliverables must contain evidence captured from your own live lab session; do not substitute examples or copied flags.
