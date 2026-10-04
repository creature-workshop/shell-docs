#!/bin/sh

: <<'MODULE'
Private functions: by their label, and by their name when they carry no doc.
MODULE

: <<'FUN'
Lower-cases its argument.
FUN
__text__lower() {
  printf '%s\n' "$1" | tr 'A-Z' 'a-z'
}

__text__undocumented() {
  :
}

undocumented() {
  :
}
