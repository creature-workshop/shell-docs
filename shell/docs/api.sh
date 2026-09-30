#!/bin/sh

: <<'MODULE'
The doc extractor as shell functions, for a host that holds the three
repositories: the tree of a module, and a page or an index rendered from
trees. The host exports SHELL_SCAN_DIR, SHELL_TREE_DIR and SHELL_DOCS_DIR,
the roots of its copies of shell-scan, shell-tree and this repository, and
sources this file.

  docs__tree shell/silt/get.sh  ->  {"role":"module","name":"shell/silt/get.sh","payload":[...]}
  docs__page get.tree.json      ->  # shell/silt/get.sh (module) ...
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
Prints the reference page of the module whose tree is in the file <tree>,
as markdown.
PUB_FUN
docs__page() {
  # structs-lint: allow -- the renderer is a jq program over a tree file; no struct value is read
  jq -r -f "$SHELL_DOCS_DIR/shell/docs/page.jq" "$1"
}

: <<'PUB_FUN'
Prints the index page over the trees in the files <trees...>, as markdown,
one row per module in the order given.

args:
  $@  The tree files, one per module
PUB_FUN
docs__index() {
  # structs-lint: allow -- the renderer is a jq program over tree files; no struct value is read
  jq -r -s -f "$SHELL_DOCS_DIR/shell/docs/index.jq" "$@"
}
