#!/usr/bin/env bats
# Covers what the goldens (test/docs-goldens.bats) cannot: the default name
# of a tree, the docgen kind loading docusaurus from beside the library,
# docs__modules over a directory with files of every kind, docs__write
# emptying its directory, cli/docs from the command line, cli/snapshot
# over a site checkout, and cli/ingest against a bare origin. What a tree,
# a page, an index and a library's render look like is the goldens'.

bats_require_minimum_version 1.5.0

REPO="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export SHELLOPS_DIR="${SHELLOPS_DIR:-$REPO/shell/.ops}"
export SHELL_SCAN_DIR="${SHELL_SCAN_DIR:-$REPO/shell/.scan}"
export SHELL_TREE_DIR="${SHELL_TREE_DIR:-$REPO/shell/.tree}"
export SHELL_DOCS_DIR="$REPO"
export PROJ="$REPO"

load "$SHELLOPS_DIR/test/lib/bats-support/load.bash"
load "$SHELLOPS_DIR/test/lib/bats-assert/load.bash"

setup() {
  # shellcheck source=/dev/null
  . "$SHELLOPS_DIR/.envrc"
  import "$REPO/shell/docs/api.sh"
  docs__docgen__load_all "$REPO/shell/docs"
}

@test "docs__tree: the path defaults to the source, and a source given with no path is named by it" {
  run docs__tree "$REPO/test/fixtures/goldens/module/source.sh"
  assert_success
  assert_output --partial "\"name\":\"$REPO/test/fixtures/goldens/module/source.sh\""
}

# A library of one module under $BATS_TEST_TMPDIR: the greet fixture as
# lib/greet.sh, so its page and index name the path shellops' goldens use.
# Moves into the directory and prints it.
library_of_greet() {
  mkdir -p "$BATS_TEST_TMPDIR/lib"
  cp "$REPO/test/fixtures/goldens/greet/source.sh" "$BATS_TEST_TMPDIR/lib/greet.sh"
  cd "$BATS_TEST_TMPDIR" || return 1
}

@test "docs__modules: every .sh file beneath the library in byte order, and no fixture, plugin or template" {
  library_of_greet
  mkdir -p lib/deep
  touch lib/deep/api.sh lib/map.fixture.sh lib/int.type.op.sh lib/run.template.sh lib/notes.txt

  run docs__modules lib
  assert_success
  assert_line --index 0 "lib/deep/api.sh"
  assert_line --index 1 "lib/greet.sh"
  assert_equal "${#lines[@]}" 2
}

@test "docgen: docusaurus loads from beside the library, with its summary, and names its page and index paths" {
  assert_equal "$(@get "$(docs__docgen__names)" '.[0]')" docusaurus
  run docs__docgen__summary docusaurus
  assert_output --partial "Docusaurus"
  run docs__docgen__page_path docusaurus shell/silt/get.sh
  assert_output "shell/silt/get.md"
  run docs__docgen__index_path docusaurus
  assert_output "README.md"
}

@test "docs__write: empties the directory first, so a module that is gone leaves no page" {
  library_of_greet
  mkdir -p out/lib
  touch out/lib/gone.md

  docs__write docusaurus lib out

  assert [ ! -f out/lib/gone.md ]
  assert [ -f out/lib/greet.md ]
  assert [ -f out/README.md ]
}

@test "cli/docs: renders the library given under --out and says how many pages, lists the systems, and refuses a missing library and an unknown system" {
  library_of_greet

  run "$REPO/cli/docs" --out reference lib
  assert_success
  assert_output "wrote reference: 1 pages and README.md"
  assert [ -f reference/lib/greet.md ]
  assert [ -f reference/README.md ]

  run "$REPO/cli/docs" --list
  assert_success
  assert_line --partial "docusaurus  Markdown pages"

  run "$REPO/cli/docs" --out reference missing
  assert_failure
  assert_output --partial "missing is not a directory"

  run "$REPO/cli/docs" --system mkdocs --out reference lib
  assert_failure
  assert_output --partial "no docs system named mkdocs; the systems are docusaurus"
}

# A site checkout under $BATS_TEST_TMPDIR with the greet library's pages
# rendered for docusaurus beside it. Moves into the directory.
site_and_pages() {
  library_of_greet
  mkdir -p site
  docs__write docusaurus lib pages
}

