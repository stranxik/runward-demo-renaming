# The rename demo: green tests, red gate

One repository, one honest refactor, and the gap every test suite leaves open.

A name changes in the code. The tests stay green. The delivery record, threat model included, still
cites the old name, so `runward check --strict` refuses the commit and says which two lines no longer
describe the code. The repair is those two lines.

## See it without installing anything

Every commit runs the same workflow ([`ci.yml`](.github/workflows/ci.yml)), and its jobs sit side by side:

| Job | Base branch | The rename | The repair |
|---|---|---|---|
| `tests (the code works)` | green | green | green |
| `runward gate (the delivery holds)` | green | **red** | green |

The rename and its repair are the two open pull requests of this repository. The first rename and the
first repair on this workflow were made by a coding agent: their commits carry a `Claude-Session` line.
Later rounds are replayed by a script (see "Replaying the demonstration").

## Replay it yourself

```sh
git clone https://github.com/stranxik/runward-demo-renaming && cd runward-demo-renaming
(cd code && npm ci && npm test)        # 14 tests, green
npx runward@0.46.0 check --strict      # exit 0: the delivery record matches the code
```

Now check out the branch of the open rename pull request and run the same commands:

```sh
(cd code && npm test)                  # still green: the code works
npx runward@0.46.0 check --strict      # exit 1: two typed pointers cite a name the code no longer declares
```

One of the two dead pointers is in the **threat model**: the security record now speaks of a name the
codebase does not contain. The tests say the code works. They do not say it is shippable.

On the branch of the repair pull request, the two pointers cite the new name:

```sh
npx runward@0.46.0 check --strict      # exit 0 again
```

The gate never asked for a rollback. It asked for the record to match the code, and it said exactly
which two lines did not.

The CI does not use `npx`: it downloads the `runward` 0.46.0 tarball from the npm registry, compares its
sha512 with the published integrity, and installs it outside the checkout, without scripts.

## What the CI keeps

- **`check-json`**, an artifact of every run: the file `runward check --strict --json` wrote for that
  commit, refused or not.

  ```sh
  gh run download <run-id> -R stranxik/runward-demo-renaming -n check-json
  ```

- **`static-page`**, an artifact of every run: the page `runward-fleet` builds from that `check.json`.
  `runward-fleet` is not on npm; the job takes it from one pinned commit of `stranxik/runward`
  (`5a9cdf08a76977f9b671662f562e98d332ccc95e`, on `main`), never from a branch head, and checks that
  this is the commit it got. The page is a CI artifact only: this repository publishes it nowhere.

## Sending the check to runward hosted (wired, off)

`ci.yml` calls the reusable workflow `send.yml` of
[`stranxik/runward-hosted`](https://github.com/stranxik/runward-hosted). The call is skipped unless the
repository variable **`RUNWARD_HOSTED_SEND`** is exactly `on`. It is unset today, and stays unset until
the service is deployed and `send.yml` has its first release.

To turn it on, in this order:

1. Replace the commit after `send.yml@` in `ci.yml` by **the commit of the first release of
   `runward-hosted`**. The commit pinned today is not a release: it is the commit of `main` that last
   changed `send.yml`, kept only so that the reference resolves.
2. Declare the mission `runward-demo-renaming` in the app.
3. Set the variable: `gh variable set RUNWARD_HOSTED_SEND -R stranxik/runward-demo-renaming --body on`.

To turn it off: `gh variable delete RUNWARD_HOSTED_SEND -R stranxik/runward-demo-renaming`.

What `send.yml` does, as written today: it accepts `runward` 0.46.0 only, runs the check again in its own
job, and sends the result only on a push to `main`. On any other branch or event it sends nothing.

## Replaying the demonstration

The demonstration alternates between two names, `guardFields` and `applyFieldGuards`, so replaying it
never needs a revert or a forced push. Once a rename and its repair are both integrated, the next round
renames the other way.

**Actions > "prepare the next demonstration" > Run workflow** (it also runs from the GitHub mobile app)
puts the repository back at its start: the base branch clean, a rename and its repair open as two pull
requests, their checks started. It reads the state by content, only adds what is missing, and a second
run changes nothing. It never pushes to `main`, never forces, never merges, never closes or deletes
anything. If `main` is refused because a rename was integrated without its repair, it makes sure the
repair is open, says which pull request to integrate first, and ends red until that is done.

The pull requests it opens are scripted replays (a search and replace, then an edit of two pointers), and
their commits say so.

It needs one repository setting: Settings > Actions > General > "Allow GitHub Actions to create and
approve pull requests".

## What this is

[runward](https://github.com/stranxik/runward) is a deterministic, zero-LLM delivery
gate: the coding agent executes, the human ratifies, and the record either matches the
tree or the gate says so. No network, no model call in the verdict path.

It does not review the code and does not run it: the tests do that. It checks that the evidence the
team requires exists, and still describes what was delivered.

The mission in `runward/` was scaffolded with runward 0.37.1 and is checked as it stands by runward
0.46.0; its rule set has not been refreshed to 0.46.0.
