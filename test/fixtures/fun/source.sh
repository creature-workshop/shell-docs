#!/bin/sh

: <<'MODULE'
Private functions: by their label, or by their name when they carry no doc.
MODULE

: <<'FUN'
Lower-cases its argument.
FUN
__text__lower() {
  printf '%s\n' "$1" | tr 'A-Z' 'a-z'
}

: <<'FUN'
A FUN label makes a function private whatever its name says.
FUN
labelled_private() {
  :
}

__text__undocumented() {
  :
}

undocumented() {
  :
}
