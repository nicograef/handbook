---
name: prog
description: Give a summary of this session's state or plan on what is done and what is still todo.  
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Prog

Write a summary on the status and progress of this session in a table or list format.
If this session is implementing a plan or executing a skill or multi-phase workflow:
List all steps and phases of this session/plan and provide clear information on wether 
that step is done or still open todo. For open steps, state what is blocking them.
Also list all decisions and questions that are needed from the user/human to continue.
No prose. Only summaries and structured information.

