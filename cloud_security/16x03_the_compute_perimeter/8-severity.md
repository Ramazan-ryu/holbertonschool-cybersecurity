# 8 — Severity Assessment

## Finding 1: instance identity exposed through the storefront fetch

**Severity: High.** A request to the catalog image-import feature returned an instance metadata credential document. STS confirmed the principal as `marlowe-web-instance-role`. Calls using that identity successfully read an order document, received a customer-events message, and retrieved the Stripe webhook-signing secret. This rating is based on the exposed identity and proven data reach, not on the URL-fetch weakness in isolation. `iam:ListUsers` was denied, and no write or account-administration capability was demonstrated for this identity.

The exposure depends on the metadata service accepting the tokenless metadata path. The exact forged-request refusal after strong mode was not recorded, so the control is not yet validated as an effective mitigation.

## Finding 2: function execution role broader than the handler's API needs

**Severity: High.** The handler has seven API operations across four services. The attached `v1` policy also grants wildcard S3, DynamoDB, and SQS actions; IAM enumeration; secret listing; KMS decrypt; all CloudWatch Logs actions; and SES sending, all with wildcard resource scope. Live calls proved enumeration of two buckets, one secret, one queue, and four IAM users. Other broad actions are policy evidence, not individually executed proof.

The risk is the reach of code executing under `marlowe-order-processor-role`, including any compromised dependency or function path. The proposed narrowing policy exists in the repository, but it was not applied or verified; the current severity therefore receives no remediation credit.

## Rating limits

No CVSS score is assigned because the supplied evidence does not establish all scoring inputs, including external authentication boundaries and full business impact. The ratings should be revisited after the metadata after-test, role policy update, and audit reconstruction are complete.
