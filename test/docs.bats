#!/usr/bin/env bats
# Covers shell/docs: each directory under test/fixtures is one label the
# contract pass reads, and lowering its source through shell-tree and the
# pass gives the tree recorded beside it; the greet fixture, lowered under the path it has in shellops,
# gives the tree and the page shellops' own goldens hold, and the index
# over two trees lists both. The docgen kind loads docusaurus from beside
# the library and a second system from a fixture, docs__write renders a
# library, the greet fixture copied as lib/greet.sh, for either, and
# cli/docs does the same from the command line.

bats_require_minimum_version 1.5.0

REPO="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export SHELLOPS_DIR="${SHELLOPS_DIR:-$REPO/shell/.ops}"
export SHELL_SCAN_DIR="${SHELL_SCAN_DIR:-$REPO/shell/.scan}"
export SHELL_TREE_DIR="${SHELL_TREE_DIR:-$REPO/shell/.tree}"
export SHELL_DOCS_DIR="$REPO"
export PROJ="$REPO"

load "$SHELLOPS_DIR/test/lib/bats-support/load.bash"
load "$SHELLOPS_DIR/test/lib/bats-assert/load.bash"

setup() {
  # shellcheck source=/dev/null
  . "$SHELLOPS_DIR/.envrc"
  import "$REPO/shell/docs/api.sh"
  docs__docgen__load_all "$REPO/shell/docs"
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

  run docs__page docusaurus "$REPO/test/fixtures/greet/tree.json"
  assert_success
  assert_output "$(cat "$REPO/test/fixtures/greet/page.md")"
}

@test "docs__index: one row per tree, in the order given, with the reach and the doc's first line" {
  run docs__index docusaurus "$REPO/test/fixtures/module/tree.json" "$REPO/test/fixtures/greet/tree.json"
  assert_success
  assert_output "$(cat "$REPO/test/fixtures/index.md")"
}

# A library of one module under $BATS_TEST_TMPDIR: the greet fixture as
# lib/greet.sh, so its page and index name the path shellops' goldens use.
# Moves into the directory and prints it.
library_of_greet() {
  mkdir -p "$BATS_TEST_TMPDIR/lib"
  cp "$REPO/test/fixtures/greet/source.sh" "$BATS_TEST_TMPDIR/lib/greet.sh"
  cd "$BATS_TEST_TMPDIR" || return 1
}

@test "docs__modules: every .sh file beneath the library in byte order, and no fixture, plugin or template" {
  library_of_greet
  mkdir -p lib/deep
  touch lib/deep/api.sh lib/map.fixture.sh lib/int.type.op.sh lib/run.template.sh lib/notes.txt

  run docs__modules lib
  assert_success
  assert_line --index 0 "lib/deep/api.sh"
  assert_line --index 1 "lib/greet.sh"
  assert_equal "${#lines[@]}" 2
}

@test "docgen: docusaurus loads from beside the library, with its summary, and names its page and index paths" {
  assert_equal "$(@get "$(docs__docgen__names)" '.[0]')" docusaurus
  run docs__docgen__summary docusaurus
  assert_output --partial "Docusaurus"
  run docs__docgen__page_path docusaurus shell/silt/get.sh
  assert_output "shell/silt/get.md"
  run docs__docgen__index_path docusaurus
  assert_output "README.md"
}

@test "docs__write: renders the library for docusaurus to a page per module and the index recorded beside the greet fixture, emptying the directory first" {
  library_of_greet
  mkdir -p out/lib
  touch out/lib/gone.md

  docs__write docusaurus lib out

  assert [ ! -f out/lib/gone.md ]
  run diff "$REPO/test/fixtures/greet/page.md" out/lib/greet.md
  assert_success
  run diff "$REPO/test/fixtures/greet/library.md" out/README.md
  assert_success
}

@test "docs__write: a second docs system is a plugin and nothing else, so the same library renders for it to its own pages and index" {
  library_of_greet
  docs__docgen__load_all "$REPO/test/fixtures/docgen"

  docs__write plain lib out

  assert_equal "$(cat out/lib/greet.txt)" "page of lib/greet.sh"
  assert_equal "$(cat out/INDEX.txt)" "lib/greet.sh"
  assert [ ! -f out/README.md ]
}

@test "cli/docs: renders the library given under --out and says how many pages, lists the systems, and refuses a missing library and an unknown system" {
  library_of_greet

  run "$REPO/cli/docs" --out reference lib
  assert_success
  assert_output "wrote reference: 1 pages and README.md"
  assert [ -f reference/lib/greet.md ]
  assert [ -f reference/README.md ]

  run "$REPO/cli/docs" --list
  assert_success
  assert_line --partial "docusaurus  Markdown pages"

  run "$REPO/cli/docs" --out reference missing
  assert_failure
  assert_output --partial "missing is not a directory"

  run "$REPO/cli/docs" --system mkdocs --out reference lib
  assert_failure
  assert_output --partial "no docs system named mkdocs; the systems are docusaurus"
}

@test "test/fixtures: every label fixture has a source and a recorded tree, and every recorded tree is covered above; docgen holds the second system" {
  for dir in "$REPO"/test/fixtures/*/; do
    label="$(basename "$dir")"
    if [ "$label" = docgen ]; then
      continue
    fi
    assert [ -f "$dir/source.sh" ]
    assert [ -f "$dir/tree.json" ]
    if [ "$label" != greet ]; then
      assert grep -q "assert_tree $label\$" "$REPO/test/docs.bats"
    fi
  done
}
