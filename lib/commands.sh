#!/usr/bin/env bash

# Command implementations for note
# Uses global flags: NOTE_QUIET, NOTE_YES

# Quiet-aware success message
cmd_success() {
  [ "$NOTE_QUIET" != "true" ] && success "$@"
}

# List notes command
cmd_list() {
  local format="plain"
  local tag_filter=""
  local since=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      --tag) tag_filter="$2"; shift 2 ;;
      --since) since="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local notes=$(parse_all_notes)
  
  # Apply tag filter
  [ -n "$tag_filter" ] && notes=$(echo "$notes" | grep "#$tag_filter")
  
  # Apply date filter (compare first 8 digits of ID = YYYYMMDD)
  if [ -n "$since" ]; then
    local since_date=""
    
    # Try YYYY-MM-DD format first
    since_date=$(date -j -f "%Y-%m-%d" "$since" "+%Y%m%d" 2>/dev/null) || \
    # Try GNU date relative format (Linux)
    since_date=$(date -d "$since" "+%Y%m%d" 2>/dev/null) || \
    since_date=""
    
    # Handle relative dates on macOS (yesterday, last week, etc.)
    if [ -z "$since_date" ]; then
      case "$since" in
        yesterday) since_date=$(date -v-1d "+%Y%m%d") ;;
        "last week"|"last-week") since_date=$(date -v-7d "+%Y%m%d") ;;
        *) error "Invalid date: $since (use YYYY-MM-DD, yesterday, or 'last week')"; return 1 ;;
      esac
    fi
    
    notes=$(echo "$notes" | awk -F'\t' -v date="$since_date" 'substr($1,1,8) >= date')
  fi
  
  # Format output
  case "$format" in
    json) echo "$notes" | format_as_json ;;
    csv) echo "$notes" | format_as_csv ;;
    markdown|md) echo "$notes" | format_as_markdown ;;
    *) echo "$notes" | format_as_plain ;;
  esac
}

# Edit note command
cmd_edit() {
  local note_id=$(resolve_note_id "${1:-}")
  [ -z "$note_id" ] && error "Note ID required" && return 1
  
  local note_data=$(find_note_by_id "$note_id")
  [ -z "$note_data" ] && error "Note not found: $note_id" && return 1
  
  local file=$(echo "$note_data" | cut -f2)
  local line=$(echo "$note_data" | cut -f3)
  
  "$EDITOR" +"$line" "$file"
}

# Comment command
cmd_comment() {
  local note_id=$(resolve_note_id "${1:-}")
  [ -z "$note_id" ] && error "Note ID required" && return 1
  
  local comment_text="${2:-}"
  [ -z "$comment_text" ] && error "Comment text required" && return 1
  
  local note_data=$(find_note_by_id "$note_id")
  [ -z "$note_data" ] && error "Note not found: $note_id" && return 1
  
  add_comment_to_note "$note_id" "$comment_text"
  local result=$?
  
  if [ $result -eq 0 ]; then
    cmd_success "Comment added to note $note_id"
    return 0
  else
    error "Failed to add comment"
    return 1
  fi
}

# Tag command
cmd_tag() {
  local note_id=$(resolve_note_id "${1:-}")
  [ -z "$note_id" ] && error "Note ID required" && return 1
  
  local tag_spec="${2:-}"
  [ -z "$tag_spec" ] && error "Tags required" && return 1
  
  local note_data=$(find_note_by_id "$note_id")
  [ -z "$note_data" ] && error "Note not found: $note_id" && return 1
  
  local current_tags=$(echo "$note_data" | cut -f6)
  local new_tags=""
  
  # Incremental mode: +tag adds, -tag removes
  # Note: requires alphanumeric after +/- (not TAG_CHARS) so "+.foo" doesn't trigger this
  if [[ "$tag_spec" =~ (^|[[:space:]])[+-][a-zA-Z0-9] ]]; then
    new_tags="$current_tags"
    local tag
    
    # Process +tags (add)
    for tag in $(echo "$tag_spec" | grep -oE "(^|[[:space:]])\+[$TAG_CHARS]+" | tr -d ' +'); do
      [[ "$new_tags" != *"#$tag"* ]] && new_tags="$new_tags #$tag"
    done
    
    # Process -tags (remove)
    for tag in $(echo "$tag_spec" | grep -oE "(^|[[:space:]])-[$TAG_CHARS]+" | tr -d ' -'); do
      new_tags=$(echo "$new_tags" | sed "s/#$tag//g")
    done
    
    # Clean up whitespace and convert to comma-separated for format_tags_line
    new_tags=$(echo "$new_tags" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr ' ' ',')
  else
    # Replacement mode: normalize spaces to commas, let format_tags_line handle the rest
    new_tags=$(echo "$tag_spec" | tr ' ' ',')
  fi
  
  update_note_tags "$note_id" "$new_tags"
  cmd_success "Tags updated for note $note_id"
  return 0
}

# Delete note command
cmd_delete() {
  local note_id=$(resolve_note_id "${1:-}")
  [ -z "$note_id" ] && error "Note ID required" && return 1
  
  local note_data=$(find_note_by_id "$note_id")
  [ -z "$note_data" ] && error "Note not found: $note_id" && return 1
  
  # Confirm unless -y flag or CONFIRM_DELETE=false
  if [ "$NOTE_YES" != "true" ] && [ "$CONFIRM_DELETE" = "true" ]; then
    confirm "Delete note $note_id?" || return 0
  fi
  
  delete_note "$note_id"
  cmd_success "Note deleted: $note_id"
  return 0
}

# Export command (alias for cmd_list)
cmd_export() {
  cmd_list "$@"
}

# Tags command - list all tags
cmd_tags() {
  parse_all_notes | cut -f6 | tr ' ' '\n' | grep -E '^#' | sort | uniq -c | \
    awk '{printf "%-20s %d\n", $2, $1}' | sort -k2 -rn
}
