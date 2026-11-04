#!/bin/sh

import \
  "$SHELLOPS_DIR/lib/structs/api.sh" \
  "$SHELL_DOCS_DIR/shell/docs/docgen.sh"

: <<'MODULE'
The doc extractor as shell functions, for a host that holds the three
repositories: the tree of a module, which is the same whatever docs system
renders it, and the reference of a whole library written for one docs
system, one page per module and an index under one directory. A docs
system is a plugin of the docgen kind (docgen.sh); docusaurus is the first.
The host exports SHELL_SCAN_DIR, SHELL_TREE_DIR and SHELL_DOCS_DIR, the
roots of its copies of shell-scan, shell-tree and this repository, boots
shellops, and imports this file; cli/docs is the entry point that does so
and writes a library's reference.

  docs__tree shell/silt/get.sh                      ->  {"role":"module","name":"shell/silt/get.sh","payload":[...]}
  docs__page docusaurus get.tree.json               ->  # shell/silt/get.sh (module) ...
  docs__write docusaurus shell/silt .ops/docs       ->  .ops/docs/shell/silt/get.md ... and .ops/docs/README.md
MODULE

: <<'PUB_FUN'
Prints the tree of the module at <source>: one JSON document, the module
node with a node per root function and per documented root constant or
variable, each carrying its doc and its contract. The source is lowered by
shell-tree and the contract pass derives the module node from that.

args:
  <source>  The module's file
  <path>    The name the tree carries, the module's path under its
            repository; <source> when left out
PUB_FUN
docs__tree() {
  __docs__tree__path="${2:-$1}"
  awk \
    -v path="$__docs__tree__path" \
    -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
    -f "$SHELL_TREE_DIR/shell/tree/tree.awk" \
    "$1" \
    | jq -c -f "$SHELL_DOCS_DIR/shell/docs/contract.jq"  # structs-lint: allow -- the contract pass is a jq program over the lowering's document, not a struct value
}

: <<'PUB_FUN'
Prints the page the docs system <system> renders for the module whose
tree is in the file <tree>. With <source>, the URL the module's source
files are at for the version rendered, a system that links a page to its
source links this one to the module under it.

Usage: docs__page <system> <tree> [<source>]
PUB_FUN
docs__page() {
  docs__docgen__page "$1" "$2" "${3:-}"
}

: <<'PUB_FUN'
Prints the index the docs system <system> renders over the modules whose
trees are in the files <trees...>, one entry each, in the order given.

Usage: docs__index <system> <trees...>
PUB_FUN
docs__index() {
  docs__docgen__index "$@"
}

: <<'PUB_FUN'
Prints the modules of the library at <dir>, one path per line in byte
order, each the directory given followed by the path under it: every .sh
file beneath it that is a module. A fixture (*.fixture.sh), a plugin
(*.op.sh), whose docs are its kind's to carry, and a template for an entry
point (*.template.sh) have no page.

  docs__modules shell/silt  ->  shell/silt/all.sh
                                shell/silt/answer.sh
                                ...
PUB_FUN
docs__modules() {
  find "$1" -type f -name '*.sh' \
    ! -name '*.fixture.sh' \
    ! -name '*.op.sh' \
    ! -name '*.template.sh' \
    | LC_ALL=C sort
}

: <<'PUB_FUN'
Writes the reference of the library at <dir> for the docs system <system>
under <out>: the page of every module at the path the system gives, and
the index over them at the path the system gives, in the order
docs__modules lists them. <out> is emptied first, so a module that is gone
leaves no page behind. With <source>, the URL the library's files are at
for the version rendered, a system that links a page to its source links
each page to its module under it.

args:
  $1  The docs system's name
  $2  The library's directory, relative to the current directory
  $3  The directory the pages go under
  $4  The URL the library's files are at; none when left out
PUB_FUN
docs__write() {
  __docs__write__trees="$(mktemp -d)"
  __docs__write__context="$(@obj \
    '.system' "$1" \
    '.library' "$2" \
    '.out' "$3" \
    '.trees' "$__docs__write__trees" \
    '.source' "${4:-}"
  )"
  rm -rf "$3"
  mkdir -p "$3"
  __docs__write_pages "$__docs__write__context"
  __docs__write_index "$1" "$3" "$__docs__write__trees"
  rm -rf "$__docs__write__trees"
}

: <<'FUN'
Writes the tree of each module of the context's library under its trees
directory, and the page the context's system renders for each under its
pages directory.

args:
  $1  The context ({system, library, out, trees, source})
FUN
__docs__write_pages() {
  __docs__write_pages__library="$(@get "$1" '.library' '')"
  __docs__write_pages__modules="$(docs__modules "$__docs__write_pages__library")"
  __docs__write_pages__n=0
  while IFS= read -r __docs__write_pages__module; do
    [ -n "$__docs__write_pages__module" ] || continue
    __docs__write_pages__n=$((__docs__write_pages__n + 1))
    __docs__write_page "$1" "$__docs__write_pages__module" "$__docs__write_pages__n"
  done <<EOF_MODULES
$__docs__write_pages__modules
EOF_MODULES
}

: <<'FUN'
Writes the tree of the module <module> under the context's trees
directory, numbered <n> so the trees sort in the modules' order, and the
page the context's system renders for it under its pages directory, at
the path the system gives, linked to the module under the context's
source when there is one.

args:
  $1  The context ({system, library, out, trees, source})
  $2  The module's path
  $3  The module's number in the library's order
FUN
__docs__write_page() {
  __docs__write_page__system="$(@get "$1" '.system' '')"
  __docs__write_page__out="$(@get "$1" '.out' '')"
  __docs__write_page__trees="$(@get "$1" '.trees' '')"
  __docs__write_page__source="$(@get "$1" '.source' '')"
  __docs__write_page__tree="$(printf '%s/%06d.tree.json' "$__docs__write_page__trees" "$3")"
  __docs__write_page__page="$__docs__write_page__out/$(docs__docgen__page_path "$__docs__write_page__system" "$2")"
  docs__tree "$2" "$2" > "$__docs__write_page__tree"
  mkdir -p "$(dirname "$__docs__write_page__page")"
  docs__page "$__docs__write_page__system" "$__docs__write_page__tree" "$__docs__write_page__source" \
    > "$__docs__write_page__page"
}

: <<'FUN'
Writes the index the system <system> renders over every tree under
<trees>, in the order they were numbered, under <out> at the path the
system gives.

args:
  $1  The docs system's name
  $2  The directory the pages go under
  $3  The directory the trees are under
FUN
__docs__write_index() {
  __docs__write_index__out="$2/$(docs__docgen__index_path "$1")"
  __docs__write_index__name="$1"
  set -- "$3"/*.tree.json
  mkdir -p "$(dirname "$__docs__write_index__out")"
  docs__index "$__docs__write_index__name" "$@" > "$__docs__write_index__out"
}
