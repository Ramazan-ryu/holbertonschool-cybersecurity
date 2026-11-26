# Trellis Software: audit trail reconstruction

## 1. Source

**Audit file.** `/home/latchkey/trellis-audit.jsonl` (881 lines). A byte-identical copy exists at `/opt/trellis/master/trellis-audit.jsonl` (md5 `161da0857299b4b81f469624e675d2fb`). One source is used.

**Properties (verified).**
- One JSON audit event per line. Line numbers are 1-based physical lines (`nl -v824`).
- Time range: `2026-10-19T00:01:00.000000Z` to `2026-10-25T23:53:00.000000Z`.
- Audit level `Metadata`, stage `ResponseComplete`. Request and response bodies are not recorded.
- The fields `sourceIPs`, `userAgent`, `requestURI`, `requestObject`, and `responseObject` are absent from the records checked, including line 829.
- All 881 events have `objectRef.namespace`.

**Archive search (on this machine).** Only the two copies above and unrelated system logs were found. No Kubernetes audit data before 2026-10-19 is present here. The cluster was not searched, because no kubeconfig is available.

## 2. Material events: what the record contains

Each row is retrievable from the file by its auditID. The command for each row is in Section 7.

| Line | auditID | requestReceivedTimestamp | User | Verb | apiGroup | Resource | Namespace | Name | Code | Decision |
|---|---|---|---|---|---|---|---|---|---|---|
| 826 | `fc732b41831c35c` | 2026-10-25T14:00:00.000000Z | `system:serviceaccount:build:ci-runner` | create | (core) | pods | platform | `debug-shell-x7k2` | 200 | allow |
| 828 | `c22c0094a42c174` | 2026-10-25T14:02:00.000000Z | `system:serviceaccount:build:ci-runner` | get | (core) | serviceaccounts | platform | `controller-admin` | 200 | allow |
| 829 | `a55c4295ef26154` | 2026-10-25T14:05:00.000000Z | `system:serviceaccount:platform:controller-admin` | list | (core) | secrets | kube-system | (empty) | 200 | allow |
| 830 | `50169ea038b7cff` | 2026-10-25T14:06:00.000000Z | `system:serviceaccount:platform:controller-admin` | get | (core) | secrets | prod | `orders-api-token` | 200 | allow |

The four events span six minutes, from 14:00:00Z to 14:06:00Z.

**What is not in the record.** The request scope of row 829 is not in the record. The record shows `objectRef.namespace: kube-system` and an empty name. It does not show whether the request was limited to `kube-system` or covered all namespaces, because the request URI and request body are not recorded at this audit level. This analysis does not infer that scope. It remains open (Section 5).

## 3. Identity context (verified)

### 3.1 `build/ci-runner` (257 events)

| Verb and resource | Count | Namespace |
|---|---|---|
| get pods | 89 | build |
| get configmaps | 87 | build |
| list configmaps | 74 | build |
| get services | 2 | build |
| watch endpoints | 1 | build |
| list pods | 1 | build |
| list deployments | 1 | build |
| get serviceaccounts | 1 | platform (row 828) |
| create pods | 1 | platform (row 826) |

Reads of configmaps and pods are 250 of 257 events (97%). The only `create` by this identity in the file is row 826. The identity never touches a Secret.

### 3.2 `platform/controller-admin` (9 events)

Before the chain (7 events, all in `platform`, none on Secrets):

| Timestamp | Verb | Resource | Name | auditID |
|---|---|---|---|---|
| 2026-10-19T10:09:00Z | get | configmaps | obj-5881 | `0670a1f86d65888` |
| 2026-10-20T11:29:00Z | list | pods | obj-2000 | `a428bd42383a986` |
| 2026-10-22T09:42:00Z | get | configmaps | obj-8375 | `f13d03690537ceb` |
| 2026-10-23T00:26:00Z | get | services | obj-4405 | `cf21d524315298b` |
| 2026-10-24T23:20:00Z | get | configmaps | obj-9673 | `87492ff0ec6b2f0` |
| 2026-10-25T00:27:00Z | list | deployments | obj-2873 | `4b7805fc302641d` |
| 2026-10-25T06:16:00Z | watch | endpoints | obj-3083 | `17820f1ba6c573e` |

The chain (rows 829 and 830) holds this identity's only Secret events in the file, and its first events outside `platform`.

After the chain: 2026-10-25T18:06:00Z, `watch endpoints` in `platform` (`obj-3571`, auditID `6a16ed2a75f8ebb`). No later events appear for this identity.

### 3.3 Secret access across the file

Exactly two events have `objectRef.resource: secrets`: rows 829 and 830. Both are by `platform/controller-admin`. No other identity touches Secrets during the week.

### 3.4 Debug pod

`debug-shell-x7k2` appears once: row 826, `create`. No `exec`, delete, or read of this pod is recorded.

