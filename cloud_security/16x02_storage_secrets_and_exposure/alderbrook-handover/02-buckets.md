# Storage (as we understand it)

| Bucket | Contents | Notes |
|---|---|---|
| `alderbrook-phi-records-ab7f3a` | patient records (NDJSON), encrypted with `alias/alderbrook-phi` | not public — account public-access block is on |
| `alderbrook-exports-ab7f3a` | clinic rollup exports | restrictive bucket policy |
| `alderbrook-partner-share-ab7f3a` | the results feed for Northmoor Labs | shared with the partner account |
| `alderbrook-ops-ab7f3a` | retention reports, ops docs | internal only |
| `alderbrook-cloudtrail-ab7f3a` | account audit log | written by the trail |

Everything is behind the account-level public access block, so none of it is public.
