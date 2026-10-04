#!/usr/bin/env bats
# The golden filesets of shell-docs, under test/fixtures/goldens/, run
# through shell-goldens at shell/.golden. One fileset is one case, in a
# directory of its own named for it: name.txt is its name and the test's
# name in the log, about.txt explains it in plain words and prints when the
# case fails, calls.txt lists the calls test/docs-transcript.sh runs, and
# expected.txt is the transcript they must write. A source a call lowers
# sits in the fileset beside the calls. Every fileset is registered as a
# test of its own, so a new case is a new directory and no new test code.
# UPDATE_GOLDENS=1 rewrites the expected.txt files from the live answers,
# to be read before they are committed.

bats_require_minimum_version 1.5.0

REPO="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
GOLDEN_FIXTURES="$BATS_TEST_DIRNAME/fixtures/goldens"
export SHELLOPS_DIR="${SHELLOPS_DIR:-$REPO/shell/.ops}"
export SHELL_DOCS_DIR="$REPO"
export PROJ="$REPO"

load "$SHELLOPS_DIR/test/lib/bats-support/load.bash"
load "$SHELLOPS_DIR/test/lib/bats-assert/load.bash"
load "$REPO/shell/.golden/shell/golden/bats.sh"

# The transcript of a fileset's calls: the script run on its calls file.
transcript() {
  "$REPO/test/docs-transcript.sh" "$GOLDEN_FIXTURES/$1/calls.txt"
}

golden__register transcript
