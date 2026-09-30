#!/bin/sh

: <<'MODULE'
A module a consumer imports, for the tree's own test. The first doc block
followed by a blank line, met before any definition, is the file's doc.
MODULE

: <<'PUB_FUN'
Prints its argument.
PUB_FUN
say() {
  printf '%s\n' "$1"
}
