#!/bin/sh

: <<'MODULE'
Public variables: exported, and in the one-line form.
MODULE

: <<'PUB_VAR'
The level below which a message is not written.
PUB_VAR
export text_level=info

# PUB_VAR: How many messages were written so far.
text_count=0
