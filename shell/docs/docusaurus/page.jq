# A module's tree as its reference page, one raw markdown string (run with
# -r). The page opens on front matter Docusaurus reads: its title, and the
# edit link to the module's source when the source is given. Then it reads
# the tree and nothing else: the module's doc, then each public function
# with its doc and its contract, then the private functions as a list of
# names, then the documented constants and variables. A doc's text is
# written as CommonMark, as prose.jq says.
#
# Input: the module node the tree lowering writes for the module.
# $source: the URL the module's source files are at for the version
# rendered, which the edit link is under, or "" when there is none.

include "prose";

# The payload entries of a node with the role $role.
def entries($role):
  [.payload[] | select(.role == $role)];

# The one payload entry with the role $role, or null.
def entry($role):
  entries($role) | first;

# A node's doc prose, or null when it has none.
def doc:
  entry("doc") | .payload;

# A node's visibility, read from its contract.
def visibility:
  entry("contract") | entry("visibility") | .payload;

# A node's args, as [{name, meaning}], empty when its contract has none.
def args:
  entry("contract") | entry("args")
  | if . == null then [] else [.payload[] | {name, meaning: (entry("meaning") | .payload)}] end;

# The heading a member's name makes.
def member_heading:
  "### `\(.name)`";

# A doc as page prose: the text as CommonMark, or a note when there is none.
def prose:
  if . == null then "*Undocumented.*" else commonmark end;

# The args table under a blank line, or nothing when a member has no args.
def args_table:
  args
  | if . == [] then empty
    else "", "| Argument | Meaning |", "| --- | --- |", (.[] | "| `\(.name)` | \(.meaning | placeholders) |")
    end;

# One public member as its section: heading, doc, args.
def public_section:
  member_heading, "", (doc | prose), args_table;

# The private members of $role as a list, one name per item, or nothing.
def private_items($role):
  entries($role)[] | select(visibility == "private") | "- `\(.name)`";

# The public members of $role as sections, or nothing.
def public_sections($role):
  entries($role)[] | select(visibility == "public") | public_section, "";

# The documented constants and variables, each as a short section.
def bindings_sections:
  (entries("constant") + entries("variable"))[]
  | "### `\(.name)` (\(visibility) \(.role))", "", (doc | prose), "";

# The page's title: the module's path and its reach.
def title:
  "# \(.name)"
  + (entry("reach") | if . == null then "" else " (\(.payload))" end);

# The edit link's line, to the module's source under $source, or nothing
# when there is no source.
def edit_url:
  if $source == "" then empty else "custom_edit_url: \("\($source)/\(.name)" | tojson)" end;

# The page's front matter: the title, and the edit link when there is one.
def front_matter:
  "---", "title: \(.name | tojson)", edit_url, "---";

# A section with $heading when $lines produce anything, else nothing.
def section($heading; lines):
  [lines] | if . == [] then empty else $heading, "", .[] end;

front_matter,
"",
title,
"",
(doc | prose),
"",
section("## Public functions"; public_sections("function")),
section("## Private functions"; private_items("function"), ""),
section("## Constants and variables"; bindings_sections)
