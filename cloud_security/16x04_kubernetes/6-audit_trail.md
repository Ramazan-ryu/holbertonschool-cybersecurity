# Trellis Software: audit trail reconstruction

## 1. Source and verification

**Audit file.** `/home/latchkey/trellis-audit.jsonl`. A byte-identical copy exists at `/opt/trellis/master/trellis-audit.jsonl` (md5 `161da0857299b4b81f469624e675d2fb`). One source is used.

**File properties (verified).**
- 881 lines, one JSON audit event per line.
- Time range: `2026-10-19T00:01:00.000000Z` to `2026-10-25T23:53:00.000000Z`, about 7 days.
- Audit level `Metadata`, stage `ResponseComplete`. Request and response bodies are not recorded.
- `sourceIPs`, `userAgent`, and `requestURI` are absent from every record checked.

**Conventions.** Line numbers are 1-based physical lines (verified with `nl -v824`). Timestamps are full `requestReceivedTimestamp` values.

## 2. Material events

| Line | auditID | requestReceivedTimestamp | User | Verb | apiGroup | Resource | Namespace | Name | Code | Decision |
|---|---|---|---|---|---|---|---|---|---|---|
| 826 | `fc732b41831c35c` | 2026-10-25T14:00:00.000000Z | `system:serviceaccount:build:ci-runner` | create | (core) | pods | platform | `debug-shell-x7k2` | 200 | allow |
| 828 | `c22c0094a42c174` | 2026-10-25T14:02:00.000000Z | `system:serviceaccount:build:ci-runner` | get | (core) | serviceaccounts | platform | `controller-admin` | 200 | allow |
| 829 | `a55c4295ef26154` | 2026-10-25T14:05:00.000000Z | `system:serviceaccount:platform:controller-admin` | list | (core) | secrets | kube-system | (empty) | 200 | allow |
| 830 | `50169ea038b7cff` | 2026-10-25T14:06:00.000000Z | `system:serviceaccount:platform:controller-admin` | get | (core) | secrets | prod | `orders-api-token` | 200 | allow |

The chain runs six minutes, from 14:00:00Z to 14:06:00Z.

**Not in the record.** Source IP, user agent, and request URI (absent at this audit level). Without `requestURI`, row 829 cannot be called namespaced or cluster-wide from the record. The request scope is therefore unresolved.

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

The 250 reads of configmaps and pods make up 97% of the identity's activity. Before row 826, every event is in `build`.

### 3.2 `platform/controller-admin` (verified, 9 events)

Before the chain (7 events, all in `platform`, none on secrets):

| Timestamp | Verb | Resource | Name |
|---|---|---|---|
| 2026-10-19T10:09:00Z | get | configmaps | obj-5881 |
| 2026-10-20T11:29:00Z | list | pods | obj-2000 |
| 2026-10-22T09:42:00Z | get | configmaps | obj-8375 |
| 2026-10-23T00:26:00Z | get | services | obj-4405 |
| 2026-10-24T23:20:00Z | get | configmaps | obj-9673 |
| 2026-10-25T00:27:00Z | list | deployments | obj-2873 |
| 2026-10-25T06:16:00Z | watch | endpoints | obj-3083 |

The chain (rows 829 and 830). These are the identity's first secret events in the file, and the first events outside `platform`.

After the chain: 2026-10-25T18:06:00Z, `watch endpoints` in `platform` (`obj-3571`, auditID `6a16ed2a75f8ebb`). The file contains no later events for this identity.

### 3.3 Debug pod

`debug-shell-x7k2` appears once in the file: row 826, `create`. No `exec`, delete, or read of this pod is recorded.

## 4. Corrections to the earlier draft

1. **"Lists Secrets cluster-wide" is removed.** The record shows `objectRef.namespace: kube-system` and an empty name. Scope cannot be established without `requestURI`.
2. **The identity change is not in the audit.** There is no `serviceaccounts/token` event. Metadata level does not record `spec.serviceAccountName`. The statement that `debug-shell-x7k2` ran as `controller-admin` is an inference from the RBAC export (`1-effective_privilege.md`, E1), not an audit fact.
3. **The first-seen tuple for `controller-admin` is secrets, not platform.** The identity has acted in `platform` all week. What is new is `secrets` (in `kube-system` and in `prod`), and cross-namespace reach.
4. **`platform-deployer` R2 grants `get` and `list` on serviceaccounts only** (`0-rbac_map.md`). It grants no access to Secrets or tokens.
5. **The count of 255 of 257 is confirmed.** 255 in `build`, 2 in `platform` (rows 826 and 828).

