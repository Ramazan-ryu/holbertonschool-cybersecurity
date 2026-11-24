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

Each row is retrievable from the file by its auditID. The command for each row is in Section 6.

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
| Two-year baseline | Not supported by the supplied materials. | The cluster's audit log store, searched on the cluster. |
| Whether `build/ci-runner` created pods outside `build` before 2026-10-19 | Unknown. | The archive, once found. |
| Fate of `debug-shell-x7k2` after 14:00:00Z | Unknown. No later event in the file. | `kubectl get pod -n platform debug-shell-x7k2` on the cluster, or later audit records. |

## 6. Retrieval commands

Any analyst can run these against the audit file.

| Event | Command |
|---|---|
| 826 | `jq 'select(.auditID=="fc732b41831c35c")' /home/latchkey/trellis-audit.jsonl` |
| 828 | `jq 'select(.auditID=="c22c0094a42c174")' /home/latchkey/trellis-audit.jsonl` |
| 829 | `jq 'select(.auditID=="a55c4295ef26154")' /home/latchkey/trellis-audit.jsonl` |
| 830 | `jq 'select(.auditID=="50169ea038b7cff")' /home/latchkey/trellis-audit.jsonl` |
| All Secret events | `jq -c 'select(.objectRef.resource=="secrets")' /home/latchkey/trellis-audit.jsonl` |
| All `build/ci-runner` events | `jq -c 'select(.user.username=="system:serviceaccount:build:ci-runner")' /home/latchkey/trellis-audit.jsonl` |
