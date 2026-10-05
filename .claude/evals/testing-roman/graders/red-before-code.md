---
type: tool_order
before: { tool: Bash, input_match: 'node\b.*test' }
after: { tool: Write, input_match: '/roman\.js"' }
---
