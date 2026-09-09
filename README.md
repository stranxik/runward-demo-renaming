# The rename demo — green tests, red gate

One repository, one honest refactor, and the gap every test suite leaves open.

## Replay it yourself (three commands)

```sh
npx runward@0.37.1 init --example   # the mission: a small triage service, documented and gated
cd code && npm ci && npm test       # 14 tests, green
cd .. && npx runward@0.37.1 check --strict   # exit 0 — the delivery record matches the code
```

Now check out the `refactor/rename-guard-fields` branch — a clean rename of
`guardFields` to `applyFieldGuards`, applied everywhere in the code, tests included:

```sh
cd code && npm test                          # still green — the code works
cd .. && npx runward@0.37.1 check --strict   # exit 1 — two typed pointers now cite a function that no longer exists
```

One of the two dead pointers is in the **threat model**: the security record now speaks
of a function the codebase does not contain. The tests say the code works. They do not
say it is shippable.

## The repair (this is a tool, not a judge)

The `refactor/rename-repaired` branch updates the two pointers to the new symbol:

```sh
npx runward@0.37.1 check --strict   # exit 0 again
```

The gate never asked for a rollback — it asked for the record to match reality, and it
said exactly which two lines did not.

## What this is

[runward](https://github.com/stranxik/runward) is a deterministic, zero-LLM delivery
gate: the coding agent executes, the human ratifies, and the record either matches the
tree or the gate says so. No network, no model call in the verdict path.
