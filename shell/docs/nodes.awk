# Reading the nodes of a tree: the source node shell-tree writes, and the
# module node the contract pass derives from it. A node is a map with a
# role, a name on a node that has one, and a payload: a value on a leaf,
# and a list of nodes otherwise. Loaded after SILT's tree.awk.

# The payload of a node, and no node when it has none.
function payload_of(node) {
  return member(node, "payload")
}

# The first node in the payload of a node that has a role, and no node
# when the payload has none.
#
#   entry(function_node, "doc")  ->  the function's doc leaf
function entry(node, role, __at) {
  for (__at = NODE_FIRST[payload_of(node)]; __at != 0; __at = NODE_NEXT[__at]) {
    if (text_of(member(__at, "role")) == role) {
      return __at
    }
  }

  return 0
}
