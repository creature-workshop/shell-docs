#!/usr/bin/env bash
set -euo pipefail

USAGE="$(cat <<HELP
Greets whoever is named. An entrypoint documents itself in its usage, a
data heredoc the lowering reads past, so the module has no doc.

Usage: greet [-h,--help] <name>
HELP
)"

main() {
  printf 'hello %s\n' "$1"
}

: <<'FUN'
Collects the flags.
FUN
parse_args() {
  :
}

main "$@"
