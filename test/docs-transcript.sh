#!/usr/bin/env bash
# shellcheck disable=SC2034  # GOLDEN_ANSWER and GOLDEN_STATUS are read by the driver this script sources
set -uo pipefail
. "$SHELLOPS_DIR/.envrc"

: <<'HELP'
Writes the transcript of one golden fileset for test/docs-goldens.bats
through the driver of shell-goldens, shell/.golden: every call in the calls
file under a "## " line, its answer below it, and "!! <status> <message>"
when the call fails. This script supplies the hook that runs one call. A
file a call names is beside the calls file unless absolute.

Usage: test/docs-transcript.sh <calls>

The calls:
  tree <source> <path>             The tree of the module at <source>, named <path>.
  page <system> <source> <path>    The page <system> renders for that tree.
  index <system> <source...>       The index <system> renders over the trees of
                                   the sources, each named as written.
  modules <dir>                    The modules docs__modules lists under <dir>.
  write <system> <dir>             The files docs__write writes for <system>
                                   over the library under <dir>, each under a
                                   "--- <path>" line.
  snapshot <system> <project> <version> <dir>
                                   The files a snapshot of the pages rendered
                                   for <system> over <dir> writes into an
                                   empty site, as that version of the project,
                                   each under a "--- <path>" line.
HELP

SHELL_DOCS_DIR="${SHELL_DOCS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export SHELL_DOCS_DIR
export SHELL_SCAN_DIR="${SHELL_SCAN_DIR:-$SHELL_DOCS_DIR/shell/.scan}"
export SHELL_TREE_DIR="${SHELL_TREE_DIR:-$SHELL_DOCS_DIR/shell/.tree}"

import "$SHELL_DOCS_DIR/shell/docs/api.sh"
. "$SHELL_DOCS_DIR/shell/.golden/shell/golden/api.sh"

main() {
  require_usage "$@"
  docs__docgen__load_all "$SHELL_DOCS_DIR/shell/docs"
  docs__docgen__load_all "$SHELL_DOCS_DIR/test/fixtures/docgen"
  SCRATCH="$(mktemp -d)"
  trap 'rm -rf "$SCRATCH"' EXIT

  golden__transcribe run_call "$1"
}

: <<'FUN'
Exits with the usage when no calls file is named.
FUN
require_usage() {
  if [ "$#" -ne 1 ]; then
    error "usage: test/docs-transcript.sh <calls>"
    exit 2
  fi
}

: <<'FUN'
Runs one call line: its verb on the rest of the line, from the calls
file's directory, so a relative path in a call means the same in the
transcript as in the fileset.
FUN
run_call() {
  __run_call__rest="$(golden__argument_of "$1")"
  # shellcheck disable=SC2086  # the call's words are split on purpose
  case "${1%% *}" in
    tree) run_tree $__run_call__rest ;;
    page) run_page $__run_call__rest ;;
    index) run_index $__run_call__rest ;;
    modules) run_modules $__run_call__rest ;;
    write) run_write $__run_call__rest ;;
    snapshot) run_snapshot $__run_call__rest ;;
    *) GOLDEN_STATUS=127 ;;
  esac
}

: <<'FUN'
Answers the tree of the module at <source>, named <path>.
FUN
run_tree() {
  golden__capture docs__tree "$(golden__file_of "$1")" "$2" > "$SCRATCH/answer"
  answer_from_scratch
}

: <<'FUN'
Answers the page <system> renders for the module at <source>, named
<path>.
FUN
run_page() {
  golden__capture docs__tree "$(golden__file_of "$2")" "$3" > "$SCRATCH/page.tree.json"
  golden__capture docs__page "$1" "$SCRATCH/page.tree.json" > "$SCRATCH/answer"
  answer_from_scratch
}

: <<'FUN'
Answers the index <system> renders over the trees of <source...>, each
named as written in the call.
FUN
run_index() {
  __run_index__system="$1"
  shift
  __run_index__n=0
  for __run_index__source in "$@"; do
    __run_index__n=$((__run_index__n + 1))
    golden__capture docs__tree "$(golden__file_of "$__run_index__source")" "$__run_index__source" \
      > "$(printf '%s/%03d.tree.json' "$SCRATCH" "$__run_index__n")"
  done
  golden__capture docs__index "$__run_index__system" "$SCRATCH"/[0-9][0-9][0-9].tree.json > "$SCRATCH/answer"
  rm -f "$SCRATCH"/[0-9][0-9][0-9].tree.json
  answer_from_scratch
}

: <<'FUN'
Answers the modules docs__modules lists under <dir>, from the calls
file's directory.
FUN
run_modules() {
  cd "$GOLDEN_CALLS_DIR" || return 1
  golden__capture docs__modules "$1" > "$SCRATCH/answer"
  cd "$OLDPWD" || return 1
  answer_from_scratch
}

: <<'FUN'
Answers the files docs__write writes for <system> over the library under
<dir>, each under a "--- <path>" line, in byte order of their paths.
FUN
run_write() {
  rm -rf "$SCRATCH/out"
  cd "$GOLDEN_CALLS_DIR" || return 1
  golden__capture docs__write "$1" "$2" "$SCRATCH/out"
  cd "$OLDPWD" || return 1
  list_written > "$SCRATCH/answer"
  answer_from_scratch
}

: <<'FUN'
Answers the files a snapshot of the pages rendered for <system> over the
library under <dir> writes into an empty site, as the version <version> of
the project <project>, each under a "--- <path>" line.
FUN
run_snapshot() {
  rm -rf "$SCRATCH/pages" "$SCRATCH/out"
  cd "$GOLDEN_CALLS_DIR" || return 1
  golden__capture docs__write "$1" "$4" "$SCRATCH/pages"
  cd "$OLDPWD" || return 1
  mkdir -p "$SCRATCH/out"
  golden__capture docs__docgen__snapshot "$1" "$SCRATCH/pages" "$SCRATCH/out" "$2" "$3"
  list_written > "$SCRATCH/answer"
  answer_from_scratch
}

: <<'FUN'
Prints every file under the written reference, each under a "--- <path>"
line, in byte order of their paths.
FUN
list_written() {
  cd "$SCRATCH/out" || return 1
  find . -type f | LC_ALL=C sort | while IFS= read -r __list_written__file; do
    printf -- '--- %s\n' "${__list_written__file#./}"
    cat "$__list_written__file"
  done
  cd "$OLDPWD" || return 1
}

: <<'FUN'
Takes the answer written to the scratch file, so the status a call kept in
GOLDEN_STATUS is not lost in a subshell.
FUN
answer_from_scratch() {
  GOLDEN_ANSWER="$(cat "$SCRATCH/answer")"
}

main "$@"
