# Granite Peak Energy — Platform Overview

_Maintained by the platform team. Last substantive revision ~18 months ago; sections have been edited
piecemeal since._

## Accounts

Granite Peak runs two cloud accounts. The **build** account (210000000001) runs CI and tooling. The
**platform** account (210000000002) runs production. The accounts are separated: a workload in one does
not carry rights in the other.

## Network and segmentation

The application tier and the analytics tier sit in separate subnets. The **analytics subnet is private**
and is not reachable from the application tier; it carries only aggregate reporting dashboards.

## Cluster

The production cluster runs the platform workloads. A **pod-security policy is enforced in every
namespace**, so a workload that violates the baseline is rejected at admission.

## Key management and data handling

Operational grid telemetry — real-time load and switching data for the regional grid — is the most
sensitive data Granite Peak holds. It is classified **operational-restricted**. The telemetry store is
**protected by a tightly held, customer-managed key**; only the telemetry service identity may use it.

Operational-restricted information is governed: access must be controlled to authorised identities and
the data must be adequately protected at rest, with access logging and a seven-year retention. A failure
of either the access control or the protection is a reportable condition requiring an access review and
client notification.

## Identity

Human operators assume roles in the platform account through the identity provider. Service identities
are scoped to their workload. The deploy pipeline uses a dedicated role in the platform account.
