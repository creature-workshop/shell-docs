# ADR.2: shell-docs is the one renderer, shellops passes through to it, and a repository renders its reference through the catalog

- Status: approved
- Date: 2026-10-04
- Merge request: https://gitlab.creature-workshop.com/ksoft/libraries/shell-docs/-/merge_requests/5
- Argued from: https://linear.app/grand-cluster-city/issue/STRATA-240
- Implementation: STRATA-240, DOCS-3, shellops!636, creatures!56

## Context

[ADR.1@shell-docs](000001-a-repository-adopts-shell-docs-at-a-pin-and-reads-the-tree-as-its-interface.md)
puts the extractor and the renderers here and says a repository composes
its own commands from its copy. The first consumer, strata, then wrote the
loop that turns a library into pages, an entry point, a test and a
pipeline job of its own, and shellops kept a second copy of the renderers
under `lib/reference`. Two renderers drift, and every repository that
wants docs would repeat the loop.

The review of strata!95 ruled: there is one renderer, anything docgen
lives in shell-docs, and a repository gets its docs from a catalog job that
uses what shell-docs declares, plus or minus a few parameters. A
pass-through command on shellops is fine, so a consumer need not adopt
shell-docs by name.

## Decision

- Everything docgen lives here: the contract pass, the loop from a library
  to its pages and index (`docs__write`), the `docgen` kind and its
  systems, and the entry point `cli/docs [--system <name>] [--out <dir>]
  <library>`. A consumer writes no renderer, no loop and no test for them.
- A docs system is a plugin of the `docgen` kind, `<name>.docgen.op.sh`,
  whose roles are what a page and an index look like and where each goes.
  The tree is the same for every system. `docusaurus` is the first; another
  docs system is another plugin, and the extraction, the command and the
  catalog's job do not change.
- shellops' `ops docs` passes through to `cli/docs` from the lock, the way
  `ops lint` passes through to shell-lint, and keeps no renderer of its
  own.
- A repository renders its reference through the catalog's package named
  for the system, `docusaurus`: `docusaurus--render` runs the command on
  every push and keeps the pages as its artifact, and `docusaurus--publish`
  hands a version of them to the docs site. The repository names its
  library once, and declares shell-docs, shell-scan and shell-tree in the
  git channel of its tools declaration.
- The pages a repository publishes are what `cli/docs` writes, so a
  change to how a page reads is made here and reaches every repository as
  a pin bump.

## Consequences

- strata's reference, shellops' reference and any later repository's are
  rendered by one command, and look the same.
- A fix for how a page reads, such as the placeholders and examples
  DOCS-7 names, is one change in the system's plugin here.
- A repository that cannot take shell-docs through the git channel yet
  renders nothing until it can; there is no second path.