## 4. Earliest structural anomaly

**Detection point: row 826.** `system:serviceaccount:build:ci-runner` creates a pod (`pods`, core group) in namespace `platform`. auditID `fc732b41831c35c`, 2026-10-25T14:00:00Z, response 200, decision allow.

**Why it is abnormal for this identity (within this file).** Its activity is 97% reads of configmaps and pods in `build`. Its only `create` in 257 events is row 826. It has no earlier activity outside `build`. The action differs on three counts: verb (`create`, unique), resource (`pods`, not a read), and namespace (`platform`, not used before in the file).

**Why it is earlier and more useful than the Secret read.** Row 826 is the first event in the chain. Row 828 follows two minutes later, the first Secret access (row 829) five minutes later, and the high-impact read (row 830) six minutes after the start. Alerting on row 830 fires once the damage is possible, and it would fire on any legitimate use of that identity. A rule keyed on row 826 fires before any Secret is touched.

**The rule does not depend on the object name.** It keys on (identity, verb, resource, namespace): `build/ci-runner`, `create`, `pods`, `platform`. The name `debug-shell-x7k2` is evidence in this case, not part of the rule.

**Limits of the comparison.**
- The contrast is with one week, not two years. No earlier audit data is available on this machine.
- The first-seen action alone cannot separate an engineer in a debug session from an attacker. The sequence becomes suspicious through what follows: a lookup of `controller-admin` (row 828), then Secret reads by that identity (rows 829 and 830). An approved debug exception with an owner belongs to the detection (Section 5).
- The cross-namespace test is complete for this file. Four events (rows 826, 828, 829, 830) have an actor whose home namespace differs from the object's namespace. All four are in the chain. This covers one week only.

## 5. Limits and open items

These items are not in the audit file. They are stated here so the findings above are not read as stronger than the record supports.

| Item | Status | What resolves it |
|---|---|---|
| Request scope of row 829 (namespaced `kube-system` or cluster-wide) | Open. Not recorded at `Metadata` level. | An audit record at `Request` level for auditID `a55c4295ef26154`. |
| Identity-change mechanism (`debug-shell-x7k2` to `controller-admin`) | Open. No token event and no pod spec in the audit. | The pod spec of `debug-shell-x7k2`, or a `Request`-level audit of its creation. |
| Two-year baseline | Not supported by the supplied materials; the local record covers seven days only. | The cluster's retained audit archive, searched per full ServiceAccount identity. |
| Whether `build/ci-runner` created pods outside `build` before 2026-10-19 | Unknown. | The archive, once found. |
| Fate of `debug-shell-x7k2` after 14:00:00Z | Unknown. No later event in the file. | `kubectl get pod -n platform debug-shell-x7k2` on the cluster, or later audit records. |

## 6. Detection design: per-identity baseline, ownership, and upkeep

The signal is a **per-identity behavioral change**: `build/ci-runner` moves from its repeated read activity in `build` to its first observed `create pods` in `platform` (row 826). This is earlier than the Secret reads and does not depend on the pod name. The seven-day export supports calling it novel in this file; it cannot establish the requested two-year normal. The two-year claim is a hypothesis from the engagement context until Trellis supplies that history.

### Baseline unit and features

Create a separate profile for each canonical Kubernetes principal, especially each ServiceAccount identity `system:serviceaccount:<namespace>:<name>`. Do not merge accounts because their short names or namespaces look similar. Link each ServiceAccount to all Deployments, Jobs, CronJobs, StatefulSets, and other workload templates that select it, then link those workloads to a named owner. If an account is shared by multiple workloads, record that fact and baseline the distinct workload sources separately where the audit data allows it.

For each identity and workload context, retain the normal distribution of:

- verb, API group, resource and subresource;
- namespace and target name pattern, including whether access is namespaced or cluster-scoped;
- allow/deny response, status code, request frequency, time-of-day, day-of-week, and known job/release cadence;
- source IP and user agent, when the audit policy captures them;
- workload/controller association and owner, joined from the workload manifests or inventory.

Treat a new write verb, new resource, new namespace, unusual target pattern, or sharp frequency shift as a candidate anomaly. Weight identity-specific novelty: a single `create pods` can be high priority for an account whose established work is read-only. Correlate the sequence across identities (row 826 `ci-runner` Pod creation, row 828 lookup of `controller-admin`, then rows 829–830 Secret requests by `controller-admin`) to raise confidence. The final Secret access remains useful context but is too late to be the first alert.

### Seed profiles visible in this seven-day sample

These are provisional sample profiles, not the two-year baselines described by the engagement context. The owner column identifies the workload that should be linked to an accountable team; team names are not in this export.

