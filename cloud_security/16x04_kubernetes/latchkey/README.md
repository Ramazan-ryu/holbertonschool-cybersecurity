# 16x04 — Kubernetes · lab workstation

Holberton School · Cybersecurity · M16 Cloud Security

A Latchkey Security analysis workstation for the **Trellis Software** engagement. Trellis's cluster is
given to you as its **complete exported state** — the artefact a Kubernetes assessment is actually
conducted against. There is no cluster, no API server, and none is needed. Everything is offline.

## What is here

| | |
|---|---|
| `~/trellis-cluster-export/` | the complete cluster state: namespaces, service accounts, roles, bindings, workloads, network policies, admission config, pod-security labels (read-only) |
| `~/trellis-audit.jsonl` | authored cluster audit events — a normal week of a busy cluster |
| `kubescape` | manifest-mode, **framework definitions pre-fetched** at `/opt/kubescape/frameworks/` (offline) |
| `trivy` | manifest / image-metadata scanning, offline |
| `checkov` | infrastructure-code scanning, offline |
| `kubectl`, `yq`, `jq` | installed for familiarity; there is **no cluster**, so read and query the manifests with `yq`/`jq`/`cat` (most `kubectl` verbs need an API server and will not reach one) |

The three tools that need a live cluster (an RBAC escalation scanner, an in-pod post-exploitation tool, a
posture tool's Kubernetes mode) are deliberately **not** here. The escalation edges are yours to derive —
that is the competency.

## The one habit to put down

The last four projects trained you to hunt for the rule that says **no**. A Kubernetes cluster has no no.
Access is purely additive: a rule grants, nothing subtracts, nothing caps. The practical consequence is the
inversion of your instinct:

> You cannot establish that somebody **lacks** a permission by finding the rule that refuses it, because no
> such rule exists. You establish it only by accounting for **every** binding that touches them — and
> Trellis has namespaces nobody has opened in two years.

An incomplete enumeration here is not an incomplete answer; it is a wrong one, always in the same direction:
it tells the client their people can do **less** than they can. **A determination that misses a granting
binding fails the engagement**, whether or not the rest is correct.

## How Whitfield wants it

- **Enumerate exhaustively.** Cover every namespace, including the abandoned ones and the one with three
  objects somebody created to test something in 2022.
- **Derive, never assert.** Every capability you claim cites the specific binding/rule that grants it.
- **Say what is fine.** At least one subject holds exactly the privilege it appears to. Report it as sound.
- **Containers are out of scope.** Not the image, not the build. What the workload is *permitted to be*, and
  what identity is *mounted* into it.
- **Your fix must not break the cluster.** Removing a binding a running workload depends on is reverted on
  Monday. State what each fix costs operationally.

## Offline scanning

```bash
kubescape scan framework nsa \
  --use-from /opt/kubescape/frameworks/nsa.json ~/trellis-cluster-export --format json
trivy config ~/trellis-cluster-export
checkov -d ~/trellis-cluster-export
```

`kubescape` is pinned to the pre-fetched frameworks so it never needs the network. `mitre` is available at
the same path.

## Deliverables

Under `cloud_security/16x04_kubernetes`: `0-rbac_map.md`, `1-effective_privilege.md`,
`2-escalation_edges.md`, `3-pod_foothold.md`, `4-controls.md`, `5-remediation/` (a **directory**:
`5-fixed_manifests.yaml`, `5-rescan.txt`, `5-edge_broken.md`, `5-cost.md`), `6-audit_trail.md`,
`7-additive.md`, `8-edges.md`, `9-cluster_quiz`, `10-trellis_reply.md`.

## Reset

`trellis-reset` restores `~/trellis-cluster-export/` and `~/trellis-audit.jsonl` to their original state if
you have edited them while working. Your deliverables are untouched.
