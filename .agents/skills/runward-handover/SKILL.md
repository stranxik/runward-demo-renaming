---
name: runward-handover
description: "Runward hand-over craft rules. Use when preparing or executing a succession: the recovery runbook, finalizing the agent charter as a leave-behind, the redone-task proof, or naming the owner who inherits the system."
---

# Runward — hand-over craft

Use this when preparing or executing a succession: the recovery runbook, finalizing the agent charter as a leave-behind, the redone-task proof, or naming the owner who inherits the system.

Confront the CRITICAL/HIGH craft rules mapped to the `handover` phase, at the point of action and not from memory. Ask for them rather than guessing: `runward rules --phase handover` lists them, and `runward rules --for <paths>` narrows to the rules whose declared territory covers the files you are touching. Then read what comes back — `runward explain <rule>` prints a rule's why and full text. Naming a rule is not confronting it. Account for each in the deliverable's `## Rule conformance` manifest — `runward manifest --sync` scaffolds the missing rows; you fill the decision: `applied` with a typed pointer the gate verifies (`file:PATH[:LINE][#SYMBOL]`, `test:PATH[::NAME]`) or prose, `deviated` with an ADR, or `n/a` with a real reason. Signed rules (frontmatter `signature:`) need evidence whose content matches their signature.

This skill helps you *apply* the rules; it does not enforce them. `runward check --strict` is the sole authority and verifies the manifest deterministically. A rule surfaced here but not accounted for still fails the gate.
