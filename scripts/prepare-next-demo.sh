#!/usr/bin/env bash
# Prepare the next demonstration: put the repository back at its start.
#
# The start is: the base branch is clean (the code and the delivery record cite the same name), and two
# pull requests into it are open:
#   - the rename: the code moves to the other name, the record still cites the current one
#     (tests green, runward check refused);
#   - the repair: on top of the rename, the two pointers of the record follow (runward check clean).
#
# The demonstration alternates between two names, so it never needs a revert, a merge back or a forced
# push: after guardFields -> applyFieldGuards has been integrated and repaired, the next one is
# applyFieldGuards -> guardFields.
#
# Idempotent: it reads what is there (by content, never by branch name) and only adds what is missing.
# Run twice in a row, the second run changes nothing. It never pushes to the base branch, never forces,
# never merges, never closes or deletes anything.
#
# Environment: BASE (default main), DRY_RUN (true|false, default false), GH_TOKEN, GITHUB_REPOSITORY.
# Exit: 0 the start is in place; 3 it is not yet (the summary says what to integrate first);
#       1 something is not as this script expects, and nothing was forced.
set -euo pipefail

BASE="${BASE:-main}"
DRY_RUN="${DRY_RUN:-false}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${REPO}/actions/runs/${GITHUB_RUN_ID:-local}"

NAME_A="guardFields"
NAME_B="applyFieldGuards"
GUARD="code/src/core/domain/guard.ts"
RECORDS=("runward/floor.md" "runward/governance/threat-model.md")

[[ "$BASE" =~ ^[A-Za-z0-9._/-]{1,100}$ && "$BASE" != -* ]] || { echo "::error::base is not a branch name"; exit 1; }

say() { echo "$*"; echo "$*" >> "$SUMMARY"; }
other_of() { if [ "$1" = "$NAME_A" ]; then echo "$NAME_B"; else echo "$NAME_A"; fi; }

# The name the code declares at a revision: one of the two, or "unknown".
code_name() {
  local found
  found=$(git show "$1:$GUARD" 2>/dev/null | grep -oE "export function ($NAME_A|$NAME_B)\(" | sed -E 's/export function //; s/\($//' | sort -u || true)
  if [ "$found" = "$NAME_A" ] || [ "$found" = "$NAME_B" ]; then echo "$found"; else echo "unknown"; fi
}

# The name the record cites at a revision: one of the two when every pointer agrees, or "mixed".
record_name() {
  local found f
  found=$(for f in "${RECORDS[@]}"; do git show "$1:$f" 2>/dev/null | grep -oE "guard\.ts#($NAME_A|$NAME_B)\b" || true; done | sed -E 's/.*#//' | sort -u)
  if [ "$found" = "$NAME_A" ] || [ "$found" = "$NAME_B" ]; then echo "$found"; else echo "mixed"; fi
}

git fetch --quiet origin "+refs/heads/*:refs/remotes/origin/*"
git rev-parse --verify --quiet "origin/$BASE" >/dev/null || { echo "::error::no branch $BASE on origin"; exit 1; }
BASE_SHA=$(git rev-parse "origin/$BASE")
SHORT=${BASE_SHA:0:7}
CODE=$(code_name "$BASE_SHA")
RECORD=$(record_name "$BASE_SHA")

{
  echo "### Prepare the next demonstration"
  echo ""
  echo "- base: \`$BASE\` at \`$SHORT\`"
  echo "- the code declares: \`$CODE\`"
  echo "- the record cites: \`$RECORD\`"
  [ "$DRY_RUN" = "true" ] && echo "- dry run: nothing is written"
  echo ""
} >> "$SUMMARY"
echo "base $BASE at $SHORT: code=$CODE record=$RECORD dry-run=$DRY_RUN"

if [ "$CODE" = "unknown" ] || [ "$RECORD" = "mixed" ]; then
  say "Not a state this script knows (code: $CODE, record: $RECORD). Nothing was changed."
  exit 1
fi

# Open pull requests into the base, from this repository, with the state of their head read by content.
find_pr() { # $1 = wanted code name, $2 = wanted record name -> "number<TAB>branch<TAB>sha" lines
  local number branch sha cross
  gh pr list -R "$REPO" --base "$BASE" --state open --limit 100 \
    --json number,headRefName,headRefOid,isCrossRepository \
    -q '.[] | [.number, .headRefName, .headRefOid, .isCrossRepository] | @tsv' |
  while IFS=$'\t' read -r number branch sha cross; do
    [ "$cross" = "false" ] || continue
    git cat-file -e "$sha^{commit}" 2>/dev/null || continue
    if [ "$(code_name "$sha")" = "$1" ] && [ "$(record_name "$sha")" = "$2" ]; then printf '%s\t%s\t%s\n' "$number" "$branch" "$sha"; fi
  done
}

