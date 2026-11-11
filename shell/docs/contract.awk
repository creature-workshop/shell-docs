# The contract pass: shell-tree's tree of a source in, the reference's tree
# out, the module node whose members carry a doc and a contract. Loaded
# after nodes.awk and doc_text.awk.
#
# This is where the house conventions are read. A `PUB_` label makes a
# member public and FUN, CONST or VAR private. In a library file, one with
# a MODULE or FRAGMENT doc, the name must agree: a private member's name
# starts with `__` and a public one's does not, and a label that disagrees
# with the name fails the pass, with a message that names the member. In an
# entrypoint, whose functions keep plain names, the label decides. A member
# with no label is judged by its name. MODULE or FRAGMENT on the source's
# doc is the module's reach. An assignment gets a node only when it has a
# doc, as a constant when the last `__` segment of its name is upper case
# and as a variable otherwise. A doc's `args:` section, one parameter per
# line and a deeper-indented line continuing the meaning above it, up to a
# blank line or the next section heading, fills the contract's args.
#
# Input: the source node shell-tree writes.

function main(line) {
  tree_line(line)
}

# Ends the pass with a message on stderr and status 1.
function fail(message) {
  print "docs: " message > "/dev/stderr"
  exit 1
}

# Whether a name is a constant's: its last `__` segment is upper case.
#
#   is_constant_name("__greet__WORD")  ->  1
function is_constant_name(name, __at) {
  while ((__at = index(name, "__")) > 0) {
    name = substr(name, __at + 2)
  }

  return name ~ /^[A-Z][A-Z0-9_]*$/
}

# The visibility a label states, and the empty string when it states none.
function label_visibility(label) {
  if (substr(label, 1, 4) == "PUB_") {
    return "public"
  }
  if (label == "FUN" || label == "CONST" || label == "VAR") {
    return "private"
  }

  return ""
}

# The visibility a name states on its own: private under a leading `__`.
function name_visibility(name) {
  return substr(name, 1, 2) == "__" ? "private" : "public"
}

# The visibility of a member with a name and a doc, which is no node when
# the member has none. In a library file the name decides and the label
# must agree with it: FUN, CONST and VAR go with a name that starts with
# `__`, PUB_FUN, PUB_CONST and PUB_VAR with one that does not, and a label
# that disagrees fails the pass. In an entrypoint the label decides, and
# the name when there is no label.
function visibility_of(name, doc, library, __label, __by_label, __by_name) {
  __by_name = name_visibility(name)
  __label = text_of(member(doc, "name"))
  __by_label = label_visibility(__label)

  if (__by_label == "") {
    return __by_name
  }
  if (library && __by_label != __by_name) {
    fail(name ": the doc opens on " __label ", but the name says " __by_name "; FUN, CONST and VAR name a member whose name starts with __, and PUB_FUN, PUB_CONST and PUB_VAR one whose name does not")
  }

  return __by_label
}

# Whether a doc line is the heading of a labelled reference section.
function is_section_heading(line) {
  return line ~ /^[ \t]*(Usage|Flags|Parameters|Params|Returns|Options|Vars|Example|Examples|Args|Arguments|Environment|Subcommands)([^A-Za-z]|$)/
}

# Whether a doc line is the heading of the args section.
function is_args_heading(line) {
  return line ~ /^[ \t]*([Aa]rgs|[Aa]rguments):[ \t]*$/
}

