# Evals

This folder contains a small `Promptfoo` starter for comparing agent and model behavior over time.

## What This Is For

Use this when you want to answer questions like:

- did Codex or Claude do better on my real task?
- did changing `AGENTS.md` or `CLAUDE.md` help or hurt?
- did adding Context7 improve answers on current library/framework questions?

This is not a full benchmark suite. It is a lightweight regression harness for your own workflow.

## Quick Start

Set the API keys you need:

```bash
export OPENAI_API_KEY=your_openai_api_key
export ANTHROPIC_API_KEY=your_anthropic_api_key
```

Run the starter eval:

```bash
npx promptfoo@latest eval -c evals/promptfooconfig.yaml
```

View results:

```bash
npx promptfoo@latest view
```

## What The Starter Covers

The included starter checks for three behaviors:

- planning a repo change with likely files
- recognizing when browser verification is needed
- recognizing when current docs should be consulted

## How To Use It

1. Run the eval before changing your workflow rules.
2. Change prompts, memory rules, MCP setup, or agent instructions.
3. Run the eval again.
4. Compare failures and output quality.

## Customize It

Edit these files:

- `evals/promptfooconfig.yaml`
- `evals/prompts/feature-plan.txt`
- `evals/tests/feature-plan.yaml`

You should add tasks that match your actual work:

- React bug triage
- large refactor planning
- API integration changes
- current-doc lookup questions

## Provider Note

The starter config uses one OpenAI provider and one Anthropic provider so you can compare the two families directly.

You should edit the model IDs to match the exact models you actually use.
