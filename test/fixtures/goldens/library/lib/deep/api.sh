#!/bin/sh

: <<'MODULE'
A module one directory down, so the library's pages keep its path.
MODULE

: <<'PUB_FUN'
Prints its one argument.
PUB_FUN
deep__echo() {
  printf '%s\n' "$1"
}
