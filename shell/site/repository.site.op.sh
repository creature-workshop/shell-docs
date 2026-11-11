#!/usr/bin/env bash

import \
  "$SHELLOPS_DIR/lib/git/api.sh" \
  "$SHELLOPS_DIR/lib/git/branches.sh" \
  "$SHELLOPS_DIR/lib/git/commits.sh" \
  "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'DOC'
A repository, the first system of the site kind (site.sh says what the
roles mean): the site is one branch of the repository the command runs in,
`branch` of the site's declaration, published by default. A checkout is a
detached worktree at the branch's tip on origin, and the token is that tip,
so a put refuses a branch another put moved meanwhile. A branch origin does
not have yet starts from a root commit holding no files. A put commits
everything under the checkout as the bot, through shellops' git-commit,
which commits nothing when nothing changed, and pushes with a lease on the
tip; when FORGE_ADMIN_TOKEN is set, the push carries it as the bot's token
the way shellops' git auth action sets it up.
DOC

# CONST: The branch when the site's declaration names none.
__site__repository__DEFAULT_BRANCH=published

@site.repository() {
  @summary() {
    println "One branch of this repository, checked out as a worktree and pushed with a lease."
  }

  @needs() {
    @arr __site__repository__needs__out git
    println "$__site__repository__needs__out"
  }

  @checkout() {
    __site__repository__checkout "$1" "$(__site__repository__branch "$2")"
  }

  @put() {
    __site__repository__put "$1" "$(__site__repository__branch "$2")" "$3" "$4" "$5" "$6"
  }

  @stage() {
    rm -rf "${2:?}"
    mkdir -p "$2"
    cp -R "$1/." "$2/"
    rm -rf "$2/.git"
  }

  @close() {
    git__worktree_remove "$1"
  }
}

: <<'FUN'
Prints the branch the site's declaration <settings> names, or the default.
FUN
__site__repository__branch() {
  @get __site__repository__branch__out "$1" '.branch' "$__site__repository__DEFAULT_BRANCH"
  println "$__site__repository__branch__out"
}

: <<'FUN'
Checks the branch <branch> out at its tip on origin as a detached worktree
at <dir>, or from a root commit holding no files when origin has no such
branch, and prints the tip, empty when there was none.

args:
  $1  The worktree's directory
  $2  The branch
FUN
__site__repository__checkout() {
  __site__repository__checkout__tip="$(git__remote_branch_tip origin "$2")"
  if @defined "$__site__repository__checkout__tip"; then
    git__worktree_checkout "$1" "$__site__repository__checkout__tip"
  else
    git__worktree_checkout "$1" "$(git__commits__empty "docs: $2" "")"
  fi
  println "$__site__repository__checkout__tip"
}

: <<'FUN'
Commits everything under the worktree <dir> as the bot and points <branch>
on origin at it, with a lease on <tip>. Sets the bot as the repository's
identity first, and its token for the push when FORGE_ADMIN_TOKEN is set.

args:
  $1  The worktree's directory
  $2  The branch
  $3  The tip the worktree was checked out from, or empty
  $4  The commit's message
  $5  The bot's name
  $6  The bot's email
FUN
__site__repository__put() {
  (cd "$1" && "$SHELLOPS_DIR/action" git config "$5" "$6")
  (cd "$1" && "$SHELLOPS_DIR/cli/git-commit" --all -m "$4")
  if @defined "${FORGE_ADMIN_TOKEN:-}"; then
    (cd "$1" && "$SHELLOPS_DIR/action" git auth "$5" "$FORGE_ADMIN_TOKEN")
  fi
  git__force_move_branch \
    origin \
    "$2" \
    "$3" \
    "$(git__worktree_head "$1")"
}
