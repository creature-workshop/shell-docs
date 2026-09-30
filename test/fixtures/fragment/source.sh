#!/bin/sh

: <<'FRAGMENT'
A file only its own module imports: its reach is fragment.
FRAGMENT

: <<'FUN'
Prints its argument.
FUN
__say__once() {
  printf '%s\n' "$1"
}
