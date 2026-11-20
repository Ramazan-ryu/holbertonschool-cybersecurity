# 2 — Data paths

## 1. Time-limited grant: pre-signed S3 URL

Support ticket CL-4471 contains a pre-signed `GetObject` URL for `alderbrook-partner-share-ab7f3a/share/partner-feed.json`. Its query carries an AWS Signature Version 4 credential and `X-Amz-Expires=604800` (seven days), starting at `2026-11-19T23:49:26Z`; absent earlier credential revocation, the URL’s stated expiry is `2026-11-26T23:49:26Z`.

The workstation transcript reports that `curl` fetched the feed without login credentials. The URL is a bearer capability: the request is authorized using the signer’s signature, not by proving that the requester is the intended Northmoor recipient. Anyone who obtains the URL can replay it while it remains valid and the signing credentials remain usable. Disabling the intended recipient’s identity does not bind or revoke the URL. Deactivating/revoking the signing access key or waiting for expiry can invalidate this particular URL, but doing so may disrupt other uses of that key. The exact signer identity and current credential status were not tested in the supplied evidence.

The URL host in the ticket is `127.0.0.1:4566`, the lab’s local S3-compatible endpoint. This proves a path from a process on the workstation to the lab endpoint; it does not prove that a remote Northmoor host can reach that loopback address.

## 2. External account trust

The `PartnerFeed` bucket policy names AWS account `905501234789` and allows `s3:GetObject` and `s3:ListBucket` on the partner-share bucket and its objects. This is a cross-account trust, not an Alderbrook-only principal. For cross-account access, a principal in that account also needs an identity-side allow. No call made with Northmoor credentials, and no external-principal success or denial response, is present. Thus the policy’s trust is established, but the effective reach of a particular Northmoor role is not.

## 3. Route, interface, destination, and observable record

The demonstrated bearer route is an HTTP(S) `GetObject` request using the pre-signed query string to the lab’s S3-compatible interface at `127.0.0.1:4566`; the caller can save the response wherever that caller controls. No off-workstation transfer was performed or is claimed. Separately, the bucket policy delegates a potential S3 API route to eligible Northmoor principals.

A real S3 transfer should be monitored as S3 data events for `GetObject`, with bucket/key, event time, source address, user agent, caller identity, and authentication method (query-string signature for a pre-signed request where recorded). The collected CloudTrail files show successful `GetObject` events by `sec-reviewer` for the records, exports, and ops objects, but no partner-share `GetObject` event in the available interval. No log record from an actual pre-signed URL use or Northmoor access is available, so those monitoring fields are expectations, not observed values.
