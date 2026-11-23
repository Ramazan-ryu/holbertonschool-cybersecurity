# Trellis Software: audit trail reconstruction

## 1. Source and verification

**Audit file.** `/home/latchkey/trellis-audit.jsonl`. A byte-identical copy exists at `/opt/trellis/master/trellis-audit.jsonl` (md5 `161da0857299b4b81f469624e675d2fb`). One source is used.

**File properties (verified).**
- 881 lines, one JSON audit event per line.
- Time range: `2026-10-19T00:01:00.000000Z` to `2026-10-25T23:53:00.000000Z`, a window of 6 days 23 hours 52 minutes.
- Audit level `Metadata`, stage `ResponseComplete`. Request and response bodies are not recorded.
- `sourceIPs`, `userAgent`, and `requestURI` are absent from every record checked. Row 829 has no `requestObject` or `responseObject` either.
- Every event has a namespace (`objectRef.namespace` is present on all 881 events).

**Archive search (verified on this machine).** `find / -iname '*audit*' -o -iname '*.jsonl*' -o -iname '*.log*'` returned only the two copies above and unrelated system logs. No Kubernetes audit archive for any period before 2026-10-19 is present. The cluster itself was not searched, because no kubeconfig is available here.

**Conventions.** Line numbers are 1-based physical lines (verified with `nl -v824`). Timestamps are full `requestReceivedTimestamp` values.

**Scope of this analysis.** One week. Nothing here establishes activity before 2026-10-19.

## 2. Material events

| Line | auditID | requestReceivedTimestamp | User | Verb | apiGroup | Resource | Namespace | Name | Code | Decision |
|---|---|---|---|---|---|---|---|---|---|---|
| 826 | `fc732b41831c35c` | 2026-10-25T14:00:00.000000Z | `system:serviceaccount:build:ci-runner` | create | (core) | pods | platform | `debug-shell-x7k2` | 200 | allow |
| 828 | `c22c0094a42c174` | 2026-10-25T14:02:00.000000Z | `system:serviceaccount:build:ci-runner` | get | (core) | serviceaccounts | platform | `controller-admin` | 200 | allow |
| 829 | `a55c4295ef26154` | 2026-10-25T14:05:00.000000Z | `system:serviceaccount:platform:controller-admin` | list | (core) | secrets | kube-system | (empty) | 200 | allow |
| 830 | `50169ea038b7cff` | 2026-10-25T14:06:00.000000Z | `system:serviceaccount:platform:controller-admin` | get | (core) | secrets | prod | `orders-api-token` | 200 | allow |

The chain runs six minutes, from 14:00:00Z to 14:06:00Z.

**Row 829: scope unresolved.** The record names `kube-system` as `objectRef.namespace` and leaves the name empty. The record does not say whether the list was limited to `kube-system` or covered all namespaces. Without `requestURI` or `requestObject`, the file cannot decide. This analysis does not call it cluster-wide.

## 3. Identity context

### 3.1 `build/ci-runner` (verified, 257 events)

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

Reads of configmaps and pods make up 250 of 257 events (97%). The only `create` by this identity in the file is row 826. The identity never touched a Secret.

### 3.2 `platform/controller-admin` (verified, 9 events)

Before the chain (7 events, all in `platform`, none on Secrets):

| Timestamp | Verb | Resource | Name |
|---|---|---|---|
| 2026-10-19T10:09:00Z | get | configmaps | obj-5881 |
| 2026-10-20T11:29:00Z | list | pods | obj-2000 |
| 2026-10-22T09:42:00Z | get | configmaps | obj-8375 |
| 2026-10-23T00:26:00Z | get | services | obj-4405 |
| 2026-10-24T23:20:00Z | get | configmaps | obj-9673 |
| 2026-10-25T00:27:00Z | list | deployments | obj-2873 |
| 2026-10-25T06:16:00Z | watch | endpoints | obj-3083 |

The chain holds this identity's only two Secret events in the file (rows 829 and 830) and its first events outside `platform`.

After the chain: 2026-10-25T18:06:00Z, `watch endpoints` in `platform` (`obj-3571`, auditID `6a16ed2a75f8ebb`). No later events appear for this identity.

### 3.3 Secret access across the whole file (verified)

Exactly two events in the file have `objectRef.resource: secrets`: rows 829 and 830. Both are by `platform/controller-admin`. No other identity reads or lists Secrets during the week.

### 3.4 Debug pod

`debug-shell-x7k2` appears once: row 826, `create`. No `exec`, delete, or read of this pod is recorded.

## 4. Corrections to the earlier draft

1. **"Lists Secrets cluster-wide" is removed.** The record shows `objectRef.namespace: kube-system` and an empty name. Scope needs `requestURI` or `requestObject`, which are absent.
2. **The identity change is not in the audit.** There is no `serviceaccounts/token` event, and `Metadata` level does not record `spec.serviceAccountName`. That `debug-shell-x7k2` ran as `controller-admin` is an inference from `1-effective_privilege.md` (E1), not an audit fact.
3. **`platform-deployer` R2 grants `get` and `list` on serviceaccounts only** (`0-rbac_map.md`). It grants nothing on Secrets or tokens.
4. **The 255-of-257 split is confirmed:** 255 events in `build`, 2 in `platform` (rows 826 and 828).
5. **"First Secret access" is now confirmed.** Rows 829 and 830 are the only Secret events in the file.

