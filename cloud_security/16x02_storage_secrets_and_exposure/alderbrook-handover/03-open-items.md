# Open items (Platform)

1. The records bucket has an old "legacy clinic sync" policy on it from the early integration days. It is
   blocked by the public access control, so it has not been a priority to revisit.
2. The partner share is reached by Northmoor over a cross-account trust. We think the trust is scoped to
   their account.
3. A support ticket (CL-4471) generated a direct download link for the partner when their auth broke. It
   was a one-off.
4. Some old credentials are probably still in the application history. We rotated what we found.
5. The reporting job decrypts records on a schedule; that is expected activity in the trail.
