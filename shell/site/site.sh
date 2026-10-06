#!/bin/sh

import "$SHELLOPS_DIR/lib/kinds/api.sh"

: <<'MODULE'
The site kind: where a docs site's content lives, and how a change to it
is made to stay. A docs system of the docgen kind (shell/docs/docgen.sh)
decides what the files look like; a site system decides where they are
kept, and knows nothing of their layout. That is a plugin of kind site
(lib/kinds/api.sh of shellops says how a kind loads), a file named
<name>.site.op.sh defining @site.<name>() with these roles:

  @summary                 What the system keeps a site in, in one line.
  @needs                   The programs the system runs, as a struct array.
  @checkout <dir> <settings>
                           Makes the site's content present as files under
                           <dir>, and prints a token that names the state
                           it came from, for @put to refuse a site that
                           moved meanwhile. <settings> is the site's
                           declaration, a struct whose keys the system
                           reads; a site that does not exist yet starts
                           empty.
  @put <dir> <settings> <token> <message> <bot> <email>
                           Makes the files under <dir>, as they are now,
                           the site's content, as <bot> with <email>, under
                           <message>. Fails when the site is not at
                           <token> any more.
  @stage <dir> <out>       Copies the site's files under <dir> to <out>,
                           as they are now and nothing else: the site as
                           it would be after @put, for a preview that
                           puts nothing.
  @close <dir>             Removes what @checkout made under <dir>.

repository is the first system, in repository.site.op.sh beside this
file: the site is a branch of the repository the command runs in, checked
out as a worktree. A site kept through an API would be another plugin,
and cli/ingest would change nothing.

A site declares its system and the system's own settings under `site` in
.ops/config/docs.yaml:

  site:
    system: repository
    branch: published
MODULE

# CONST: The roles the kind knows.
__site__ROLES="summary needs checkout put stage close"

# CONST: The roles a system must answer.
__site__REQUIRED="summary checkout put stage close"

: <<'PUB_FUN'
Loads and registers the site system <name>, whose plugin file has been
sourced. See kinds__load.
PUB_FUN
site__load() {
  kinds__load site "$1" "$__site__ROLES" "$__site__REQUIRED"
}

: <<'PUB_FUN'
Sources and loads every site system under <root>, each a file
<name>.site.op.sh, in byte order of their paths. Fails when one does not
load.
PUB_FUN
site__load_all() {
  __site__load_all__files="$(find "$1" -type f -name '*.site.op.sh' | LC_ALL=C sort)"
  while IFS= read -r __site__load_all__file; do
    [ -n "$__site__load_all__file" ] || continue
    __site__load_file "$__site__load_all__file" || return 1
  done <<EOF_FILES
$__site__load_all__files
EOF_FILES
}

: <<'FUN'
Sources the plugin file <file> and loads the system it defines, named by
the file.
FUN
__site__load_file() {
  __site__load_file__name="$(basename "$1" .site.op.sh)"
  . "$1"
  site__load "$__site__load_file__name"
}

: <<'PUB_FUN'
Prints the names of every loaded site system, as a struct array, in load
order.
PUB_FUN
site__names() {
  kinds__names site
}

: <<'PUB_FUN'
Prints the system <name>'s @summary.
PUB_FUN
site__summary() {
  kinds__call site "$1" summary
}

: <<'PUB_FUN'
Makes the site the system <name> keeps, as <settings> declares it, present
as files under <dir>, and prints the token @put takes.

Usage: site__checkout <name> <dir> <settings>
PUB_FUN
site__checkout() {
  kinds__call site "$1" checkout "$2" "$3"
}

: <<'PUB_FUN'
Makes the files under <dir> the content of the site the system <name>
keeps, as <settings> declares it, as the bot <bot> with <email>, under
<message>. Fails when the site is not at <token> any more.

Usage: site__put <name> <dir> <settings> <token> <message> <bot> <email>
PUB_FUN
site__put() {
  kinds__call site "$1" put "$2" "$3" "$4" "$5" "$6" "$7"
}

: <<'PUB_FUN'
Copies the site's files under <dir> to <out>, as they are now.

Usage: site__stage <name> <dir> <out>
PUB_FUN
site__stage() {
  kinds__call site "$1" stage "$2" "$3"
}

: <<'PUB_FUN'
Removes what the system <name>'s checkout made under <dir>.

Usage: site__close <name> <dir>
PUB_FUN
site__close() {
  kinds__call site "$1" close "$2"
}
