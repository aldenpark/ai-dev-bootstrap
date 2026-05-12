# External Backends

This plugin is designed to work with a file-backed local project hub first.

## Recommended External Targets

### GitHub Projects

Best default for engineering work across multiple repos.

Use when you want:

- roadmap, table, and board views
- direct links to issues and PRs
- automatic sync with repo work items

Recommended pairing:

- GitHub Projects for planning
- GitHub Issues for tasks
- repo markdown docs or GitHub-hosted docs for architecture and decisions

### Notion

Best when you want a combined docs + database experience and do not mind looser repo coupling.

### Trello

Best when you want a very lightweight board and the team mainly needs status tracking, not engineering traceability.

### Confluence

Best as a wiki layer, especially if you later adopt Jira. Less attractive as the main free engineering PM system.

## Multi-System Guidance

Avoid splitting the same canonical backlog across multiple tools.

If you need both:

- keep the local project hub as the canonical state
- choose one external PM board
- choose one external wiki/doc target