# Whether a doc line names a parameter: a positional or special parameter,
# an angle-bracketed name, or a flag, followed by its meaning.
function is_arg_line(line) {
  return line ~ /^[ \t]*(\$[0-9@#*]+(\.\.)?|<[^>]+>|--?[A-Za-z][A-Za-z0-9_-]*)[ \t]+[^ \t]/
}

# The parameter an arg line names.
#
#   arg_name("  $1  The name to greet")  ->  $1
function arg_name(line) {
  line = trimmed(line)
  sub(/[ \t].*$/, "", line)

  return line
}

# The meaning an arg line gives, after the parameter and the gap.
#
#   arg_meaning("  $1  The name to greet")  ->  The name to greet
function arg_meaning(line) {
  sub(/^[ \t]*[^ \t]+[ \t]+/, "", line)

  return line
}

# Reads the args section of a doc's text into two lists, the parameters and
# their meanings, and returns how many parameters there are. A line that
# names a parameter adds one, and a deeper-indented line continues the
# meaning of the last. The section ends at a blank line or at the next
# section heading.
function read_args(text, names, meanings, __lines, __total, __i, __line, __count, __width, __inside) {
  __total = split(text, __lines, "\n")
  __count = 0
  __inside = 0

  for (__i = 1; __i <= __total; __i++) {
    __line = __lines[__i]
    if (!__inside) {
      __inside = is_args_heading(__line)
      continue
    }
    if (is_blank(__line) || is_section_heading(__line)) {
      break
    }
    if (is_arg_line(__line)) {
      __count++
      names[__count] = arg_name(__line)
      meanings[__count] = arg_meaning(__line)
      __width = indent_width(__line)
      continue
    }
    if (__count > 0 && indent_width(__line) > __width) {
      meanings[__count] = meanings[__count] " " trimmed(__line)
    }
  }

  return __count
}

# Prints the lines that open a node with a role as an element of a list.
function open_node(depth, index_in_list, role) {
  print_open(depth, index_in_list, "map")
  print_str(depth + 1, "role", role)
}

# Prints a leaf with a role, whose payload is a value the source's tree
# has. No node prints as a null payload.
function print_leaf(depth, index_in_list, role, value) {
  open_node(depth, index_in_list, role)
  print_node(value, depth + 1, wrap("payload"))
}

# Prints a leaf with a role, whose payload is a text.
function print_text_leaf(depth, index_in_list, role, text) {
  open_node(depth, index_in_list, role)
  print_str(depth + 1, "payload", text)
}

# Prints the args of a contract: one arg node for each parameter, with its
# meaning.
function print_args(depth, index_in_list, names, meanings, count, __i) {
  open_node(depth, index_in_list, "args")
  print_open(depth + 1, wrap("payload"), "list")

  for (__i = 1; __i <= count; __i++) {
    open_node(depth + 2, __i - 1, "arg")
    print_str(depth + 3, "name", names[__i])
    print_open(depth + 3, wrap("payload"), "list")
    print_text_leaf(depth + 4, 0, "meaning", meanings[__i])
  }
}

# Prints the contract of a member with a name and a doc: its visibility,
# then its args when the doc has any.
function print_contract(depth, index_in_list, name, doc, library, __names, __meanings, __count) {
  open_node(depth, index_in_list, "contract")
  print_open(depth + 1, wrap("payload"), "list")
  print_text_leaf(depth + 2, 0, "visibility", visibility_of(name, doc, library))

  __count = read_args(text_of(payload_of(doc)), __names, __meanings)
  if (__count > 0) {
    print_args(depth + 2, 1, __names, __meanings, __count)
  }
}

# The role a definition of the source's has in the reference's tree:
# function for a function, constant or variable for an assignment that has
# a doc, and the empty string for a definition that gets no node.
function member_role(definition, __role) {
  __role = text_of(member(definition, "role"))

  if (__role == "function") {
    return "function"
  }
  if (__role == "assignment" && entry(definition, "doc") != 0) {
    return is_constant_name(text_of(member(definition, "name"))) ? "constant" : "variable"
  }

  return ""
}

# Prints a member of the reference's tree from a definition of the
# source's: its line, its doc when it has one, and its contract.
function print_member(index_in_list, definition, role, library, __doc, __next) {
  __doc = entry(definition, "doc")

  open_node(1, index_in_list, role)
  print_node(member(definition, "name"), 2, wrap("name"))
  print_open(2, wrap("payload"), "list")
  print_leaf(3, 0, "line", payload_of(entry(definition, "line")))
  __next = 1
  if (__doc != 0) {
    print_leaf(3, __next++, "doc", payload_of(__doc))
  }
  print_contract(3, __next, text_of(member(definition, "name")), __doc, library)
}

# Whether a source's doc opens on MODULE or FRAGMENT: the file is a library
# file, whose members' names say what they are.
function is_library(doc, __label) {
  __label = text_of(member(doc, "name"))

  return __label == "MODULE" || __label == "FRAGMENT"
}

# Prints the module node of a source: its path, its reach and its doc when
# the source is a library file, and its members.
function print_module(source, __doc, __library, __next, __definition, __role) {
  __doc = entry(source, "doc")
  __library = is_library(__doc)

  print_str(0, "role", "module")
  print_node(member(source, "name"), 0, wrap("name"))
  print_open(0, wrap("payload"), "list")
  print_leaf(1, 0, "path", member(source, "name"))
  __next = 1
  if (__library) {
    print_text_leaf(1, __next++, "reach", tolower(text_of(member(__doc, "name"))))
    print_leaf(1, __next++, "doc", payload_of(__doc))
  }

  for (__definition = NODE_FIRST[payload_of(source)]; __definition != 0; __definition = NODE_NEXT[__definition]) {
    __role = member_role(__definition)
    if (__role != "") {
      print_member(__next++, __definition, __role, __library)
    }
  }
}

BEGIN {
  ROOT = tree_open()
}

END {
  if (REFUSED) {
    exit 1
  }

  print_module(ROOT)
}

{ main($0) }
