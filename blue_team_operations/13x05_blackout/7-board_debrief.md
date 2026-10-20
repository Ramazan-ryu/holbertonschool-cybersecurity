# Board Debrief

The incident was confirmed by a ransomware executable hash and ransom-note creation, not by a single alert. Containment was deliberately limited to the 53 encrypted and 19 staged hosts. Six staged payments hosts led the priority order.

The principal risk is persistence in the identity system. Evidence shows replication access from HALC-ADM-04 and unusually long-lived service tickets. The board should treat ordinary password resets as insufficient and fund domain recovery, a controlled krbtgt double reset, rebuilding of affected hosts, credential rotation, and regulated impact assessment.