## 5. Earliest structural anomaly

**Detection point: row 826.** `system:serviceaccount:build:ci-runner` creates a pod (`pods`, core group) in namespace `platform`. auditID `fc732b41831c35c`, 2026-10-25T14:00:00Z, response 200, decision allow.

**Why it is abnormal for this identity (within this file).** Its activity is 97% reads of configmaps and pods in `build`. Its only `create` in 257 events is row 826. Its only earlier activity outside `build` is none. The action differs on three counts: verb (`create`, unique), resource (`pods`, not a read), and namespace (`platform`, never used before in the file).

**Why it is earlier and more useful than the Secret read.** Row 826 is the first event in the chain. Row 828 follows two minutes later, the first Secret access (row 829) five minutes later, and the high-impact read (row 830) six minutes after the start. Alerting on row 830 fires once the damage is possible, and it would fire on any legitimate use of that identity. A rule keyed on row 826 fires before any Secret is touched.

**The rule does not depend on the object name.** It keys on (identity, verb, resource, namespace): `build/ci-runner`, `create`, `pods`, `platform`. `debug-shell-x7k2` is evidence in this case, not part of the rule.

**What the evidence can and cannot support.**
- The contrast is with one week, not two years. The archive search found no earlier audit data on this machine. Whether `build/ci-runner` created pods outside `build` before 2026-10-19 is unknown.
- The first-seen action cannot by itself separate an engineer in a debug session from an attacker. The sequence becomes suspicious through what follows: a lookup of `controller-admin` (row 828), then Secret reads by that identity (rows 829 and 830). An approved debug exception with an owner belongs to the detection (Section 6).
- The cross-namespace test is complete for this file. Four events (rows 826, 828, 829, 830) have an actor whose home namespace differs from the object's namespace. All four are in the chain. All 881 events have a namespace, so no cluster-scoped request was missed. The test covers one week only.

## 6. Detection: what it takes

**What to build.**
1. A per-identity baseline of (verb, resource, namespace) tuples with request rates, learned from audit data for each ServiceAccount and User. For `build/ci-runner`, one week gives 257 events, enough to see a pattern. For `controller-admin`, one week gives seven pre-chain events, too few for a reliable baseline.
2. An alert on a first-seen (identity, verb, resource, namespace) tuple where the namespace differs from the identity's home namespace and the verb is `create`, or `get` or `list` on serviceaccounts or secrets.
3. An alert on any Secret read by an identity with no prior Secret reads in its baseline.
4. An exception path for approved debug and deployment changes, recorded with an owner, an expiry, and the pod or namespace in scope.

**Requirements before the detection is reliable.**
- **Audit level.** `Metadata` does not record source IP, user agent, request URI, or request bodies. Detection needs at least `Request` level for pods, serviceaccounts, and secrets. Without it, row 829's scope and the identity-change mechanism cannot be recorded.
- **Learning period.** A baseline needs a full cycle of legitimate activity: deploys, rollouts, scheduled work. One week does not supply that.
- **Deployment changes and debug sessions.** Approved changes update the baseline, and the change record suppresses the related alerts. Each debug session needs an owner.
- **Baseline maintenance.** Review profiles on a fixed schedule, and rebuild after any change to the identity's RBAC.
- **Cost.** Audit retention and alert triage are the main costs. Start with `platform/controller-admin`, `build/ci-runner`, and `prod/deploy-bot`.

**What the detection does not do.** An identity acting inside its established profile is not caught. A Secret read would be missed if such reads were already part of that identity's profile. The detection supplements narrower RBAC and enforced admission, and does not replace them.

## 7. Limits and verification still needed

| Item | Status | What resolves it |
|---|---|---|
| Two-year baseline | **Not supported by the supplied materials.** The archive search on this machine found no Kubernetes audit data before 2026-10-19. | The cluster's audit log store, searched on the cluster, or the archive owner. Run the same `find` there. |
| Scope of row 829 | Unresolved. No `requestURI` or `requestObject`. | An audit record at `Request` level for the same auditID `a55c4295ef26154`. |
| Identity-change mechanism (`debug-shell-x7k2` to `controller-admin`) | Unresolved. No token event and no pod spec in the audit. | The pod spec of `debug-shell-x7k2` (`kubectl get pod`, if it still exists), or a `Request`-level audit of the pod's creation. |
| Whether `build/ci-runner` created pods outside `build` before 2026-10-19 | Unknown. | The archive, once found. |
| Fate of `debug-shell-x7k2` after 14:00:00Z | Unknown. No later event in the file. | Cluster state (`kubectl get pod -n platform debug-shell-x7k2`) or later audit records. |
