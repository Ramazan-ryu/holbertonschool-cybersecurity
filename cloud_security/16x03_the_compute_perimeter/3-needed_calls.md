# 3 — What the Function Code Needs

The baseline below is derived from `~/marlowe-package/order_processor/handler.py`, before comparing it with the role. The source comment says its listed calls are the API calls made by the handler. It makes seven API operations:

| Source line | SDK call | Required permission | Resource indicated by code |
|---:|---|---|---|
| 22 | `sm.get_secret_value(SecretId=SECRET)` | `secretsmanager:GetSecretValue` | Secret `marlowe/stripe-webhook-signing` |
| 25 | `sqs.receive_message(QueueUrl=QUEUE_URL, ...)` | `sqs:ReceiveMessage` | Queue `marlowe-customer-events` |
| 30 | `s3.get_object(Bucket=ORDERS_BUCKET, Key="orders/<id>.json")` | `s3:GetObject` | `marlowe-orders-mc4e21/orders/*` |
| 33 | `ddb.get_item(TableName=TABLE, ...)` | `dynamodb:GetItem` | Table `marlowe-orders` |
| 36 | `ddb.put_item(TableName=TABLE, ...)` | `dynamodb:PutItem` | Table `marlowe-orders` |
| 39 | `s3.put_object(Bucket=ORDERS_BUCKET, Key="processed/<id>.json", ...)` | `s3:PutObject` | `marlowe-orders-mc4e21/processed/*` |
| 42 | `sqs.delete_message(QueueUrl=QUEUE_URL, ...)` | `sqs:DeleteMessage` | Queue `marlowe-customer-events` |

The source does not call S3 bucket listing, SQS queue listing, IAM enumeration, DynamoDB table listing, KMS directly, CloudWatch Logs APIs, or SES. This is the independent baseline used in `4-function_chain.md`.
