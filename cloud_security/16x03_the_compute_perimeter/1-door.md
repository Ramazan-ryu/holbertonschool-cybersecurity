# 1 — Through the Door

## Feature and control test

The server-side URL fetch is the catalog image import endpoint:

```text
GET /admin/catalog/image-import?src=<URL>
```

Evidence that the destination is caller-controlled: requesting `src=http://example.com/` returned the Example Domain HTML body from the server-side fetch. The two similar-looking controls rejected the same metadata destination instead:

```text
GET /admin/preview?page=http://169.254.169.254/  -> 403: host not permitted for preview
GET /go?to=http://169.254.169.254/              -> 400: only relative redirects allowed
```

This distinguishes the working fetch from the allowlisted preview and relative-only redirect. The names of the features were not used as evidence; their responses were.

## Metadata response and identity

Using the image-import fetch for `http://169.254.169.254:80/latest/meta-data/iam/security-credentials/marlowe-web-instance-role` returned a successful instance-credential document (`Code: Success`, type `AWS-HMAC`, with access key, secret key, token, and expiration fields). Credential values are omitted from this report and evidence bundle. The subsequent `sts get-caller-identity` response identifies the credentials as `arn:aws:sts::500100200300:assumed-role/marlowe-web-instance-role/i-0marlowe` (see `2-instance_chain.md`). This is a server-side request forgery with a demonstrated workload identity consequence.

The request used the IMDSv1-style metadata path without a metadata token. The service therefore accepted a forged server-side request without the caller proving possession of an IMDSv2 session token. This is the metadata configuration decision that made credential retrieval possible.

## Remediation evidence status

The session transcript records an earlier `sudo imds-mode strong` followed by `sudo imds-mode weak`. In the latest retest, `sudo imds-mode strong` again returned success. Replaying the identical forged URL above then returned `HTTP=502`, 23 bytes, and the response contained none of the `AccessKeyId`, `SecretAccessKey`, or `Token` fields. The corresponding weak-mode request returned the credential document. This validates the service-side metadata control for that exact request. The catalog image-import SSRF itself remains caller-controlled; hardening metadata does not repair the application route or prove that every internal destination is unreachable.
