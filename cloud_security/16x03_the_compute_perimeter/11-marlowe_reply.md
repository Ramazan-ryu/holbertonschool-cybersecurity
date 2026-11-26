# 11 — Reply to Marlowe Commerce

Dear Marlowe team,

Image import reached tokenless metadata and returned credentials for `marlowe-web-instance-role`. They read an order, received a queue message, retrieved the signing secret, and assumed `marlowe-order-processor-role`. The handler has seven source calls; a role session accepted six extra inventory calls. Lambda configuration failed, so the deployed function-role attachment is unverified.

Both paths end with code using a workload identity: SSRF exposed the instance role; code in the order processor would use its execution role if attached. Package exploitability was not demonstrated. Application, platform or cloud, and security owners should jointly approve identity, metadata mode, and code-derived permissions before deployment and after code, dependency, configuration, or role changes.

Use one detection: alert when workload-role use falls outside an owner-approved runtime and origin baseline. Record caller, target role, session, time, source, and network or service context; correlate role assumptions with `GetCallerIdentity` and later API calls. The observed instance-to-function role transition is a review signal, not proof of misuse. The export is lab-generated; `127.0.0.1` appears for workload and reviewer events and does not prove physical origin.

Approved tests, deployment tools, proxies, failover, and architecture changes can create valid alerts. Maintaining exceptions and investigating them takes staff time; no false-positive rate is known. Strong metadata mode blocked the tested request, but image import still accepts caller-controlled URLs and needs destination checks and egress limits. An authorized administrator must apply the role policy and test denied excess access plus a successful required call.

Regards,
Latchkey Security
