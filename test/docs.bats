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
export SHELL_DOCS_DIR="$REPO"
export PROJ="$REPO"

load "$SHELLOPS_DIR/test/lib/bats-support/load.bash"
load "$SHELLOPS_DIR/test/lib/bats-assert/load.bash"

setup() {
  # shellcheck source=/dev/null
  . "$SHELLOPS_DIR/.envrc"
  # The boot's pins name a shell-docs of their own; the tests run this one.
  export SHELL_DOCS_DIR="$REPO"
  import "$REPO/shell/docs/api.sh"
  docs__docgen__load_all "$REPO/shell/docs"
}

@test "docs__tree: the path defaults to the source, and a source given with no path is named by it" {
  run docs__tree "$REPO/test/fixtures/goldens/module/source.sh"
  assert_success
  assert_output --partial "\"name\":\"$REPO/test/fixtures/goldens/module/source.sh\""
}

# Prints the versions list in the file <file>, as one line of JSON.
versions_in() {
  @to_json __versions_in__json "$(cat "$1")" || return 1
  println "$__versions_in__json"
}

# Prints the versions list of the strata project at the commit the site
# last fetched, as one line of JSON.
fetched_versions() {
  git -C site show FETCH_HEAD:strata_versions.json > "$BATS_TEST_TMPDIR/fetched_versions.json" || return 1
  versions_in "$BATS_TEST_TMPDIR/fetched_versions.json"
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
  @get first_system "$(docs__docgen__names)" '.[0]'
  assert_equal "$first_system" docusaurus
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

@test "cli/docs: links each page to its source under --source, else under the pipeline's project at its ref, and leaves the link out otherwise" {
  library_of_greet

  run "$REPO/cli/docs" --out reference --source https://forge.example/org/tool/-/blob/v1.0.0 lib
  assert_success
  assert_equal "$(sed -n 3p reference/lib/greet.md)" 'custom_edit_url: "https://forge.example/org/tool/-/blob/v1.0.0/lib/greet.sh"'

  export CI_PROJECT_URL=https://forge.example/org/tool CI_COMMIT_REF_NAME=v2.0.0
  run "$REPO/cli/docs" --out reference lib
  assert_success
  assert_equal "$(sed -n 3p reference/lib/greet.md)" 'custom_edit_url: "https://forge.example/org/tool/-/blob/v2.0.0/lib/greet.sh"'
  unset CI_PROJECT_URL CI_COMMIT_REF_NAME

  run "$REPO/cli/docs" --out reference lib
  assert_success
  assert_equal "$(sed -n 1,3p reference/lib/greet.md)" "$(printf -- '---\ntitle: "lib/greet.sh"\n---')"
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

  run "$REPO/cli/snapshot" --site site --project strata --as-version 0.1.0 pages
  assert_success
  assert_output "snapshot strata 0.1.0: 2 files into site"
  assert [ -f site/strata_versioned_docs/version-0.1.0/lib/greet.md ]
  assert_equal "$(versions_in site/strata_versions.json)" '["0.1.0"]'

  run "$REPO/cli/snapshot" --site site --project strata --as-version 0.1.0 pages
  assert_failure
  assert_output --partial "strata 0.1.0 is already in the site, and a published version is never replaced"

  run "$REPO/cli/snapshot" --site site --project strata --as-version main --trunk main pages
  assert_success
  run "$REPO/cli/snapshot" --site site --project strata --as-version main --trunk main pages
  assert_success
  assert_equal "$(versions_in site/strata_versions.json)" '["main","0.1.0"]'
}

@test "cli/snapshot: refuses pages with no index for the system, and a missing site, project or version" {
  site_and_pages

  run "$REPO/cli/snapshot" --site site --project strata --as-version 0.1.0 lib
  assert_failure
  assert_output --partial "there is no README.md under lib; render the pages for docusaurus first"

  run "$REPO/cli/snapshot" --site site --project strata pages
  assert_failure
  assert_output --partial "--site, --project, --as-version and the pages are required"
}

# A source as its render leaves it, under $BATS_TEST_TMPDIR/source: the
# greet library's pages rendered for docusaurus under .ops/docs, and a
# manifest naming the project strata. Moves into $BATS_TEST_TMPDIR.
source_of_greet() {
  library_of_greet
  docs__write docusaurus lib source/.ops/docs
  mkdir -p source/.ops/config
  printf 'name: strata\n' > source/.ops/config/manifest.yaml
}

# A site repository under $BATS_TEST_TMPDIR/site with a bare origin beside
# it, declaring the published branch, main as the trunk and the bot, and
# the source of source_of_greet beside it. The declarations are committed,
# so a test can check that the ingest leaves the checkout as it was. PROJ
# is the site's checkout, so the ingest commits there. The bot's token is
# unset, so the push uses the file origin as it is, and the shell's git
# identity is unset, so the commit's author is the bot.
site_with_origin_and_source() {
  source_of_greet
  git init -q --bare origin.git
  git clone -q origin.git site 2>/dev/null
  mkdir -p site/.ops/config
  printf 'system: docusaurus\nsite:\n  system: repository\n  branch: published\n  trunk: main\n' > site/.ops/config/docs.yaml
  printf 'name: Bot\nemail: bot@example.com\n' > site/.ops/config/bot.yaml
  git -C site add .ops
  git -C site -c user.name=t -c user.email=t@t commit -q -m seed
  git -C site push -q origin HEAD:trunk
  export PROJ="$BATS_TEST_TMPDIR/site"
  unset FORGE_ADMIN_TOKEN GIT_CONFIG_COUNT GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
}

@test "cli/docs: renders the library the docs declaration names where it says and for the system it names, when no argument names them" {
  library_of_greet
  mkdir -p .ops/config
  printf 'library: lib\npages: reference\nsystem: docusaurus\n' > .ops/config/docs.yaml
  export PROJ="$BATS_TEST_TMPDIR"

  run "$REPO/cli/docs"
  assert_success
  assert_output "wrote reference: 1 pages and README.md"
  assert [ -f reference/lib/greet.md ]

  printf 'library: lib\nsystem: mkdocs\n' > .ops/config/docs.yaml
  run "$REPO/cli/docs"
  assert_failure
  assert_output --partial "no docs system named mkdocs"
}

@test "cli/ingest: reads the project from the source's manifest and the site system, its branch, the trunk and the bot from the site's declarations, puts the version, refuses it a second time, replaces the trunk's, and leaves the checkout as it was" {
  site_with_origin_and_source

  run "$REPO/cli/ingest" --as-version 0.1.0 source
  assert_success
  assert_line "ingest strata 0.1.0: put into the repository site"
  git -C site fetch -q origin published
  assert_equal "$(git -C site log -1 --format='%an <%ae> %s' FETCH_HEAD)" "Bot <bot@example.com> docs: strata 0.1.0"
  assert_equal "$(fetched_versions)" '["0.1.0"]'
  run git -C site cat-file -e FETCH_HEAD:strata_versioned_docs/version-0.1.0/lib/greet.md
  assert_success

  run "$REPO/cli/ingest" --as-version 0.1.0 source
  assert_failure
  assert_output --partial "strata 0.1.0 is already in the site, and a published version is never replaced"

  run "$REPO/cli/ingest" --as-version main source
  assert_success
  run "$REPO/cli/ingest" --as-version main source
  assert_success
  git -C site fetch -q origin published
  assert_equal "$(fetched_versions)" '["main","0.1.0"]'
  assert_equal "$(git -C site rev-list --count FETCH_HEAD)" 3

  assert_equal "$(git -C site log -1 --format=%s HEAD)" seed
  assert_equal "$(git -C site status --porcelain)" ""
  assert_equal "$(git -C site worktree list | wc -l | tr -d ' ')" 1
}

@test "cli/ingest: a flag overrides a declaration, and the pages are read where the source's docs declaration says" {
  site_with_origin_and_source
  mv source/.ops/docs source/pages
  printf 'pages: pages\n' > source/.ops/config/docs.yaml

  run "$REPO/cli/ingest" --as-version 0.1.0 --project silt --branch docs --bot-name Other --bot-email other@example.com source
  assert_success
  assert_line "ingest silt 0.1.0: put into the repository site"
  git -C site fetch -q origin docs
  assert_equal "$(git -C site log -1 --format='%an <%ae> %s' FETCH_HEAD)" "Other <other@example.com> docs: silt 0.1.0"
  run git -C site cat-file -e FETCH_HEAD:silt_versioned_docs/version-0.1.0/lib/greet.md
  assert_success
}

@test "cli/ingest --out: stages the site with the snapshot into the directory, and puts nothing" {
  site_with_origin_and_source
  run "$REPO/cli/ingest" --as-version 0.1.0 source
  assert_success

  run "$REPO/cli/ingest" --as-version mr-7 --out preview source
  assert_success
  assert_line "ingest strata mr-7: staged the site with the snapshot in preview"
  assert [ -f preview/strata_versioned_docs/version-mr-7/lib/greet.md ]
  assert [ -f preview/strata_versioned_docs/version-0.1.0/lib/greet.md ]
  assert [ ! -e preview/.git ]
  assert_equal "$(versions_in preview/strata_versions.json)" '["mr-7","0.1.0"]'

  git -C site fetch -q origin published
  assert_equal "$(fetched_versions)" '["0.1.0"]'
  assert_equal "$(git -C site worktree list | wc -l | tr -d ' ')" 1
}

@test "cli/ingest: refuses a missing version, a missing source, a source that names no project, a site that names no bot, and an unknown site system" {
  site_with_origin_and_source

  run "$REPO/cli/ingest" --as-version 0.1.0 --site wiki source
  assert_failure
  assert_output --partial "no site system named wiki; the systems are repository"

  run "$REPO/cli/ingest" source
  assert_failure
  assert_output --partial "--as-version is required"

  run "$REPO/cli/ingest" --as-version 0.1.0
  assert_failure
  assert_output --partial "give --artifact <url> or the directory the source's render left"

  rm source/.ops/config/manifest.yaml
  run "$REPO/cli/ingest" --as-version 0.1.0 source
  assert_failure
  assert_output --partial "the source names no project"

  rm site/.ops/config/bot.yaml
  run "$REPO/cli/ingest" --as-version 0.1.0 --project strata source
  assert_failure
  assert_output --partial "nothing names the bot"
}

# A curl on PATH that answers the source pipeline's jobs with $1 and fails
# every other URL, test/stubs/curl, and the environment the lookup reads:
# the forge's API and the bot's token. Call it after the site is set up,
# which unsets the token.
with_curl_answering_jobs() {
  export CURL_STUB_MATCH="/pipelines/55/jobs"
  export CURL_STUB_BODY="$BATS_TEST_TMPDIR/jobs.json"
  export CURL_STUB_LOG="$BATS_TEST_TMPDIR/curl.log"
  printf '%s\n' "$1" > "$CURL_STUB_BODY"
  export PATH="$REPO/test/stubs:$PATH"
  export CI_API_V4_URL="https://forge.example/api/v4"
  export FORGE_ADMIN_TOKEN="bot-token"
}

@test "cli/ingest with a source pipeline: reads its jobs with the bot's token, takes the successful job of the source's name, and downloads its artifact by id, with the project and the job from the flags or the site's source declaration" {
  site_with_origin_and_source
  with_curl_answering_jobs '[{"id":700,"name":"ksoft/docusaurus/render","status":"failed"},{"id":777,"name":"ksoft/docusaurus/render","status":"success"},{"id":778,"name":"ksoft/shell/test","status":"success"}]'

  run "$REPO/cli/ingest" --as-version 0.1.0 --source-project 26 --source-pipeline 55 --source-job ksoft/docusaurus/render
  assert_failure
  assert_output --partial "the artifact at https://forge.example/api/v4/projects/26/jobs/777/artifacts could not be downloaded"
  assert_equal "$(sed -n 1p "$CURL_STUB_LOG")" "https://forge.example/api/v4/projects/26/pipelines/55/jobs?per_page=100"
  assert_equal "$(sed -n 2p "$CURL_STUB_LOG")" "https://forge.example/api/v4/projects/26/jobs/777/artifacts"

  printf 'source:\n  project: 26\n  job: ksoft/docusaurus/render\n' >> site/.ops/config/docs.yaml
  run "$REPO/cli/ingest" --as-version 0.1.0 --source-pipeline 55
  assert_failure
  assert_output --partial "the artifact at https://forge.example/api/v4/projects/26/jobs/777/artifacts could not be downloaded"

  run "$REPO/cli/ingest" --as-version 0.1.0 --source-project 26 --source-pipeline 55 --source-job ksoft/shell/test
  assert_failure
  assert_output --partial "the artifact at https://forge.example/api/v4/projects/26/jobs/778/artifacts could not be downloaded"
}

@test "cli/ingest: refuses a source pipeline with no successful job of the name, a pipeline without the project or the job, the project and the job without a pipeline, a source given twice, and the lookup without the forge's API or the bot's token" {
  site_with_origin_and_source
  with_curl_answering_jobs '[{"id":700,"name":"ksoft/docusaurus/render","status":"failed"}]'

  run "$REPO/cli/ingest" --as-version 0.1.0 --source-project 26 --source-pipeline 55 --source-job ksoft/docusaurus/render
  assert_failure
  assert_output --partial "no successful job named ksoft/docusaurus/render in pipeline 55 of project 26"

  run "$REPO/cli/ingest" --as-version 0.1.0 --source-pipeline 55
  assert_failure
  assert_output --partial "the source pipeline needs the project and the job's name"

  run "$REPO/cli/ingest" --as-version 0.1.0 --source-project 26 --source-job ksoft/docusaurus/render
  assert_failure
  assert_output --partial "give --artifact <url> or the directory the source's render left"

  run "$REPO/cli/ingest" --as-version 0.1.0 --source-project 26 --source-pipeline 55 --source-job ksoft/docusaurus/render source
  assert_failure
  assert_output --partial "and only one of them"

  unset FORGE_ADMIN_TOKEN
  run "$REPO/cli/ingest" --as-version 0.1.0 --source-project 26 --source-pipeline 55 --source-job ksoft/docusaurus/render
  assert_failure
  assert_output --partial "set both"
}
