# Prints the reference's index page, in Markdown: a table with one row for
# each module, linking the module's page, with its reach and the first line
# of its doc, written as CommonMark as prose.awk says. Loaded after
# nodes.awk, doc_text.awk and prose.awk.
#
# Input: a list of module nodes, in the order the pages are listed.

function main(line) {
  tree_line(line)
}

# The first line of a module's doc, or a note when it has none.
function summary(module, __doc, __lines) {
  __doc = payload_of(entry(module, "doc"))
  if (!is_present(__doc)) {
    return "*Undocumented.*"
  }
  split(text_of(__doc), __lines, "\n")

  return placeholders(__lines[1])
}

# A module's reach, or a dash when its doc states none.
function reach(module, __reach) {
  __reach = entry(module, "reach")

  return __reach == 0 ? "-" : text_of(payload_of(__reach))
}

# The page a module's tree renders to, relative to the index.
#
#   page("lib/greet.sh")  ->  lib/greet.md
function page(name) {
  sub(/\.sh$/, "", name)

  return name ".md"
}

# Prints one module's row.
function print_row(module, __name) {
  __name = text_of(member(module, "name"))

  print "| [`" __name "`](" page(__name) ") | " reach(module) " | " summary(module) " |"
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print "# Reference"
  print ""
  print "One page per library module, rendered from its tree."
  print ""
  print "| Module | Reach | Summary |"
  print "| --- | --- | --- |"
  for (module = NODE_FIRST[ROOT]; module != 0; module = NODE_NEXT[module]) {
    print_row(module)
  }
}

{ main($0) }
