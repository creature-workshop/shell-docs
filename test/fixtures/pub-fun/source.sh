#!/bin/sh

: <<'MODULE'
Public functions, with and without an args section.
MODULE

: <<'PUB_FUN'
Copies <source> to <target>, and says so when --verbose is given.

args:
  <source>   The file to copy
  <target>   Where the copy goes, which may be a directory
             or a new name
  --verbose  Name the copy on stderr
  $@         Anything after them, ignored

Usage: copy [--verbose] <source> <target>
PUB_FUN
copy() {
  cp "$@"
}

: <<'PUB_FUN'
Prints the working directory. A doc with no args section adds none.

Returns:
  The directory, one line
PUB_FUN
where() {
  pwd
}

# A comment between a doc block and its function does not part them.
: <<'PUB_FUN'
Prints nothing.
PUB_FUN
# shellcheck disable=SC2120
quiet() {
  :
}

: <<'PUB_FUN'
A doc block parted from the function below by a blank line attaches to
nothing, and the function is undocumented.
PUB_FUN

parted() {
  :
}
