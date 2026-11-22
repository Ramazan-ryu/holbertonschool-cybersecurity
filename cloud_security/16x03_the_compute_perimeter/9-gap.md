The Gap Is the Normal State

Measured distance. The function handler requires seven API actions. The attached policy grants those seven, plus six explicit non-code actions and four service wildcards (s3:*, dynamodb:*, sqs:*, logs:*), all on Resource: "*". Five non-code actions were confirmed by successful calls under the role: listing buckets, secrets, queues, IAM users and role details. Untested grants are excluded from the measured result.

Mechanism. No one was careless. The role was scoped against the code at deployment, under deadline pressure, using the widest convenient permissions. The code then changed and the role did not. Nothing pushes it back: a deployment does not fail because a role keeps an unused grant, and nobody is alerted when the code stops using one. Permissions accumulate.

Why it is invisible. An over-broad role never produces an error. No request fails, no alert fires, and no user complains. It is the only class of misconfiguration that is fully silent in normal operation. It surfaces only when effective permissions are deliberately compared with a baseline derived independently from the code.

What Marlowe would need to do. Maintain the required-call baseline derived from the handler source, including resource ARNs. On every deployment and in quarterly reviews, compare each execution role's effective permissions against it and fail the build on any extra grant. Validate each reduction with positive tests (required calls still succeed) and negative tests (unrequired calls are denied). Give every role a named owner who reviews exceptions.

Cost. Baseline upkeep and test maintenance take ongoing engineering time. CI gates slow releases and will block deployments until the baseline is updated. Resource-level scoping will break some working code on first run, and the team must fix those failures. Regression risk does not disappear. This is not free. Without it, the gap returns, because the mechanism that created it is still running.
