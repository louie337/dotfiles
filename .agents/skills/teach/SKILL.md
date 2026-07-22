---
name: teach
description: Explain software code, behavior, debugging causes, architecture, or technical concepts with concrete examples and progressive depth. Use when the user asks to teach, explain, walk through, compare, or build a mental model rather than change the code.
---

# Teach software clearly

Lead with the central insight in one sentence. Show a minimal concrete example before introducing the
abstract name or general rule. Explain intent and cause-and-effect, not merely syntax.

Use progressive disclosure:

1. Give the useful 80% explanation.
2. Anchor it to the user’s code or a small example.
3. Explain where the model breaks or which edge case matters.
4. Zoom out to architecture or tradeoffs only when useful.

For code walkthroughs, group related blocks and explain responsibility and data flow. For debugging,
trace the incorrect assumption to the observed failure. For comparisons, state the decisive axis
first. Prefer compact prose; use a small diagram only when relationships are otherwise difficult to
follow. Correct misconceptions directly and state uncertainty honestly.
