#!/usr/bin/env bats
# Covers shell/docs: each directory under test/fixtures is one label the
# contract pass reads, and lowering its source through shell-tree and the
# pass gives the tree recorded beside it; the greet fixture, lowered under the path it has in shellops,
# gives the tree and the page shellops' own goldens hold, and the index
# over two trees lists both.

bats_require_minimum_version 1.5.0

REPO="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
SHELLOPS_DIR="${SHELLOPS_DIR:-$REPO/shell/.ops}"
export SHELL_SCAN_DIR="${SHELL_SCAN_DIR:-$REPO/shell/.scan}"
export SHELL_TREE_DIR="${SHELL_TREE_DIR:-$REPO/shell/.tree}"
export SHELL_DOCS_DIR="$REPO"

load "$SHELLOPS_DIR/test/lib/bats-support/load.bash"
load "$SHELLOPS_DIR/test/lib/bats-assert/load.bash"

setup() {
  # shellcheck source=../shell/docs/api.sh
  . "$REPO/shell/docs/api.sh"
}

# Asserts that the tree of the fixture named <label>, lowered under the path
# its source has in this repository, is the one recorded in its tree.json.
assert_tree() {
  run docs__tree "$REPO/test/fixtures/$1/source.sh" "test/fixtures/$1/source.sh"
  assert_success
  assert_output "$(cat "$REPO/test/fixtures/$1/tree.json")"
}

@test "docs__tree: MODULE on the first doc block is the file's doc, and the reach is module" {
  assert_tree module
}

@test "docs__tree: FRAGMENT on the first doc block makes the reach fragment" {
  assert_tree fragment
}

@test "docs__tree: PUB_FUN makes a function public, its args section fills the contract, and a parted doc attaches to nothing" {
  assert_tree pub-fun
}

@test "docs__tree: FUN makes a function private whatever its name, and an undocumented function is judged by its name" {
  assert_tree fun
}

@test "docs__tree: PUB_CONST documents a public constant, as a heredoc or as a one-line comment with a continuation" {
  assert_tree pub-const
}

@test "docs__tree: CONST documents a private constant, and an assignment with no doc gets no node" {
  assert_tree const
}

@test "docs__tree: PUB_VAR documents a public variable, exported or not" {
  assert_tree pub-var
}

@test "docs__tree: VAR documents a private variable, and an enum declaration is read as an assignment" {
  assert_tree var
}

@test "docs__tree: HELP is a data heredoc the lowering reads past, so an entrypoint has no file doc" {
  assert_tree help
}

@test "docs__tree: the path defaults to the source, and a source given with no path is named by it" {
  run docs__tree "$REPO/test/fixtures/module/source.sh"
  assert_success
  assert_output --partial "\"name\":\"$REPO/test/fixtures/module/source.sh\""
}

@test "docs__tree and docs__page: the greet fixture lowers to the tree and renders to the page shellops' goldens hold" {
  run docs__tree "$REPO/test/fixtures/greet/source.sh" lib/greet.sh
  assert_success
  assert_output "$(cat "$REPO/test/fixtures/greet/tree.json")"

  run docs__page "$REPO/test/fixtures/greet/tree.json"
  assert_success
  assert_output "$(cat "$REPO/test/fixtures/greet/page.md")"
}

@test "docs__index: one row per tree, in the order given, with the reach and the doc's first line" {
  run docs__index "$REPO/test/fixtures/module/tree.json" "$REPO/test/fixtures/greet/tree.json"
  assert_success
  assert_output "$(cat "$REPO/test/fixtures/index.md")"
}

@test "test/fixtures: every label fixture has a source and a recorded tree, and every recorded tree is covered above" {
  for dir in "$REPO"/test/fixtures/*/; do
    label="$(basename "$dir")"
    assert [ -f "$dir/source.sh" ]
    assert [ -f "$dir/tree.json" ]
    if [ "$label" != greet ]; then
      assert grep -q "assert_tree $label\$" "$REPO/test/docs.bats"
    fi
  done
}
