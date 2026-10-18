# shell-docs

The doc extractor for shell sources: the contract pass that reads the
house conventions out of a module's definitions and docs, and the
renderers of a reference page and an index from the tree it derives. It
reads a shell file through [shell-scan](../shell-scan), the heredoc
scanner, and [shell-tree](../shell-tree), the lowering of a source to its
definitions, which know no convention; this is the layer that does:

    awk -v path=<module path> \
      -f "$SHELL_SCAN_DIR/shell/scan/scan.awk" \
      -f "$SHELL_TREE_DIR/shell/tree/tree.awk" <module> \
      | jq -c -f "$SHELL_DOCS_DIR/shell/docs/contract.jq"

`shell/docs/contract.jq` is the contract pass, and its header states the
conventions it reads by: what a label means, what a name says, that the
two must agree or the member is refused, and how an `args:` section fills
the contract. `shell/docs/api.sh` wraps the
extraction as `docs__tree` for a host that holds the three repositories,
and adds `docs__write`, the reference of a whole library for one docs
system: one page per module and an index under one directory.

A docs system is a plugin of the `docgen` kind, `shell/docs/docgen.sh`,
which names the roles: what a page and an index look like, where each
goes, and how rendered pages are written into a docs site's checkout as
one version of a project. `docusaurus` is the first,
`shell/docs/docusaurus.docgen.op.sh`: markdown pages at the module's path
with `.sh` as `.md`, rendered by the two jq programs under
`shell/docs/docusaurus/`, the index at `README.md`, and a snapshot in
Docusaurus's own versioning layout. Another docs system is another plugin;
the extraction, the commands and the catalog's job do not change.

`cli/docs` is the entry point. A repository that declares its library in
`.ops/config/docs.yaml`, as `library`, with `pages` for where the reference
goes and `system` for the docs system, runs it with no arguments:

    cli/docs [--list] [--system <name>] [--out <dir>] [<library>]

`cli/snapshot` writes rendered pages into a site's checkout as one version
of one project. It fails when the site already contains that version,
unless it is the trunk's, named with `--trunk`:

    cli/snapshot [--system <name>] [--trunk <version>] --site <dir> --project <id> --as-version <version> <pages>

`cli/ingest` is the step a source repository's publish job triggers in the
site's repository. It reads the source as its render left it: the project
from the source's manifest, and the pages from where its docs declaration
says, `.ops/docs` by default. It reads the site's own declarations for the
rest: `system`, `site` and `site.trunk` of `.ops/config/docs.yaml`, and
the bot's `name` and `email` from `.ops/config/bot.yaml`; a flag overrides
any of them. It checks the site out through its site system, writes the
pages through `cli/snapshot`, and puts the result back as the bot. With
`--artifact` it downloads the source from a job artifact first, and with
a source pipeline it finds the render job in that pipeline of that project
and downloads its artifact by id, which the forge serves while the pipeline
is still running. The project, the pipeline and the job are `source` of the
site's docs declaration, with `project`, `pipeline` and `job`, and
`--source-project`, `--source-pipeline` and `--source-job` override them. With
`--out <dir>` it puts nothing, and stages the site as it would be after
the put into `<dir>` instead, which is how a site is built as a preview of
a merge request's docs. The catalog's `docusaurus--ingest` member runs it,
and the site repository only includes that member:

    cli/ingest [--system <name>] [--site <name>] [--branch <name>] [--trunk <version>] [--project <id>] [--bot-name <name>] [--bot-email <email>] [--out <dir>] --as-version <version> (--artifact <url> | --source-pipeline <id> [--source-project <id>] [--source-job <name>] | <source>)

A site system is a plugin of the `site` kind, `shell/site/site.sh`, which
names the roles: check the site's content out as files, put the files back
as the site's content unless the site moved meanwhile, stage the files for
a preview, and close the checkout. The docgen kind decides what the files
look like; the site kind decides where they are kept, and knows nothing of
their layout. `repository` is the first, `shell/site/repository.site.op.sh`:
the site is one branch of the repository the command runs in, `site.branch`
of the declaration, `published` by default, checked out as a worktree at
origin's tip and pushed with a lease on that tip. A site kept through an
API is another plugin, and `cli/ingest` does not change. The declaration:

    site:
      system: repository
      branch: published
      trunk: main

`cli/docs` renders every module beneath `<library>` under `<dir>`, `.ops/docs` by
default, for the system named, docusaurus by default, and reads shell-scan
and shell-tree from `SHELL_SCAN_DIR` and `SHELL_TREE_DIR`, which shellops
exports from the pins of the host's lock when it boots. The kind registry
of shellops loads the systems. A host that takes shell-docs at a pin
declares the two beside it; shellops' `ops docs` passes through to this
command, and the catalog's `docusaurus` package runs it in a pipeline and
keeps the pages as an artifact.

## The tree

The tree is the interface every consumer reads: a renderer, a table, a
lint over the contract. It is one JSON document per module, in the
`{ role, name, payload }` shape, and every field below is what a consumer
may rely on.

| Node | Role | Name | Payload |
| --- | --- | --- | --- |
| The module | `module` | its path | the entries below, then one node per member |
| Its path | `path` | | the path, as given |
| Its reach | `reach` | | `module` or `fragment`, from the file doc's label; absent without a file doc |
| Its doc | `doc` | | the file doc's text; absent without a file doc |
| A function | `function` | the function's name | `line`, `doc` when it has one, `contract` |
| A constant | `constant` | the name | as a function; only when it carries a doc |
| A variable | `variable` | the name | as a function; only when it carries a doc |
| A member's line | `line` | | the line number of its definition |
| A member's doc | `doc` | | the doc block's text as written |
| A member's contract | `contract` | | `visibility`, then `args` when the doc has an args section |
| Visibility | `visibility` | | `public` or `private`, from the label, else from the name |
| The args | `args` | | one `arg` per parameter line |
| One arg | `arg` | the parameter as written | `meaning`, the text after it, continued by deeper-indented lines |

A public function with no `doc` is undocumented, and the page says so.

The tests are goldens, run through shell-goldens, a tree the lock pins: one
fileset per case under `test/fixtures/goldens/`, one per label the contract
pass reads, one for the `greet` fixture's tree, page and index, and one
for a library rendered for docusaurus and for a second system, each with
the transcript it must write recorded beside it. `test/docs.bats` covers
the kind, the command and what a transcript cannot show.

A repository takes this library at a pin, and renders its reference
through the catalog's `docusaurus` package or shellops' `ops docs`, which
passes through to `cli/docs`; nothing docgen lives anywhere else (ADR.2).
shellops and strata both do. This repository vendors shellops at
`shell/.ops` and declares shell-scan, shell-tree and shell-goldens in the
git channel of `.ops/config/tools.yaml`, for its own tests and lint, and
for nothing else; `.ops/lock` records the pins, and shellops fetches the
trees and exports their roots when it boots.

The work is tracked in Linear on the SILT project, from STRATA-221.

shell-docs is licensed under the [Apache License, Version 2.0](LICENSE).
