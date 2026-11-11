#!/usr/bin/env bash

: <<'DOC'
A second docs system, for the kind's test: a text page per module at the
module's path with .sh as .txt, holding the module's name, and the index
at INDEX.txt, one module name per line, and a snapshot that is the pages
under <site>/<project>/<version>/. It shows that a system is a plugin and
nothing else changes.
DOC

@docgen.plain() {
  @summary() {
    println "Plain text, for the test."
  }

  @page() {
    __docgen__plain__page__tree="$(cat "$1")" || return 1
    println "page of $(@get "$__docgen__plain__page__tree" '.name' '')"
  }

  @index() {
    for __docgen__plain__index__file in "$@"; do
      __docgen__plain__index__tree="$(cat "$__docgen__plain__index__file")" || return 1
      @get "$__docgen__plain__index__tree" '.name' ''
    done
  }

  @page_path() {
    println "${1%.sh}.txt"
  }

  @index_path() {
    println "INDEX.txt"
  }

  @snapshot() {
    rm -rf "${2:?}/$3/$4"
    mkdir -p "$2/$3/$4"
    cp -R "$1/." "$2/$3/$4/"
  }

  @has_version() {
    if [ -d "$1/$2/$3" ]; then
      @true
    else
      @false
    fi
  }
}