# The first line of what find_pr printed (the newest matching pull request), or nothing.
first_pr() { local all; all=$(find_pr "$1" "$2"); echo "${all%%$'\n'*}"; }

bot_identity() {
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

# Push a new branch (never forced). If the branch is already there with the same tree, it is reused.
push_new_branch() { # $1 = branch
  local remote_sha
  remote_sha=$(git ls-remote --heads origin "$1" | cut -f1)
  if [ -z "$remote_sha" ]; then
    git push --quiet origin "HEAD:refs/heads/$1"
  elif [ "$(git rev-parse "$remote_sha^{tree}")" = "$(git rev-parse "HEAD^{tree}")" ]; then
    echo "branch $1 is already on origin with the same content: reused"
    git reset --quiet --hard "$remote_sha"
  else
    echo "::error::branch $1 exists on origin with another content; nothing is forced"
    exit 1
  fi
}

# The checks of a commit pushed by a workflow are not started by GitHub: start them, once.
ensure_ci() { # $1 = branch, $2 = sha
  local n
  n=$(gh run list -R "$REPO" --workflow ci.yml --commit "$2" --json databaseId -q 'length')
  if [ "$n" = "0" ]; then
    if [ "$DRY_RUN" = "true" ]; then say "- would start the checks of \`$1\`"; else
      gh workflow run ci.yml -R "$REPO" --ref "$1"
      say "- started the checks of \`$1\`"
    fi
  fi
}

make_rename() { # $1 = from, $2 = to, $3 = start point -> sets NEW_BRANCH, NEW_SHA
  NEW_BRANCH="demo/rename-$SHORT"
  git switch --quiet --detach "$3"
  # every use of the name in the code, tests included, as a whole word
  grep -rlw --include='*.ts' -- "$1" code/src code/test | while read -r f; do FROM="$1" TO="$2" perl -pi -e 's/\b\Q$ENV{FROM}\E\b/$ENV{TO}/g' "$f"; done
  if grep -rqw --include='*.ts' -- "$1" code/src code/test; then echo "::error::$1 is still in the code"; exit 1; fi
  bot_identity
  git commit --quiet -am "refactor: rename $1 to $2, everywhere the code knows" \
    -m "The code changes, the tests stay green, and the delivery record still cites $1: runward check --strict refuses this commit until the record follows." \
    -m "Replayed by the workflow that prepares the next demonstration ($RUN_URL): a scripted search and replace. The first rename of this demonstration was made by a coding agent; see the README."
  push_new_branch "$NEW_BRANCH"
  NEW_SHA=$(git rev-parse HEAD)
}

make_repair() { # $1 = from, $2 = to, $3 = start point -> sets NEW_BRANCH, NEW_SHA
  NEW_BRANCH="demo/repair-$SHORT"
  git switch --quiet --detach "$3"
  local f
  for f in "${RECORDS[@]}"; do FROM="$1" TO="$2" perl -pi -e 's/(guard\.ts#)\Q$ENV{FROM}\E\b/$1$ENV{TO}/g' "$f"; done
  bot_identity
  git commit --quiet -am "docs(mission): the record follows the rename: two pointers, nothing else" \
    -m "runward/floor.md and runward/governance/threat-model.md cite $2, the name the code declares. runward check --strict is clean again." \
    -m "Replayed by the workflow that prepares the next demonstration ($RUN_URL): a scripted edit of two pointers. The first repair of this demonstration was made by a coding agent; see the README."
  push_new_branch "$NEW_BRANCH"
  NEW_SHA=$(git rev-parse HEAD)
}

open_pr() { # $1 = branch, $2 = title, $3 = body -> prints the number
  local url
  if ! url=$(gh pr create -R "$REPO" --base "$BASE" --head "$1" --title "$2" --body "$3"); then
    {
      echo "::error::the branch $1 is pushed, and GitHub refused to open its pull request"
      echo "If this runs in GitHub Actions: Settings > Actions > General > allow GitHub Actions to create pull requests, then run this again (it reuses the branch)."
    } >&2
    echo "**Stopped.** \`$1\` is pushed, and GitHub refused to open its pull request. In GitHub Actions this needs the repository setting that lets Actions create pull requests. Run this again afterwards: it reuses the branch." >> "$SUMMARY"
    exit 1
  fi
  echo "${url##*/pull/}"
}

REPLAY_NOTE="Opened by the workflow that prepares the next demonstration ($RUN_URL). It is a scripted replay: the first rename and the first repair of this demonstration were made by a coding agent (see the README)."

# --- the base is refused: the rename is integrated, the record has not followed yet ---------------------
if [ "$CODE" != "$RECORD" ]; then
  REPAIR=$(first_pr "$CODE" "$CODE")
  if [ -n "$REPAIR" ]; then
    IFS=$'\t' read -r R_NUM R_BRANCH R_SHA <<< "$REPAIR"
    say "- repair: #$R_NUM (\`$R_BRANCH\`), already open"
    ensure_ci "$R_BRANCH" "$R_SHA"
  elif [ "$DRY_RUN" = "true" ]; then
    say "- repair: none open; would open one (\`demo/repair-$SHORT\`)"
  else
    make_repair "$RECORD" "$CODE" "$BASE_SHA"
    R_NUM=$(open_pr "$NEW_BRANCH" "docs(mission): the record follows the rename to $CODE (two pointers, runward check clean)" \
      "\`$BASE\` declares \`$CODE\` in the code while the record still cites \`$RECORD\`: the runward check refuses it. This updates the two pointers, nothing else.

$REPLAY_NOTE")
    say "- repair: #$R_NUM (\`$NEW_BRANCH\`), opened"
    ensure_ci "$NEW_BRANCH" "$NEW_SHA"
  fi
  say ""
  say "**Not at the start yet.** \`$BASE\` is refused by the runward check: the rename is integrated and the record has not followed. Integrate the repair${R_NUM:+ (#$R_NUM)}, then run this again."
  exit 3
fi

# --- the base is clean: the two pull requests of the next demonstration must be open --------------------
NEXT=$(other_of "$CODE")
RENAME=$(first_pr "$NEXT" "$CODE")
REPAIR=$(first_pr "$NEXT" "$NEXT")

if [ -n "$RENAME" ]; then
  IFS=$'\t' read -r N_NUM N_BRANCH N_SHA <<< "$RENAME"
  say "- rename \`$CODE\` to \`$NEXT\`: #$N_NUM (\`$N_BRANCH\`), already open"
  ensure_ci "$N_BRANCH" "$N_SHA"
elif [ "$DRY_RUN" = "true" ]; then
  say "- rename \`$CODE\` to \`$NEXT\`: none open; would open one (\`demo/rename-$SHORT\`)"
  N_SHA=""
else
  make_rename "$CODE" "$NEXT" "$BASE_SHA"
  N_BRANCH="$NEW_BRANCH"; N_SHA="$NEW_SHA"
  N_NUM=$(open_pr "$N_BRANCH" "refactor: rename $CODE to $NEXT (tests green, runward check refused)" \
    "A rename of \`$CODE\` to \`$NEXT\`, applied everywhere the code uses it. The tests stay green. The delivery record still cites \`$CODE\` in two places, one of them in the threat model, so \`runward check --strict\` refuses this commit.

$REPLAY_NOTE")
  say "- rename \`$CODE\` to \`$NEXT\`: #$N_NUM (\`$N_BRANCH\`), opened"
  ensure_ci "$N_BRANCH" "$N_SHA"
fi

if [ -n "$REPAIR" ]; then
  IFS=$'\t' read -r R_NUM R_BRANCH R_SHA <<< "$REPAIR"
  say "- repair: #$R_NUM (\`$R_BRANCH\`), already open"
  ensure_ci "$R_BRANCH" "$R_SHA"
elif [ "$DRY_RUN" = "true" ]; then
  say "- repair: none open; would open one (\`demo/repair-$SHORT\`)"
else
  make_repair "$CODE" "$NEXT" "$N_SHA"
  R_NUM=$(open_pr "$NEW_BRANCH" "docs(mission): the record follows the rename to $NEXT (two pointers, runward check clean)" \
    "On top of the rename (#$N_NUM): the two pointers of the record now cite \`$NEXT\`. Two lines, nothing else. \`runward check --strict\` is clean again.

Integrate the rename first, then this one.

$REPLAY_NOTE")
  say "- repair: #$R_NUM (\`$NEW_BRANCH\`), opened"
  ensure_ci "$NEW_BRANCH" "$NEW_SHA"
fi

say ""
if [ "$DRY_RUN" = "true" ]; then
  say "Dry run: this is what a real run would find and do."
else
  say "**Ready.** \`$BASE\` is clean; integrate #$N_NUM to play the rename, then #$R_NUM to repair."
fi
