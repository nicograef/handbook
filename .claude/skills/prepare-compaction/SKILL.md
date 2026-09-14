---
name: prepare-compaction
description: Prepare the current session for a context compaction. Needs to run before /compact.  
---

# Prepare Compaction

Run the status and progress skill /prog first to get a full overview about this whole session.
Prepare this session to be compacted. Save this session's current state and it's progress to the scratchpad.
Update it's plan file and its memories as well as the scratchpad.
Make sure no subagents, no workflows and no background shell or monitor will get lost due to context compaction.
When everything important is updated and persisted, tell the user he/she can run /compact now.
Write a short prompt the user can copy and run after the compaction is done that instructs the compacted session to continue
(while giving it the information and references it needs to know).
