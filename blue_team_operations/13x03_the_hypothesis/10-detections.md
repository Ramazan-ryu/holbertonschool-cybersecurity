# Durable coverage

## Detection for confirmed persistence

I authored and tested the following behavior-based Wazuh rule. It is intentionally narrower than any Run-key write:

<pre>
&lt;group name="kestrel_hunt,windows,persistence,"&gt;
  &lt;rule id="100310" level="12"&gt;
    &lt;if_group&gt;sysmon_event13&lt;/if_group&gt;
    &lt;field name="win.eventdata.targetObject"&gt;(?i)\\Software\\Microsoft\\Windows\\CurrentVersion\\Run&lt;/field&gt;
    &lt;field name="win.eventdata.details"&gt;(?i)(AppData\\Roaming|AppData\\Local|Users\\Public)&lt;/field&gt;
    &lt;field name="win.eventdata.image"&gt;(?i)(powershell|wscript|cscript|rundll32|regsvr32|mshta)\.exe&lt;/field&gt;
    &lt;description&gt;Script-backed writer creates Run-key persistence in a user-writable path&lt;/description&gt;
    &lt;mitre&gt;&lt;id&gt;T1547.001&lt;/id&gt;&lt;/mitre&gt;
  &lt;/rule&gt;
&lt;/group&gt;
</pre>

The production rule should add signer or inventory context to exclude legitimate signed enterprise updaters. Tavistock9 remains a campaign pivot, not the sole detection condition.

Test result: I tested the behavior against ordinary fleet activity. Legitimate updater Run-key writes were present, but the full condition did not fire on those benign writers because they did not combine the script-capable writer and user-writable target conditions. The confirmed candidates remained NIM-ENG-031, NIM-ENG-057, and NIM-ENG-066.

## Remedy for the blind spot

I recommend collection rather than a live staging rule because local staging and archive creation are not observable. Enable Sysmon Event ID 11 FileCreate and Windows Object Access auditing with Security Event ID 4663; collect 4656 and 4660 as supporting events. Begin with user-writable staging locations, temporary directories, archive extensions, and sensitive paths, then tune high-volume applications.

After collection exists, add a rule for archive creation or repeated writes into a staging directory correlated with process and destination. Until then, an empty result means the sensor could not see the operation.
