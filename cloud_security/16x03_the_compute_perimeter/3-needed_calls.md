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

| Exact source location and expression | Execution path | Required IAM action and resource |
|---|---|---|
| `handler.py:22` — `sm.get_secret_value(SecretId=SECRET)` | Every invocation reads `SecretString` before receiving a message. | `secretsmanager:GetSecretValue` on `arn:aws:secretsmanager:eu-west-1:500100200300:secret:marlowe/stripe-webhook-signing-*`; the observed concrete suffix is `OZUeBE`. |
| `handler.py:25` — `sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)` | Every invocation receives at most one message before entering the message loop. | `sqs:ReceiveMessage` on `arn:aws:sqs:eu-west-1:500100200300:marlowe-customer-events`. |
| `handler.py:30` — `s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")` | Runs inside the loop only when a message exists; reads that order's source document. | `s3:GetObject` on `arn:aws:s3:::marlowe-orders-mc4e21/orders/*`. |
| `handler.py:33` — `ddb.get_item(TableName=TABLE, Key={"id": {"S": order["id"]}})` | Runs inside the message loop after reading the order document. | `dynamodb:GetItem` on `arn:aws:dynamodb:eu-west-1:500100200300:table/marlowe-orders`. |
| `handler.py:36` — `ddb.put_item(TableName=TABLE, Item={...})` | Runs inside the message loop after the lookup and writes the processed status. | `dynamodb:PutItem` on `arn:aws:dynamodb:eu-west-1:500100200300:table/marlowe-orders`. |
| `handler.py:39` — `s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)` | Runs inside the message loop after the DynamoDB write. | `s3:PutObject` on `arn:aws:s3:::marlowe-orders-mc4e21/processed/*`. |
| `handler.py:42` — `sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])` | Runs inside the message loop after the processed S3 write. | `sqs:DeleteMessage` on `arn:aws:sqs:eu-west-1:500100200300:marlowe-customer-events`. |

The derived baseline is seven distinct API calls across S3, SQS, DynamoDB, and Secrets Manager. In the supplied handler source there are no calls to list buckets, queues, secrets, IAM users/roles, or DynamoDB tables, nor any direct KMS, SES, or CloudWatch Logs API call. Those are not needed by an executable path in this source and are compared against demonstrated role permissions in `4-function_chain.md`.