| Canonical identity | Workload association to resolve | Observed normal pattern before the chain | Novel behavior in this file |
|---|---|---|---|
| `system:serviceaccount:build:ci-runner` | Deployment `ci-runner` in `build` (`workloads/build/deployments.yaml`); owner team must be identified in Trellis' service inventory. | 257 events. 250 (97%) were `get/list` reads of core Pods and ConfigMaps in `build`; other events were limited reads/watches of Services, Endpoints, and Deployments. No Secret access. | First recorded `create pods` in `platform` at row 826, then `get serviceaccounts/controller-admin` in `platform` at row 828. |
| `system:serviceaccount:platform:controller-admin` | Deployment `platform-controller` in `platform` (`workloads/platform/deployments.yaml`); owner team must be identified in Trellis' service inventory. | Seven pre-chain events, all read/watch requests in `platform` on ConfigMaps, Pods, Services, Deployments, and Endpoints; no Secret event. | First Secret requests and first events outside `platform` are rows 829–830. The scope of row 829 remains unknown from this Metadata export. |

For both profiles, store distributions by verb × API group × resource × namespace, plus target-name class, result/status, time/cadence, source, and workload owner. The export's `obj-*` names do not establish stable application naming patterns, and the omitted source IP/user agent fields prevent source-based comparison. Validate those fields against longer history before enabling automatic suppression.

### Build and validate the baseline

1. Recover the longest retained audit history available, with a target of 24 months so daily, weekly, release, and infrequent maintenance cycles can be represented. The supplied seven-day JSONL is not enough to train or validate a durable profile.
2. Build profiles retrospectively from that history. Where history is shorter, mark the account **provisional**; collect at least one full business/release cycle and keep alerts in analyst-review mode until owners validate expected activity. Do not label a one-week sample as two years of normal.
3. Replay known incidents, approved releases, maintenance jobs, and denied requests against the candidate rules. Measure missed events and noisy alerts; tune per identity and workload rather than using one cluster-wide allowlist.
4. Start alerting with the owner, observed deviation, supporting audit events, and the prior baseline. High-risk deviations—new workload writes, RBAC changes, impersonation, and Secret reads—can page immediately; lower-confidence shifts go to review.

### Audit data needed

Keep routine audit events at `Metadata` level for the identity, verb, API group, resource, namespace, target name, and result. Ensure the retained record also includes timestamp, source IP, user agent, and request URI; these fields are absent from this supplied sample, limiting retrospective analysis. For sensitive **write** actions—workload create/update/patch, Role/RoleBinding/ClusterRoleBinding changes, ServiceAccount changes, and Secret writes—use `Request` level so the requested object fields (for example `serviceAccountName` or a new binding subject) can be inspected. Avoid `RequestResponse` for Secret reads unless a specific case justifies it, because response bodies can contain secret values. The current Metadata-only export cannot recover request bodies retroactively.

Retain searchable audit data for 24 months, protect it from workload identities, restrict analyst access, and monitor gaps in collection. Storage and review volume are part of the control's operating cost.

### Ownership and maintenance

Assign each profile to the service owner of the workload that uses the identity. Review exceptions with that owner, security, and platform operations; every exception records the identity, exact action/resource/namespace/target, reason, approver, ticket, and expiry date. Expired exceptions stop suppressing alerts automatically. Avoid indefinite allowlists.

Refresh profiles when a workload image/template, ServiceAccount, RoleBinding, owner, or deployment schedule changes. Compare the change to recent history, require owner review for newly added privilege or new target namespaces, and version the approved profile with the deployment change. Review alert quality and profile coverage monthly; review exceptions and owner mappings at least quarterly. Flag profiles with no recent events, deleted accounts, changed workload associations, or data gaps as stale; do not keep silently learning them. New or changed identities return to provisional review until the owner validates their new baseline.

Trellis currently lacks the long audit history and per-identity baseline needed to say that `ci-runner` had done only its routine actions for two years. Establishing that history, joining identities to workload owners, and maintaining reviewed profiles are prerequisites to the detection—not work the present seven-day export can prove has already been done.

## 7. Retrieval commands

Any analyst can run these against the audit file.

| Event | Command |
|---|---|
| 826 | `jq 'select(.auditID=="fc732b41831c35c")' /home/latchkey/trellis-audit.jsonl` |
| 828 | `jq 'select(.auditID=="c22c0094a42c174")' /home/latchkey/trellis-audit.jsonl` |
| 829 | `jq 'select(.auditID=="a55c4295ef26154")' /home/latchkey/trellis-audit.jsonl` |
| 830 | `jq 'select(.auditID=="50169ea038b7cff")' /home/latchkey/trellis-audit.jsonl` |
| All Secret events | `jq -c 'select(.objectRef.resource=="secrets")' /home/latchkey/trellis-audit.jsonl` |
| All `build/ci-runner` events | `jq -c 'select(.user.username=="system:serviceaccount:build:ci-runner")' /home/latchkey/trellis-audit.jsonl` |
