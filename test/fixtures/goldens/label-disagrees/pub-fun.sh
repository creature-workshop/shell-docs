#!/bin/sh

: <<'MODULE'
A library file, so the name and the label must agree.
MODULE

: <<'PUB_FUN'
A PUB_FUN label on a name that says private.
PUB_FUN
__labelled_public() {
  :
}
