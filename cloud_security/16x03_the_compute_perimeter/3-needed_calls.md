# 3 — Code-Derived Permission Requirements

## Method

I derived this baseline from the executable `handler(event, context)` in `~/marlowe-package/order_processor/handler.py` before comparing it with the IAM role. The function first retrieves the signing secret and then receives a queue message. Only when `Messages` contains an item does the loop parse its body and perform the order reads/writes and acknowledgement. The constants at lines 8–11 fix the resource names and prefixes below.

## Calls reached from the handler

| Source locator and executable path | SDK call and exact code evidence | Least-privilege IAM requirement |
|---|---|---|
| `~/marlowe-package/order_processor/handler.py`, module constant `SECRET` (line 11), then `handler()` line 22; reached on every handler invocation before queue receive | `sm.get_secret_value(SecretId=SECRET)["SecretString"]` | `secretsmanager:GetSecretValue` on secret `arn:aws:secretsmanager:eu-west-1:500100200300:secret:marlowe/stripe-webhook-signing-*` (the account response showed the concrete suffix `OZUeBE`). |
| Same file, module constant `QUEUE_URL` (line 9), then `handler()` line 25; reached on every invocation | `sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1)` | `sqs:ReceiveMessage` on `arn:aws:sqs:eu-west-1:500100200300:marlowe-customer-events`. |
| Same file, inside `for m in msg.get("Messages", [])`, `handler()` line 30; reached only when receive returns a message, after its body is decoded at line 28 | `s3.get_object(Bucket=ORDERS_BUCKET, Key=f"orders/{order['id']}.json")` | `s3:GetObject` on `arn:aws:s3:::marlowe-orders-mc4e21/orders/*`. The code controls the bucket and the `orders/` prefix; the order ID is message data. |
| Same file, same message loop, `handler()` line 33; reached after the S3 read | `ddb.get_item(TableName=TABLE, Key={"id": {"S": order["id"]}})` | `dynamodb:GetItem` on table ARN `arn:aws:dynamodb:eu-west-1:500100200300:table/marlowe-orders`. |
| Same file, same message loop, `handler()` line 36; reached after the lookup | `ddb.put_item(TableName=TABLE, Item={...})` | `dynamodb:PutItem` on `arn:aws:dynamodb:eu-west-1:500100200300:table/marlowe-orders`. |
| Same file, same message loop, `handler()` line 39; reached after the DynamoDB write | `s3.put_object(Bucket=ORDERS_BUCKET, Key=f"processed/{order['id']}.json", Body=doc)` | `s3:PutObject` on `arn:aws:s3:::marlowe-orders-mc4e21/processed/*`. |
| Same file, same message loop, `handler()` line 42; reached after the processed copy is written | `sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])` | `sqs:DeleteMessage` on `arn:aws:sqs:eu-west-1:500100200300:marlowe-customer-events`. |

## Calls not in the code baseline

The source contains no `list_buckets`, `list_queues`, `list_secrets`, IAM enumeration, `list_tables`, KMS, SES, or broad logging API calls. It also contains no code path that assumes another role. Those actions cannot be justified by the handler. This seven-action, four-service set is the independent baseline for the execution-role comparison in `4-function_chain.md`; it is derived from executable statements, not comments, names, or the existing policy.