@test "cli/snapshot: writes the pages into the site as the version, refuses the version a second time, and replaces the trunk's" {
  site_and_pages

  run "$REPO/cli/snapshot" --site site --project strata --version 0.1.0 pages
  assert_success
  assert_output "snapshot strata 0.1.0: 2 files into site"
  assert [ -f site/strata_versioned_docs/version-0.1.0/lib/greet.md ]
  assert_equal "$(jq -c . site/strata_versions.json)" '["0.1.0"]'

  run "$REPO/cli/snapshot" --site site --project strata --version 0.1.0 pages
  assert_failure
  assert_output --partial "strata 0.1.0 is already in the site, and a published version is never replaced"

  run "$REPO/cli/snapshot" --site site --project strata --version main --trunk main pages
  assert_success
  run "$REPO/cli/snapshot" --site site --project strata --version main --trunk main pages
  assert_success
  assert_equal "$(jq -c . site/strata_versions.json)" '["main","0.1.0"]'
}

@test "cli/snapshot: refuses pages with no index for the system, and a missing site, project or version" {
  site_and_pages

  run "$REPO/cli/snapshot" --site site --project strata --version 0.1.0 lib
  assert_failure
  assert_output --partial "there is no README.md under lib; render the pages for docusaurus first"

  run "$REPO/cli/snapshot" --site site --project strata pages
  assert_failure
  assert_output --partial "--site, --project, --version and the pages are required"
}

# A site repository under $BATS_TEST_TMPDIR with a bare origin beside it,
# and the greet library's pages rendered for docusaurus. Moves into the
# directory, with PROJ at the site's checkout, so the ingest commits there.
# The bot's token is unset, so the push uses the file origin as it is, and
# the shell's git identity is unset, so the commit's author is the bot.
site_with_origin_and_pages() {
  library_of_greet
  docs__write docusaurus lib pages
  git init -q --bare origin.git
  git clone -q origin.git site 2>/dev/null
  git -C site -c user.name=t -c user.email=t@t commit -q --allow-empty -m seed
  git -C site push -q origin HEAD:trunk
  export PROJ="$BATS_TEST_TMPDIR/site"
  unset FORGE_ADMIN_TOKEN GIT_CONFIG_COUNT GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
}

@test "cli/ingest: pushes the version to the published branch of origin as the bot, refuses the version a second time, replaces the trunk's, and leaves the checkout as it was" {
  site_with_origin_and_pages

  run "$REPO/cli/ingest" --project strata --version 0.1.0 --bot Bot --email bot@example.com pages
  assert_success
  assert_line "ingest strata 0.1.0: pushed published"
  git -C site fetch -q origin published
  assert_equal "$(git -C site log -1 --format='%an <%ae> %s' FETCH_HEAD)" "Bot <bot@example.com> docs: strata 0.1.0"
  assert_equal "$(git -C site show FETCH_HEAD:strata_versions.json | jq -c .)" '["0.1.0"]'
  run git -C site cat-file -e FETCH_HEAD:strata_versioned_docs/version-0.1.0/lib/greet.md
  assert_success

  run "$REPO/cli/ingest" --project strata --version 0.1.0 --bot Bot --email bot@example.com pages
  assert_failure
  assert_output --partial "strata 0.1.0 is already in the site, and a published version is never replaced"

  run "$REPO/cli/ingest" --project strata --version main --trunk main --bot Bot --email bot@example.com pages
  assert_success
  run "$REPO/cli/ingest" --project strata --version main --trunk main --bot Bot --email bot@example.com pages
  assert_success
  git -C site fetch -q origin published
  assert_equal "$(git -C site show FETCH_HEAD:strata_versions.json | jq -c .)" '["main","0.1.0"]'
  assert_equal "$(git -C site rev-list --count FETCH_HEAD)" 3

  assert_equal "$(git -C site log -1 --format=%s HEAD)" seed
  assert_equal "$(git -C site status --porcelain)" ""
  assert_equal "$(git -C site worktree list | wc -l | tr -d ' ')" 1
}

@test "cli/ingest: refuses a missing project, version, bot, email or pages" {
  site_with_origin_and_pages

  run "$REPO/cli/ingest" --project strata --version 0.1.0 pages
  assert_failure
  assert_output --partial "--project, --version, --bot, --email and the pages are required"
}
