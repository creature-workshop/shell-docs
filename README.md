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

`cli/docs` is the entry point:

    cli/docs [--list] [--system <name>] [--out <dir>] <library>

`cli/snapshot` writes rendered pages into a site's checkout as one version
of one project. It fails when the site already contains that version,
unless it is the trunk's, named with `--trunk`:

    cli/snapshot [--system <name>] [--trunk <version>] --site <dir> --project <id> --version <version> <pages>

`cli/ingest` is the step a source repository's publish job triggers in the
site's repository: it checks the published branch out at origin's tip in a
worktree, writes the pages through `cli/snapshot`, commits as the bot and
pushes with a lease on that tip. With `--artifact` it downloads the pages
from a job artifact first. The catalog's `docusaurus--ingest` member runs
it, and the site repository only includes that member and sets its
variables:

    cli/ingest [--system <name>] [--branch <name>] [--trunk <version>] [--artifact <url>] --project <id> --version <version> --bot <name> --email <email> <pages>

`cli/docs` renders every module beneath `<library>` under `<dir>`, `.ops/docs` by
default, for the system named, docusaurus by default, and reads shell-scan
and shell-tree from `SHELL_SCAN_DIR` and `SHELL_TREE_DIR` when the host
exports them, from the vendored copies here otherwise. It boots shellops,
whose kind registry loads the systems. A host that takes shell-docs at a
pin declares the two beside it; shellops' `ops docs` passes through to this
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

The tests are goldens, run through shell-goldens at `shell/.golden`: one
fileset per case under `test/fixtures/goldens/`, one per label the contract
pass reads, one for the `greet` fixture's tree, page and index, and one
for a library rendered for docusaurus and for a second system, each with
the transcript it must write recorded beside it. `test/docs.bats` covers
the kind, the command and what a transcript cannot show.

A repository takes this library at a pin, and renders its reference
through the catalog's `docusaurus` package or shellops' `ops docs`, which
passes through to `cli/docs`; nothing docgen lives anywhere else (ADR.2).
shellops and strata both do. `shell/.scan`, `shell/.tree`, `shell/.golden` and `shell/.ops` vendor
shell-scan, shell-tree, shell-goldens and shellops, for this repository's
own tests and lint, and for nothing else.

The work is tracked in Linear on the SILT project, from STRATA-221.
