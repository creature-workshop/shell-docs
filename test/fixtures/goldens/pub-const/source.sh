#!/bin/sh

: <<'MODULE'
Public constants: a heredoc, or the one-line form with a continuation.
MODULE

: <<'PUB_CONST'
The greeting every message opens with.
PUB_CONST
readonly text__GREETING=hello

# PUB_CONST: The most lines a message may run to,
# counted without its blank lines.
text__LINES=12
