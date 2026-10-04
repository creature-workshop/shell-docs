#!/bin/sh

: <<'MODULE'
A library file, so the name and the label must agree.
MODULE

: <<'FUN'
A FUN label on a name that says public.
FUN
labelled_private() {
  :
}
