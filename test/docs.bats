#!/usr/bin/env bats
# Covers what the goldens (test/docs-goldens.bats) cannot: the default name
# of a tree, the docgen kind loading docusaurus from beside the library,
# docs__modules over a directory with files of every kind, docs__write
# emptying its directory, and cli/docs from the command line. What a tree,
# a page, an index and a library's render look like is the goldens'.

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

@test "docs__tree: the path defaults to the source, and a source given with no path is named by it" {
  run docs__tree "$REPO/test/fixtures/goldens/module/source.sh"
  assert_success
  assert_output --partial "\"name\":\"$REPO/test/fixtures/goldens/module/source.sh\""
}

# A library of one module under $BATS_TEST_TMPDIR: the greet fixture as
# lib/greet.sh, so its page and index name the path shellops' goldens use.
# Moves into the directory and prints it.
library_of_greet() {
  mkdir -p "$BATS_TEST_TMPDIR/lib"
  cp "$REPO/test/fixtures/goldens/greet/source.sh" "$BATS_TEST_TMPDIR/lib/greet.sh"
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

@test "docs__write: empties the directory first, so a module that is gone leaves no page" {
  library_of_greet
  mkdir -p out/lib
  touch out/lib/gone.md

  docs__write docusaurus lib out

  assert [ ! -f out/lib/gone.md ]
  assert [ -f out/lib/greet.md ]
  assert [ -f out/README.md ]
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
