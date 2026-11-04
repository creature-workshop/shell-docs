#!/bin/sh

: <<'MODULE'
Text for the docusaurus renderer's own test: a placeholder such as <name>
in prose, one already in a code span, `<name>`, and one in a double
backtick span, `` a `<name>` b ``, each kept as the author wrote it, and
an autolink, <https://example.com/>, which is not a placeholder.

An example indented by two spaces, after a blank line:

  text__wrap <name> <width>  ->  a line of <width> columns

- A list item whose text runs on
  to a second line, with <name> in it, and
- a second item, with a `<code>` span of its own.

  A paragraph of the second item, indented after a blank line.

A fence the author wrote, with <name> inside it:

```
text__wrap <name>
```
MODULE

: <<'PUB_FUN'
Wraps <text> to <width> columns.

args:
  <text>   The text, with <name> in its meaning
  <width>  The width, which may run on
           to a second line

Usage: text__wrap <text> <width>

  text__wrap "a b" 1  ->  a
                          b
PUB_FUN
text__wrap() {
  printf '%s\n' "$1"
}
