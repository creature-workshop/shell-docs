# Prints the trees in the files given as one JSON list, in the order the
# files are given. A tree file holds one JSON document, so the list is the
# documents with a comma between them, inside brackets.
#
#   awk -f trees.awk 000001.tree.json 000002.tree.json  ->  [{"role":"module",...},{"role":"module",...}]

function main(line) {
  if (FNR == 1) {
    printf "%s", (NR == 1) ? "[" : ","
  }
  print line
}

END {
  print (NR == 0) ? "[]" : "]"
}

{ main($0) }
