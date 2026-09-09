---
name: runward-topology
description: "Runward execution topology craft rules. Use when deciding where each port's adapter runs and under which data sovereignty: placement family, the secrets/network boundary, or third-party trace export."
---

# Runward — execution topology craft

Use this when deciding where each port's adapter runs and under which data sovereignty: placement family, the secrets/network boundary, or third-party trace export.

Confront the CRITICAL/HIGH craft rules mapped to the `topology` phase, at the point of action and not from memory. Ask for them rather than guessing: `runward rules --phase topology` lists them, and `runward rules --for <paths>` narrows to the rules whose declared territory covers the files you are touching. Then read what comes back — `runward explain <rule>` prints a rule's why and full text. Naming a rule is not confronting it. Account for each in the deliverable's `## Rule conformance` manifest — `runward manifest --sync` scaffolds the missing rows; you fill the decision: `applied` with a typed pointer the gate verifies (`file:PATH[:LINE][#SYMBOL]`, `test:PATH[::NAME]`) or prose, `deviated` with an ADR, or `n/a` with a real reason. Signed rules (frontmatter `signature:`) need evidence whose content matches their signature.

This skill helps you *apply* the rules; it does not enforce them. `runward check --strict` is the sole authority and verifies the manifest deterministically. A rule surfaced here but not accounted for still fails the gate.
