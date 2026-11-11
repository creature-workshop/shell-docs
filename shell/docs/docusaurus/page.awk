# Prints a module's tree as its reference page, in Markdown. The page opens
# on front matter Docusaurus reads: its title, and the edit link to the
# module's source when the source is given. Then it reads the tree and
# nothing else: the module's doc, then each public function with its doc
# and its contract, then the private functions as a list of names, then the
# documented constants and variables. A doc's text is written as
# CommonMark, as prose.awk says. Loaded after nodes.awk, doc_text.awk and
# prose.awk.
#
# Input: the module node the contract pass writes for the module.
# Args:  source: the URL the module's source files are at for the version
#        rendered, which the edit link is under, or the empty string when
#        there is none.

function main(line) {
  tree_line(line)
}

# The name of a node, as text.
function name_text(node) {
  return text_of(member(node, "name"))
}

# The role of a node, as text.
function role_text(node) {
  return text_of(member(node, "role"))
}

# A node's doc as page prose: its text as CommonMark, or a note when the
# node has no doc.
function prose_of(node, __doc) {
  __doc = payload_of(entry(node, "doc"))

  return is_present(__doc) ? commonmark(text_of(__doc)) : "*Undocumented.*"
}

# A node's visibility, read from its contract.
function visibility_of(node) {
  return text_of(payload_of(entry(entry(node, "contract"), "visibility")))
}

# Whether a node is a member with a role and a visibility.
function is_member_with(node, role, visibility) {
  return role_text(node) == role && visibility_of(node) == visibility
}

# How many nodes in a module's payload have a role, with a visibility when
# one is given.
function count_members(module, role, visibility, __at, __count) {
  __count = 0
  for (__at = NODE_FIRST[payload_of(module)]; __at != 0; __at = NODE_NEXT[__at]) {
    if (role_text(__at) == role && (visibility == "" || visibility_of(__at) == visibility)) {
      __count++
    }
  }

  return __count
}

# Prints the page's front matter: the title, and the edit link to the
# module's source under the source argument when there is one.
function print_front_matter(module) {
  print "---"
  print "title: " wrap(name_text(module))
  if (arg("source") != "") {
    print "custom_edit_url: " wrap(arg("source") "/" name_text(module))
  }
  print "---"
}

# The page's title: the module's path, and its reach when it states one.
function title(module, __reach) {
  __reach = entry(module, "reach")

  return "# " name_text(module) (__reach == 0 ? "" : " (" text_of(payload_of(__reach)) ")")
}

# Prints the args table of a member under a blank line, or nothing when the
# member has no args.
function print_args_table(node, __args, __arg) {
  __args = payload_of(entry(entry(node, "contract"), "args"))
  if (NODE_COUNT[__args] == 0) {
    return
  }

  print ""
  print "| Argument | Meaning |"
  print "| --- | --- |"
  for (__arg = NODE_FIRST[__args]; __arg != 0; __arg = NODE_NEXT[__arg]) {
    print "| `" name_text(__arg) "` | " placeholders(text_of(payload_of(entry(__arg, "meaning")))) " |"
  }
}

# Prints one public function as its section: heading, doc, args.
function print_public_function(node) {
  print "### `" name_text(node) "`"
  print ""
  print prose_of(node)
  print_args_table(node)
  print ""
}

# Prints the public functions of a module, each as a section, under their
# heading, or nothing when the module has none.
function print_public_functions(module, __at) {
  if (count_members(module, "function", "public") == 0) {
    return
  }

  print "## Public functions"
  print ""
  for (__at = NODE_FIRST[payload_of(module)]; __at != 0; __at = NODE_NEXT[__at]) {
    if (is_member_with(__at, "function", "public")) {
      print_public_function(__at)
    }
  }
}

# Prints the private functions of a module as a list of names, under their
# heading.
function print_private_functions(module, __at) {
  print "## Private functions"
  print ""
  for (__at = NODE_FIRST[payload_of(module)]; __at != 0; __at = NODE_NEXT[__at]) {
    if (is_member_with(__at, "function", "private")) {
      print "- `" name_text(__at) "`"
    }
  }
  print ""
}

# Prints the members of a module with a role, a constant or a variable,
# each as a short section.
function print_bindings_of(module, role, __at) {
  for (__at = NODE_FIRST[payload_of(module)]; __at != 0; __at = NODE_NEXT[__at]) {
    if (role_text(__at) == role) {
      print "### `" name_text(__at) "` (" visibility_of(__at) " " role ")"
      print ""
      print prose_of(__at)
      print ""
    }
  }
}

# Prints the documented constants and then the documented variables of a
# module under their heading, or nothing when the module has neither.
function print_bindings(module) {
  if (count_members(module, "constant", "") + count_members(module, "variable", "") == 0) {
    return
  }

  print "## Constants and variables"
  print ""
  print_bindings_of(module, "constant")
  print_bindings_of(module, "variable")
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_front_matter(ROOT)
  print ""
  print title(ROOT)
  print ""
  print prose_of(ROOT)
  print ""
  print_public_functions(ROOT)
  print_private_functions(ROOT)
  print_bindings(ROOT)
}

{ main($0) }
