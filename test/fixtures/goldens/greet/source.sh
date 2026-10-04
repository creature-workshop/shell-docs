#!/bin/sh

import "$SHELLOPS_DIR/lib/structs/api.sh"

: <<'MODULE'
Greetings, for the tree's own test.
MODULE

: <<'CONST'
The word every greeting opens with.
CONST
__greet__WORD=hello

: <<'PUB_FUN'
Prints a greeting to $1, with a "quote" and a \ in it.

args:
  $1  The name to greet, which may run on
      to a second line
  $@  Anything after it, ignored

Usage: greet <name>
PUB_FUN
# shellcheck disable=SC2120
greet() {
  printf '%s %s\n' "$__greet__WORD" "$1"
}

: <<'FUN'
Lower-cases $1.
FUN
__greet__lower() {
  printf '%s\n' "$1" | tr 'A-Z' 'a-z'
}

undocumented() {
  :
}
