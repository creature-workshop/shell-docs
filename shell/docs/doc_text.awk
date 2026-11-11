# Reading one line of a doc's text: whether it has any content, and how far
# it is indented. The contract pass and the renderers load it, so they
# agree on what a blank line and an indent are.

# Whether a line has no character other than a space or a tab.
function is_blank(line) {
  return line !~ /[^ \t]/
}

# How many spaces and tabs a line opens with.
function indent_width(line) {
  match(line, /^[ \t]*/)

  return RLENGTH
}

# A line without the spaces and tabs it opens with.
function trimmed(line) {
  sub(/^[ \t]*/, "", line)

  return line
}
