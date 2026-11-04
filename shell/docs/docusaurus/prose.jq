# A doc's text as CommonMark, which the page and the index renderers
# include. A placeholder such as <name> goes in a code span: a Markdown
# parser reads it as an HTML tag otherwise, and the browser swallows the
# text after it. An indented example goes in a fenced code block: a
# two-space indent is prose to Markdown otherwise, and the example runs
# into the sentence before it. Code the author wrote, a code span or a
# fenced block, is kept as written, and the indented lines of a list item
# stay the item's text.

# True when a line has no non-whitespace content.
def blank:
  test("[^ \t]") | not;

# True when a line is indented: whitespace, then content.
def indented:
  test("^[ \t]+[^ \t]");

# True when a line opens a list item: a bullet or a number, then a space.
def list_item:
  test("^([-*+]|[0-9]+[.)])[ \t]");

# True when a line opens or closes a fenced code block the author wrote.
def fence:
  test("^[ \t]*(```|~~~)");

# The width of a line's leading whitespace.
def indent_width:
  match("^[ \t]*") | .length;

# A text with every placeholder in a code span. A placeholder is a word in
# angle brackets, such as <name> or <trees...>; an autolink, which has a
# scheme or an address in its brackets, is not one.
def spans_placeholders:
  gsub("(?<placeholder><[^<>`:@[:space:]]+>)"; "`\(.placeholder)`");

# The segments of a line: each run of backticks, and the text between.
def segments:
  [scan("`+|[^`]+")];

# The state after one segment of a line. A run of backticks opens a code
# span when none is open, and closes the span a run of the same length
# opened. Text outside a span gets its placeholders in code spans, and
# text inside one is kept as written.
def read_segment($segment):
  if ($segment | startswith("`")) then
    .text += $segment
    | if .open == 0 then .open = ($segment | length)
      elif .open == ($segment | length) then .open = 0
      else . end
  elif .open == 0 then .text += ($segment | spans_placeholders)
  else .text += $segment end;

# A line of prose with every placeholder outside a code span in one.
#
#   "Wraps <text> to `<width>` columns"  ->  "Wraps `<text>` to `<width>` columns"
def placeholders:
  reduce segments[] as $segment ({text: "", open: 0}; read_segment($segment))
  | .text;

# The lines of an indented run without the indent they share, so the
# example opens at the margin of its block.
def dedent:
  ([.[] | select(blank | not) | indent_width] | min) as $width
  | map(if blank then "" else .[$width:] end);

# The state with the open run of indented lines, when there is one, written
# out as a fenced code block, then the blank lines held after the run.
def close_run:
  if .run == [] then .
  else .out += ["```"] + (.run | dedent) + ["```"] + .pending | .run = [] | .pending = []
  end;

# The state after one line of a doc. Inside a fence the author wrote, every
# line passes as written. A blank line after an open run is held, in case
# the run continues. An indented line continues the open run, or is a list
# item's text when a list is open, and opens a run otherwise. Any other
# line closes the run and is prose, with its placeholders in code spans.
def read_line($line):
  if .in_fence then
    .out += [$line] | .in_fence = ($line | fence | not)
  elif ($line | fence) then
    close_run | .out += [$line] | .in_fence = true
  elif ($line | blank) then
    if .run == [] then .out += [$line] else .pending += [$line] end
  elif ($line | indented) then
    if .run != [] then .run += .pending + [$line] | .pending = []
    elif .in_list then .out += [$line | placeholders]
    else .run = [$line] end
  else
    close_run | .out += [$line | placeholders] | .in_list = ($line | list_item)
  end;

# A doc's text as CommonMark: each indented run that is not a list item's
# text in a fenced code block, and the placeholders of the prose in code
# spans.
#
#   "Wraps <text>.\n\n  wrap a b  ->  a\n"  ->  "Wraps `<text>`.\n\n```\nwrap a b  ->  a\n```\n"
def commonmark:
  reduce split("\n")[] as $line
    ({out: [], run: [], pending: [], in_list: false, in_fence: false}; read_line($line))
  | close_run
  | .out
  | join("\n");
