#!/bin/sh

: <<'MODULE'
Private constants, and an assignment with no doc, which gets no node.
MODULE

: <<'CONST'
The separator between two fields.
CONST
__text__SEP=,

# CONST: The width of a column.
__text__WIDTH=8

__text__UNDOCUMENTED=1
