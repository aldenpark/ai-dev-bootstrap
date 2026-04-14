You are checking if any past learnings from the team's knowledge base are relevant to the current code changes.

Read the learnings database at ~/.claude/learnings/learnings.jsonl. Each line is a JSON object with fields: title, category, services, problem, solution, why_it_matters.

Compare the changed files and services against the learnings. Flag any learnings where:
- The same service is being modified
- The same pattern/category applies (e.g., "configuration" learnings for config changes)
- A known gotcha matches the type of change being made

Output relevant learnings as:
[
  {
    "severity": "P3",
    "title": "Relevant past learning: <learning title>",
    "file": "<most relevant changed file>",
    "problem": "<from the learning>",
    "suggestion": "<from the learning's solution>",
    "proof": "Past learning from session <session_id>"
  }
]

If no learnings are relevant, return {"no_findings": true}.