## 5. Signal

**The signal is the first-seen cross-namespace action by a workload identity.** For `build/ci-runner`, the tuple (create, pods, platform) occurs once in the week, at row 826. The tuple (get, serviceaccounts, platform) also occurs once, at row 828. Both are valid requests (decision `allow`, code 200). RBAC and admission do not stop them.

**Why row 826 comes before the high-impact action.** It is the first event in the file where `ci-runner` leaves `build`. Row 830, the Secret read in `prod`, comes six minutes later and is itself a first-seen action for `controller-admin`. An alert on row 830 fires once the damage is possible.

**Limit.** Row 826 also fits a legitimate debug session, and the name `debug-shell-x7k2` suggests one. The first-seen action alone cannot separate an engineer from an attacker. What makes the sequence suspicious is what follows: a lookup of `controller-admin` (row 828), then Secret reads by that identity (rows 829 and 830). An approved debug exception is part of the detection (Section 6).

**False-positive evidence, and its limit.** Across the week, 4 events have an actor whose home namespace differs from the object's namespace: rows 826, 828, 829, and 830. All four are in the chain. This suggests that a rule on cross-namespace actions would have produced no false positives in this file. It is not evidence for a real cluster. The test covers one week of 881 events and excludes requests with no namespace (cluster-scoped requests).

**What this file cannot show.**
- Activity before 2026-10-19. The two-year history is not in the supplied materials.
- The request scope of row 829.
- The fate of `debug-shell-x7k2` after 14:00:00Z.
- Whether the identity change was a token request, a pod spec, or something else. The audit level does not record it.

## 6. Detection: what it takes

**What to build.**
1. A per-identity baseline of (verb, resource, namespace) tuples, with request rates, learned from audit data for each ServiceAccount and User. For `controller-admin`, one week gives seven events, which is too few to be a reliable baseline.
2. An alert on a first-seen (identity, verb, resource, namespace) tuple where the namespace is not the identity's home namespace and the verb is `create`, or `get` or `list` on serviceaccounts or secrets.
3. An alert on any Secret read by an identity with no prior Secret reads in its baseline.
4. An exception path for approved debug and deployment changes, recorded with an owner, an expiry, and the pod or namespace in scope.

**Requirements before the detection is reliable.**
- **Audit level.** Metadata does not record source IP, user agent, request URI, or the pod spec. Detection needs at least `Request` level for the high-impact resources (pods, serviceaccounts, secrets) so that scope and identity-change events are recorded.
- **Learning period.** A baseline needs a full cycle of legitimate activity: deploys, rollouts, scheduled work.
- **Deployment changes and debug sessions.** Approved changes update the baseline, and the change record suppresses the related alerts. Each debug session needs an owner, or the team will learn to ignore the alert.
- **Baseline maintenance.** Review profiles on a fixed schedule, and rebuild after any change to the identity's RBAC.
- **Cost.** Audit retention and triage are the main costs. Start with `platform/controller-admin`, `build/ci-runner`, and `prod/deploy-bot`.

**What the detection does not do.** An identity used inside its established profile is not caught. A Secret read by `controller-admin` would be missed if reads of that kind were already part of its profile. The detection supplements narrower RBAC and enforced admission, and does not replace them.

## 7. Verification still needed

| Check | Command | Resolves |
|---|---|---|
| Cluster-scoped requests excluded from the false-positive test | `jq -r 'select(.objectRef.namespace==null) \| [.user.username, .verb, .objectRef.resource] \| @tsv' /home/latchkey/trellis-audit.jsonl \| sort \| uniq -c \| sort -rn` | Whether the false-positive result in Section 5 holds for requests without a namespace |
| Request scope of row 829 | Requires an audit record with `requestURI`, not present in this file | Section 2, row 829 |
| Identity change mechanism | Requires `Request`-level audit or the pod's spec, not present in this file | Section 4, item 2 |
| Activity before 2026-10-19 | Requires the audit archive for that period | Section 5 limits |
