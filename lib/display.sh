#!/usr/bin/env bash

# Display formatting for note

# Print configurable separator line
print_separator() {
  [[ ! "$BORDER_WIDTH" =~ ^[0-9]+$ ]] && BORDER_WIDTH=60
  [ "$BORDER_WIDTH" -eq 0 ] && return
  printf "%s\n" "$(colorize "$COLOR_BORDER" "$(printf "$BORDER_CHAR%.0s" $(seq 1 "$BORDER_WIDTH"))")"
}

# Format note for fzf list display
# Input: tab-separated note data
format_for_fzf_list() {
  while IFS= read -r line; do
    local id=$(echo "$line" | cut -f1)
    local time=$(echo "$line" | cut -f4)
    local title=$(echo "$line" | cut -f5)
    local tags=$(echo "$line" | cut -f6)
    printf "%s\t%s\n" "$id" "$(format_note_line "$id" "$time" "$title" "$tags")"
  done
}

# Format note for fzf preview
format_note_detail() {
  local note_id="$1"

  local note_data
  note_data=$(find_note_by_id "$note_id")
  [ -z "$note_data" ] && echo "Note not found" && return 1

  local id=$(echo "$note_data" | cut -f1)
  local file=$(echo "$note_data" | cut -f2)
  local line=$(echo "$note_data" | cut -f3)
  local time=$(echo "$note_data" | cut -f4)
  local title=$(echo "$note_data" | cut -f5)
  local tags=$(echo "$note_data" | cut -f6)
  local content=$(echo "$note_data" | cut -f7)
  local comments=$(echo "$note_data" | cut -f8)

  # Unescape content
  content=$(echo "$content" | tr '␤' '\n' | tr '␉' '\t')
  comments=$(echo "$comments" | tr '␤' '\n' | tr '␉' '\t')

  # Header separator
  print_separator

  # Title with timestamp (same format as list view)
  local display_time=$(format_list_timestamp "$id" "$time")
  printf "%s %s\n" "$(colorize "$COLOR_TIMESTAMP" "[$display_time]")" "$(colorize "$COLOR_TITLE" "$title")"

  # Header separator
  print_separator
  echo ""

  # Tags
  if [ -n "$tags" ]; then
    printf "%s " "$(colorize "$COLOR_LABEL" "Tags:")"
    echo "$tags" | tr ' ' '\n' | while read -r tag; do
      [ -n "$tag" ] && printf "%s " "$(colorize "$COLOR_TAG" "$tag")"
    done
    echo ""
    echo ""
  fi

  # Content
  if [ -n "$content" ]; then
    echo "$(colorize "$COLOR_CONTENT" "$content")"
    echo ""
  fi

  # Comments
  if [ -n "$comments" ]; then
    printf "%s\n" "$(colorize "$COLOR_LABEL" "Comments:")"
    echo "$comments" | while IFS='|' read -r comment_time comment_text; do
      # Convert UTC timestamp to epoch seconds, then format like list view
      if [[ "$comment_time" =~ ^(.+)Z$ ]]; then
        local time_sec="${BASH_REMATCH[1]}"
        local comment_epoch=$(date -j -u -f "%Y-%m-%d %H:%M:%S" "$time_sec" "+%s" 2>/dev/null)
        local display_comment_time=$(format_list_timestamp "$comment_epoch" "")
        printf "  %s %s\n" \
          "$(colorize "$COLOR_BRANCH" "└─") $(colorize "$COLOR_TIMESTAMP" "[$display_comment_time]")" \
          "$(colorize "$COLOR_CONTENT" "$comment_text")"
      fi
    done
    echo ""
  fi

  # Footer with metadata
  print_separator
  printf "%s %s %s %s %s\n" \
    "$(colorize "$COLOR_LABEL" "ID:")" "$(colorize "$COLOR_META" "$id")" \
    "$(colorize "$COLOR_DIVIDER" "|")" \
    "$(colorize "$COLOR_LABEL" "File:")" "$(colorize "$COLOR_META" "$file:$line")"
}

