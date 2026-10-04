#!/bin/sh

: <<'MODULE'
Private variables, and an enum declaration, which the lowering reads as an
assignment.
MODULE

: <<'VAR'
The last message written.
VAR
__text__last=""

# VAR: The levels, in the order they rank.
@enum __text__LEVEL info warn error
