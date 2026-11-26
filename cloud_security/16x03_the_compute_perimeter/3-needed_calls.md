# 3 — Provider Calls in the Handler Source

## Method

I read `~/marlowe-package/order_processor/handler.py` before comparing its calls with any role policy. The excerpt below reproduces each provider SDK call from the executable body of `handler(event, context)`; the inline line numbers are the source line numbers reported by `grep -n` on that file. Each row then maps that exact expression to its provider operation and execution condition. The operation names and locations come from executable statements, not the function's description or the role configuration.

```python
def handler(event, context):
    signing = sm.get_secret_value(SecretId=SECRET)                         # line 22
    msg = sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)  # line 25
    for m in msg.get("Messages", []):
        order = json.loads(m["Body"])
        doc = s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")["Body"].read()  # line 30
        existing = ddb.get_item(TableName=TABLE, Key={"id": {"S": order["id"]}})                  # line 33
        ddb.put_item(TableName=TABLE, Item={"id": {"S": order["id"]}, "status": {"S": "processed"}})  # line 36
        s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)        # line 39
        sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])                   # line 42
```

The function retrieves the signing secret and receives a queue message before entering the message loop. The five remaining calls are reached only when `receive_message` returns at least one message. No provider call is made for an empty `Messages` list by the loop body.

## Calls observed

| Exact source locator | Executable expression | Provider operation | Execution path |
|---|---|---|---|
| `handler.py:22`, `handler` | `sm.get_secret_value(SecretId=SECRET)` | Secrets Manager `GetSecretValue` | Every invocation reaches this statement before queue receive. |
| `handler.py:25`, `handler` | `sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)` | SQS `ReceiveMessage` | Every invocation reaches this statement after the secret read. |
| `handler.py:30`, `handler` message loop | `s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")` | S3 `GetObject` | Runs once per returned message, after its body is decoded as JSON. |
| `handler.py:33`, `handler` message loop | `ddb.get_item(TableName=TABLE, Key=...)` | DynamoDB `GetItem` | Runs once per returned message. |
| `handler.py:36`, `handler` message loop | `ddb.put_item(TableName=TABLE, Item=...)` | DynamoDB `PutItem` | Runs once per returned message. |
| `handler.py:39`, `handler` message loop | `s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)` | S3 `PutObject` | Runs once per returned message, after the order document is fetched. |
| `handler.py:42`, `handler` message loop | `sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])` | SQS `DeleteMessage` | Runs once per returned message, after the processing operations. |

The source therefore contains seven distinct provider operations across Secrets Manager, SQS, S3, and DynamoDB. This list is a description of what the supplied source calls. It does not claim successful execution, decide what the current role allows, or treat other permissions as required merely because they appear plausible.

## Targets written in source

The constants are declared at `handler.py:8–11`: bucket `marlowe-orders-mc4e21`, queue URL `https://sqs.eu-west-1.amazonaws.com/500100200300/marlowe-customer-events`, table `marlowe-orders`, and secret name `marlowe/stripe-webhook-signing`. The S3 key expressions use the `orders/` and `processed/` prefixes. These values describe the handler's arguments; effective IAM authorization and resource reach are assessed separately in `4-function_chain.md`.
