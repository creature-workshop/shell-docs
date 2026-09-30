# lib/greet.sh (module)

Greetings, for the tree's own test.

## Public functions

### `greet`

Prints a greeting to $1, with a "quote" and a \ in it.

args:
  $1  The name to greet, which may run on
      to a second line
  $@  Anything after it, ignored

Usage: greet <name>

| Argument | Meaning |
| --- | --- |
| `$1` | The name to greet, which may run on to a second line |
| `$@` | Anything after it, ignored |

### `undocumented`

*Undocumented.*

## Private functions

- `__greet__lower`

## Constants and variables

### `__greet__WORD` (private constant)

The word every greeting opens with.