# Interactive browse with fzf
interactive_browse() {
  check_dependencies || return 1

  while true; do
    local notes=$(parse_all_notes)
    local header="Ctrl-N=new | Ctrl-C=comment | Ctrl-T=tags | Ctrl-E=edit | Ctrl-D=delete | Enter=view | Esc=quit"
    [ -z "$notes" ] && header="No notes yet | Ctrl-N=new | Ctrl-E=editor | Esc=quit"

    local selection
    local fzf_input=""
    [ -n "$notes" ] && fzf_input=$(echo "$notes" | format_for_fzf_list)
    selection=$(echo "$fzf_input" | tail -r |
      fzf --ansi \
        --delimiter=$'\t' \
        --with-nth=2.. \
        --height=100% \
        --reverse \
        --expect=ctrl-n,ctrl-c,ctrl-t,ctrl-e,ctrl-d \
        --header="$(colorize "$COLOR_LABEL" "$header")" \
        --preview="echo {} | cut -f1 | xargs $BIN_DIR/note-preview" \
        --preview-window=down:60%)

    [ -z "$selection" ] && break

    local key=$(echo "$selection" | head -n1)
    local selected=$(echo "$selection" | tail -n1)
    local note_id=$(echo "$selected" | cut -f1)

    case "$key" in
    ctrl-n)
      clear
      read -p "Note: " note_text
      if [ -n "$note_text" ]; then
        read -p "Tags: " note_tags
        # Normalize spaces to commas
        [ -n "$note_tags" ] && note_tags=$(echo "$note_tags" | tr ' ' ',')
        local new_id=$(create_note "$note_text" "$note_tags" "")
        echo "Note created: $new_id"
      fi
      ;;
    ctrl-c)
      clear
      format_note_detail "$note_id"
      read -p "Comment: " comment_text
      [ -n "$comment_text" ] && cmd_comment "$note_id" "$comment_text"
      ;;
    ctrl-t)
      clear
      format_note_detail "$note_id"
      read -p "Tags (+add -remove replace): " new_tags
      [ -n "$new_tags" ] && cmd_tag "$note_id" "$new_tags"
      ;;
    ctrl-e)
      if [ -n "$note_id" ] && [[ "$note_id" =~ ^[0-9]+$ ]]; then
        cmd_edit "$note_id"
      else
        clear
        read -p "Note: " note_title
        read -p "Tags: " note_tags
        [ -n "$note_tags" ] && note_tags=$(echo "$note_tags" | tr ' ' ',')
        local new_id=$(create_note_with_editor "$note_title" "$note_tags")
        echo "Note created: $new_id"
      fi
      ;;
    ctrl-d)
      clear
      format_note_detail "$note_id"
      cmd_delete "$note_id"
      ;;
    "")
      # Enter key - view note
      clear
      format_note_detail "$note_id"
      read -p "Press Enter to continue..."
      ;;
    esac
  done
}

# Interactive find with pre-filled search
interactive_find() {
  local query="$1"

  check_dependencies || return 1

  parse_all_notes | grep -i "$query" | format_for_fzf_list | tail -r |
    fzf --ansi \
      --delimiter=$'\t' \
      --with-nth=2.. \
      --height=100% \
      --reverse \
      --query="$query" \
      --preview="echo {} | cut -f1 | xargs $BIN_DIR/note-preview" \
      --preview-window=down:60%
}

# Interactive multi-select picker - outputs IDs
interactive_pick() {
  local tag_filter="" since=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag) tag_filter="$2"; shift 2 ;;
      --since) since="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  check_dependencies || return 1

  local notes=$(parse_all_notes)
  
  # Apply filters
  [ -n "$tag_filter" ] && notes=$(echo "$notes" | grep "#$tag_filter")
  if [ -n "$since" ]; then
    local since_epoch=""
    local date_flag=""
    [ "$DISPLAY_TIMEZONE" = "utc" ] && date_flag="-u"
    since_epoch=$(date -j $date_flag -f "%Y-%m-%d %H:%M:%S" "$since 00:00:00" "+%s" 2>/dev/null) || since_epoch=""
    if [ -z "$since_epoch" ]; then
      case "$since" in
        yesterday) since_epoch=$(date $date_flag -v-1d -v0H -v0M -v0S "+%s") ;;
        "last week"|"last-week") since_epoch=$(date $date_flag -v-7d -v0H -v0M -v0S "+%s") ;;
      esac
    fi
    [ -n "$since_epoch" ] && notes=$(echo "$notes" | awk -F'\t' -v epoch="$since_epoch" '$1 >= epoch')
  fi

  [ -z "$notes" ] && echo "No notes found" >&2 && return 1

  echo "$notes" | format_for_fzf_list | tail -r |
    fzf --ansi \
      --multi \
      --delimiter=$'\t' \
      --with-nth=2.. \
      --height=100% \
      --reverse \
      --header="Tab to select, Enter to confirm" \
      --preview="echo {} | cut -f1 | xargs $BIN_DIR/note-preview" \
      --preview-window=down:60% |
    cut -f1
}
