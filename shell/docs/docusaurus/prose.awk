# A doc's text as CommonMark, for the page and the index renderers. Loaded
# after doc_text.awk.
#
# A placeholder such as <name> goes in a code span: a Markdown parser reads
# it as an HTML tag otherwise, and the browser swallows the text after it.
# An indented example goes in a fenced code block: a two-space indent is
# prose to Markdown otherwise, and the example runs into the sentence
# before it. Code the author wrote, a code span or a fenced block, is kept
# as written, and the indented lines of a list item stay the item's text.

# Whether a line is indented: spaces or tabs, then content.
function is_indented(line) {
  return line ~ /^[ \t]+[^ \t]/
}

# Whether a line opens a list item: a bullet or a number, then a space.
function opens_list_item(line) {
  return line ~ /^([-*+]|[0-9]+[.)])[ \t]/
}

# Whether a line opens or closes a fenced code block the author wrote.
function is_fence(line) {
  return line ~ /^[ \t]*(```|~~~)/
}

# A text with every placeholder in a code span. A placeholder is a word in
# angle brackets, such as <name> or <trees...>; an autolink, which has a
# scheme or an address in its brackets, is not one.
#
#   spans_placeholders("Wraps <text> to")  ->  Wraps `<text>` to
function spans_placeholders(text, __out) {
  __out = ""
  while (match(text, /<[^<>`:@[:space:]]+>/)) {
    __out = __out substr(text, 1, RSTART - 1) "`" substr(text, RSTART, RLENGTH) "`"
    text = substr(text, RSTART + RLENGTH)
  }

  return __out text
}

# The length of the open code span after a run of backticks: a run opens a
# span when none is open, and closes the span that a run of the same length
# opened. 0 is no open span.
function span_after(open, run) {
  if (open == 0) {
    return run
  }

  return open == run ? 0 : open
}

# A line of prose with every placeholder outside a code span in one. Text
# inside a code span is kept as written.
#
#   placeholders("Wraps <text> to `<width>` columns")  ->  Wraps `<text>` to `<width>` columns
function placeholders(line, __out, __open, __run) {
  __out = ""
  __open = 0

  while (line != "") {
    if (match(line, /^`+/)) {
      __run = RLENGTH
      __out = __out substr(line, 1, __run)
      __open = span_after(__open, __run)
    } else {
      match(line, /^[^`]+/)
      __run = RLENGTH
      __out = __out (__open == 0 ? spans_placeholders(substr(line, 1, __run)) : substr(line, 1, __run))
    }
    line = substr(line, __run + 1)
  }

  return __out
}

# Adds a line to the text a reader has written so far.
function write_line(reader, line) {
  reader["text"] = (reader["lines"]++ == 0) ? line : reader["text"] "\n" line
}

# The indent that the lines of a reader's open run share: the narrowest of
# the lines that have content.
function run_indent(reader, __i, __width, __narrowest) {
  __narrowest = -1
  for (__i = 1; __i <= reader["run"]; __i++) {
    if (is_blank(reader["run", __i])) {
      continue
    }
    __width = indent_width(reader["run", __i])
    if (__narrowest < 0 || __width < __narrowest) {
      __narrowest = __width
    }
  }

  return __narrowest
}

# Writes a reader's open run of indented lines, when there is one, as a
# fenced code block, without the indent its lines share, so the example
# opens at the margin of its block. The blank lines held after the run
# follow the block.
function close_run(reader, __i, __indent) {
  if (reader["run"] == 0) {
    return
  }

  __indent = run_indent(reader)
  write_line(reader, "```")
  for (__i = 1; __i <= reader["run"]; __i++) {
    write_line(reader, is_blank(reader["run", __i]) ? "" : substr(reader["run", __i], __indent + 1))
  }
  write_line(reader, "```")
  for (__i = 1; __i <= reader["held"]; __i++) {
    write_line(reader, reader["held", __i])
  }

  reader["run"] = 0
  reader["held"] = 0
}

# Reads a blank line: it is held when a run is open, in case the run
# continues after it, and written otherwise.
function read_blank(reader, line) {
  if (reader["run"] == 0) {
    write_line(reader, line)
  } else {
    reader["held"]++
    reader["held", reader["held"]] = line
  }
}

# Adds the blank lines a reader holds, and then a line, to its open run.
function extend_run(reader, line, __i) {
  for (__i = 1; __i <= reader["held"]; __i++) {
    reader["run"]++
    reader["run", reader["run"]] = reader["held", __i]
  }
  reader["held"] = 0
  reader["run"]++
  reader["run", reader["run"]] = line
}

# Reads an indented line: it continues the open run, or is the text of a
# list item when a list is open, and opens a run otherwise.
function read_indented(reader, line) {
  if (reader["run"] == 0 && reader["in_list"]) {
    write_line(reader, placeholders(line))
  } else {
    extend_run(reader, line)
  }
}

# Reads one line of a doc. Inside a fence the author wrote, every line is
# written as it is. A line that is neither blank nor indented closes the
# open run and is prose, with its placeholders in code spans.
function read_line(reader, line) {
  if (reader["in_fence"]) {
    write_line(reader, line)
    reader["in_fence"] = !is_fence(line)
  } else if (is_fence(line)) {
    close_run(reader)
    write_line(reader, line)
    reader["in_fence"] = 1
  } else if (is_blank(line)) {
    read_blank(reader, line)
  } else if (is_indented(line)) {
    read_indented(reader, line)
  } else {
    close_run(reader)
    write_line(reader, placeholders(line))
    reader["in_list"] = opens_list_item(line)
  }
}

# A doc's text as CommonMark: each indented run that is not a list item's
# text in a fenced code block, and the placeholders of the prose in code
# spans.
#
#   commonmark("Wraps <text>.\n\n  wrap a b  ->  a\n")  ->  "Wraps `<text>`.\n\n```\nwrap a b  ->  a\n```\n"
function commonmark(text, __lines, __total, __i, __reader) {
  __reader["text"] = ""
  __reader["lines"] = 0
  __reader["run"] = 0
  __reader["held"] = 0
  __reader["in_list"] = 0
  __reader["in_fence"] = 0

  __total = split(text, __lines, "\n")
  for (__i = 1; __i <= __total; __i++) {
    read_line(__reader, __lines[__i])
  }
  close_run(__reader)

  return __reader["text"]
}
