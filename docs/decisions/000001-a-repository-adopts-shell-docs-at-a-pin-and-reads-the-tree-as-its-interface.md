# ADR.1: A repository takes shell-docs at a pin, and reads the tree as its interface

- Status: approved
- Date: 2026-09-30
- Merge request: https://gitlab.creature-workshop.com/ksoft/shell-docs/-/merge_requests/1
- Argued from: https://linear.app/grand-cluster-city/issue/STRATA-221
- Implementation: STRATA-221

## Context

shellops lowers a library module to a tree, one JSON document per module,
and renders its help text and its reference page from that tree and from
nothing else. STRATA-221 decides that the extractor and the renderers are a
repository of their own, this one, so that SILT's interface can be reviewed
as the table its docs generate, and a change lands in seconds. STRATA-233
splits the extractor: the lowering that knows no convention is
[ADR.1@shell-tree](https://gitlab.creature-workshop.com/ksoft/shell-tree/-/blob/main/docs/decisions/000001-a-repository-adopts-shell-tree-at-a-pin-and-the-lowering-knows-no-convention.md),
over the scanner of
[ADR.1@shell-scan](https://gitlab.creature-workshop.com/ksoft/shell-scan/-/blob/main/docs/decisions/000001-a-repository-adopts-shell-scan-at-a-pin-and-composes-its-own-program.md),
and the conventions are read here.

## Decision

- shell-docs holds `shell/docs/contract.jq`, `page.jq` and `index.jq`, and
  `api.sh`, which wraps them as shell functions. It adopts shell-scan and
  shell-tree as their own records say.
- The layering is fixed: the scanner, then the lowering, then the contract
  pass, which is the one place a label's meaning, a name's convention and
  the `args:` section are read. The renderers read only what it writes.
- The tree is the interface every consumer reads: a renderer, a table, a
  lint over the contract. Its nodes are written down in the README, and a
  field named there is one a consumer may rely on. A field not named there
  may change without notice.
- A repository takes shell-docs at a pin, and composes its own commands
  from its copy. How the copy is made present, and where, is decided by the
  dependency work under way and not here. Whether it is a run-time or a dev-time dependency, in the sense
  [ADR.33@strata](https://gitlab.creature-workshop.com/ksoft/strata/-/blob/main/adrs/000033-dependencies/adr.md)
  gives the words, is the adopter's to say, from how its own code uses the
  copy; nothing here decides it.
- A renderer is a reader of the tree and never of the source. A fact one
  renderer shows and another does not is a renderer bug, fixed in the
  renderer.

## Consequences

- strata adopts shell-docs to derive SILT's pages and its table. shellops
  adopts it in step 2 of STRATA-221, when its own copies leave.
- The contract entries STRATA-221 adds (`answers`, `paths`, `refuses`,
  `tier`) join the tree here, each with its fixture, and reach an adopter
  as a pin bump.
- A Rust lowering, when the tree's shape has stopped moving, lives beside
  the awk in shell-tree and is compared with it over the fixtures before it
  takes over.
