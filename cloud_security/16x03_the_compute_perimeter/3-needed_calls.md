# 3 — Permissions Required by the Executable Handler

## Source evidence

The call sites below are copied from the supplied executable file `~/marlowe-package/order_processor/handler.py`, function `handler(event, context)`. The `grep -nE '\b(s3|sqs|ddb|sm)\.[a-z_]+\('` output from that file reported the exact source lines shown. These are code statements, not comments or role-policy entries.

```python
def handler(event, context):
    signing = sm.get_secret_value(SecretId=SECRET)["SecretString"]

    msg = sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)
    for m in msg.get("Messages", []):
        order = json.loads(m["Body"])

        doc = s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")["Body"].read()
        existing = ddb.get_item(TableName=TABLE, Key={"id": {"S": order["id"]}})
        ddb.put_item(TableName=TABLE, Item={"id": {"S": order["id"]}, "status": {"S": "processed"}})
        s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)
        sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])
```

This excerpt shows the actual handler and its control flow: secret retrieval and receive are unconditional; the five order-processing operations run inside the `Messages` loop.

```text
22: signing = sm.get_secret_value(SecretId=SECRET)["SecretString"]
25: msg = sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)
30: doc = s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")["Body"].read()
33: existing = ddb.get_item(TableName=TABLE, Key={"id": {"S": order["id"]}})
36: ddb.put_item(TableName=TABLE, Item={"id": {"S": order["id"]}, "status": {"S": "processed"}})
39: s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)
42: sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])
```

The code uses constants at `handler.py` lines 8–11: bucket `marlowe-orders-mc4e21`, queue URL `https://sqs.eu-west-1.amazonaws.com/500100200300/marlowe-customer-events`, table `marlowe-orders`, and secret name `marlowe/stripe-webhook-signing`. The message body is decoded before the loop's order-object and DynamoDB calls; the loop performs the seven provider operations only when a message is returned.

## Least-privilege mapping

Resource names come from the handler constants (`handler.py` lines 8–11). The account ID comes from the queue URL in those constants. The region `eu-west-1` is taken from the queue URL. Where the code does not state a region, the ARN uses the same region and is marked as derived.

| Exact source location and expression | Execution path | Required IAM action and resource |
|---|---|---|
| `handler.py:22` — `sm.get_secret_value(SecretId=SECRET)` | Every invocation, before any message is received. | `secretsmanager:GetSecretValue` on `arn:aws:secretsmanager:eu-west-1:500100200300:secret:marlowe/stripe-webhook-signing-*` (secret name from line 11; the random suffix is a wildcard, the region is derived). |
| `handler.py:25` — `sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)` | Every invocation. | `sqs:ReceiveMessage` on `arn:aws:sqs:eu-west-1:500100200300:marlowe-customer-events` (queue URL, line 9). |
| `handler.py:30` — `s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")` | Inside the message loop. | `s3:GetObject` on `arn:aws:s3:::marlowe-orders-mc4e21/orders/*` (bucket, line 8). |
| `handler.py:33` — `ddb.get_item(TableName=TABLE, Key=...)` | Inside the message loop. | `dynamodb:GetItem` on `arn:aws:dynamodb:eu-west-1:500100200300:table/marlowe-orders` (table, line 10; region derived). |
| `handler.py:36` — `ddb.put_item(TableName=TABLE, Item=...)` | Inside the message loop. | `dynamodb:PutItem` on `arn:aws:dynamodb:eu-west-1:500100200300:table/marlowe-orders` (region derived). |
| `handler.py:39` — `s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)` | Inside the message loop. | `s3:PutObject` on `arn:aws:s3:::marlowe-orders-mc4e21/processed/*`. |
| `handler.py:42` — `sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=...)` | Inside the message loop. | `sqs:DeleteMessage` on `arn:aws:sqs:eu-west-1:500100200300:marlowe-customer-events`. |

The code makes seven distinct provider calls. It makes no calls to list buckets, queues, secrets, IAM, or other tables, and no KMS, SES, or CloudWatch Logs calls. Comparison with the role's actual permissions is in `4-function_chain.md`.

The derived baseline is seven distinct API calls across S3, SQS, DynamoDB, and Secrets Manager. In the supplied handler source there are no calls to list buckets, queues, secrets, IAM users/roles, or DynamoDB tables, nor any direct KMS, SES, or CloudWatch Logs API call. Those are not needed by an executable path in this source and are compared against demonstrated role permissions in `4-function_chain.md`.
