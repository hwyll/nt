# note

A fast, terminal-based note-taking CLI built on plain text markdown files.

## Features

- **Plain text storage** - Human-readable markdown, organized by date
- **Quick note** - `nt buy potato`
- **Interactive browser** - fzf integration for browsing and searching
- **Tags** - Flexible tagging with `#tag` syntax
- **Comments** - Thread comments on notes
- **Multiple formats** - Export to JSON, CSV, Markdown
- **macOS compatible** - Works with BSD tools

## Installation

```bash
# Dependencies
brew install fzf

# Add to PATH
ln -s "$(pwd)/bin/note" /usr/local/bin/note

# Optional alias in ~/.zshrc
alias nt='note'
```

## Quick Start

```bash
# Capture notes (default action)
nt buy potato
nt today was productive
nt -t work,urgent deploy the fix

# Browse and search
nt                        # interactive fzf browser
nt -s auth                # search for "auth"

# List
nt -l                     # all notes
nt -l --today             # today only
nt -l --tag work          # filter by tag
nt -l -f json             # as JSON

# Operations
nt -e latest              # edit last note
nt -c latest "done"       # add comment
nt -g latest +urgent      # add tag
nt -d <id>                # delete
```

## Usage

### Capture Notes

```bash
nt meeting went well           # quick note
nt -t work standup notes       # with tags
nt -e                          # open editor for multiline
nt -e "meeting"                # editor with title pre-filled
```

### List & Search

```bash
nt                             # interactive browser (fzf)
nt -l                          # list all
nt -l --today                  # today's notes
nt -l --tag work               # filter by tag
nt -l --since 2026-01-01       # filter by date (YYYY-MM-DD)
nt -l --since yesterday        # relative dates supported
nt -l --since "last week"      # past 7 days
nt -l -f json                  # output as JSON
nt -l -f csv                   # output as CSV
nt -l -f md                    # output as Markdown
nt -s "search term"            # search with fzf
nt --tags                      # list all tags with counts
```

### Operations

```bash
nt -e <id>                     # edit note
nt -e latest                   # edit most recent
nt -c <id> "comment text"      # add comment
nt -c latest "done!"           # comment on latest
nt -g <id> +urgent             # add tag
nt -g <id> -old +new           # modify tags
nt -g <id> work todo           # replace all tags
nt -d <id>                     # delete note
nt -y -d <id>                  # delete without confirm
```

Tags can contain letters, numbers, dots, hyphens, and underscores (e.g., `work`, `v2.0`, `my-tag`). Tags are normalized to lowercase and deduplicated.

### Scripting

```bash
nt -q buy potato               # quiet mode (no output)
nt -q -y -d latest             # quiet + skip confirm
nt -l -f json | jq ...         # pipe JSON to jq
```

### Export

```bash
nt -x                          # export all as markdown
nt -x -f json                  # export as JSON
nt -x --tag work               # export filtered
```

## Note IDs

Every note has a timestamp-based ID: `YYYYMMDDHHMMSS`

```bash
nt -e 20260203143052           # full ID
nt -e 143052                   # time only (today)
nt -e latest                   # most recent
nt -e oldest                   # oldest note
nt -e -1                       # alias for latest
nt -e -2                       # second to last
```

## Interactive Browser

```bash
nt                             # open browser

# Keyboard shortcuts:
# Ctrl-N    Create new note
# Ctrl-C    Add comment
# Ctrl-T    Modify tags
# Ctrl-E    Edit note
# Ctrl-D    Delete note
# Enter     View details
# Esc       Quit
```

## File Format

Notes stored in `~/notes/` (or `$NOTES_DIR`):

```
~/notes/
  2026/
    02/
      2026-02-03.md
```

Each note:

```markdown
## [14:30:52-0800] Meeting notes

tags: #work #standup

Discussed the deployment timeline.

> [14:35:00-0800] Action item added
> [15:00:00-0800] Completed

---
```

## Configuration

Create `~/.config/note/note.conf`:

```bash
NOTES_DIR=~/notes
EDITOR=nvim
CONFIRM_DELETE=true         # Prompt before delete
COLORS_ENABLED=true         # Disable all colors

# Colors (ANSI escape codes)
COLOR_TIMESTAMP='\033[35m'  # Magenta
COLOR_TAG='\033[33m'        # Yellow
COLOR_TITLE='\033[0m'       # Default
COLOR_CONTENT='\033[37m'    # White
COLOR_LABEL='\033[2;37m'    # Dim (section labels)
COLOR_BORDER='\033[2;37m'   # Dim (border lines)
BORDER_CHAR='━'             # Border character (━, ─, =, -)
BORDER_WIDTH=0              # Border width (0=none, 3=minimal, 60=full)
COLOR_DIVIDER='\033[2;37m'  # Dim (| divider)
COLOR_BRANCH='\033[2;37m'   # Dim (└─ comment prefix)
COLOR_META='\033[2;37m'     # Dim (footer metadata)
```

## Scripting

```bash
# Count by tag
nt -l -f json | jq -r '.[] | .tags[]' | sort | uniq -c

# Find notes with comments
nt -l -f json | jq '.[] | select(.comments | length > 0)'

# Export work notes
nt -x --tag work -f json > work_notes.json
```

## Escaping

If your note starts with a dash, use `--`:

```bash
nt -- -t this is not a flag
nt -- --hierarchical notes
```

## Options Reference

```
CAPTURE:
  -t TAGS        Tags (comma-separated)
  -e [ID]        Edit (no ID = new in editor)

LIST:
  -l             List notes
  --today        Filter to today
  --since DATE   Filter by date (YYYY-MM-DD, yesterday, 'last week')
  --tag TAG      Filter by tag
  -f FORMAT      Output format (json|csv|md|plain)
  -s TERM        Search
  --tags         List all tags

OPERATIONS:
  -c ID TEXT     Add comment
  -g ID TAGS     Modify tags (+add -remove, or replace)
  -d ID          Delete

EXPORT:
  -x             Export notes

OTHER:
  -q, --quiet    Suppress output (for scripting)
  -y, --yes      Skip confirmation prompts
  -h, --help     Help
  -v, --version  Version
```

## License

[MIT](LICENSE) © 2026 [hwyll](https://github.com/hwyll)
