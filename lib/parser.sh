#!/usr/bin/env bash

# Parser for note markdown format
# Compatible with macOS (BSD sed/awk/grep)

# Note data format: tab-separated fields
# Field 1: id        - epoch seconds
# Field 2: file      - full path to .md file
# Field 3: line      - line number of note header
# Field 4: time      - YYYY-MM-DD HH:MM:SSZ (UTC)
# Field 5: title     - note title text
# Field 6: tags      - space-separated #tags (may be empty)
# Field 7: content   - note body (␤ = newline, ␉ = tab)
# Field 8: comments  - time|text pairs (␤ separated)
#
# Use `cut -f<N>` to extract fields (preserves empty fields)
# Do NOT use `IFS=$'\t' read` - it collapses empty fields

# Parse note file and extract all notes
# Input: file path
# Output: Array of note data (one per line, tab-separated fields)
parse_note_file() {
  local file="$1"
  
  [ ! -f "$file" ] && return 1
  
  local in_note=false
  local note_id=""
  local note_time=""
  local note_title=""
  local note_tags=""
  local note_content=""
  local note_comments=""
  local line_num=0
  local header_line=0
  
  while IFS= read -r line || [ -n "$line" ]; do
    ((line_num++))
    
    # Check for note header: ## [YYYY-MM-DD HH:MM:SSZ] Title
    if [[ "$line" =~ ^##[[:space:]]\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})Z\][[:space:]](.*)$ ]]; then
      # Save previous note if exists
      if $in_note; then
        output_note "$file" "$note_id" "$header_line" "$note_time" "$note_title" "$note_tags" "$note_content" "$note_comments"
      fi
      
      # Start new note
      in_note=true
      header_line=$line_num
      note_time="${BASH_REMATCH[1]}Z"
      note_title="${BASH_REMATCH[2]}"
      note_tags=""
      note_content=""
      note_comments=""
      note_id=$(compute_note_id "$file" "$note_time")
      
    # Check for tags line: tags: #tag1 #tag2
    elif $in_note && [[ "$line" =~ ^tags:[[:space:]]*(.*)$ ]]; then
      note_tags="${BASH_REMATCH[1]}"
      
    # Check for comment: > [YYYY-MM-DD HH:MM:SSZ] Comment text
    elif $in_note && [[ "$line" =~ ^\>[[:space:]]\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})Z\][[:space:]](.*)$ ]]; then
      local comment_time="${BASH_REMATCH[1]}Z"
      local comment_text="${BASH_REMATCH[2]}"
      note_comments="${note_comments}${comment_time}|${comment_text}
"
      
    # Check for separator: ---
    elif [[ "$line" =~ ^---$ ]]; then
      if $in_note; then
        output_note "$file" "$note_id" "$header_line" "$note_time" "$note_title" "$note_tags" "$note_content" "$note_comments"
        in_note=false
      fi
      
    # Content line
    elif $in_note && [ -n "$line" ]; then
      note_content="${note_content}${line}
"
    fi
    
  done < "$file"
  
  # Output last note if file doesn't end with separator
  if $in_note; then
    output_note "$file" "$note_id" "$header_line" "$note_time" "$note_title" "$note_tags" "$note_content" "$note_comments"
  fi
}

# Output note in tab-separated format
# Fields: id, file, line, time, title, tags, content, comments
output_note() {
  local file="$1"
  local id="$2"
  local line="$3"
  local time="$4"
  local title="$5"
  local tags="$6"
  local content="$7"
  local comments="$8"
  
  # Escape tabs and newlines in content
  content=$(echo -n "$content" | tr '\n' '␤' | tr '\t' '␉')
  comments=$(echo -n "$comments" | tr '\n' '␤' | tr '\t' '␉')
  
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$id" "$file" "$line" "$time" "$title" "$tags" "$content" "$comments"
}

# Compute note ID from file and time
# Format: Unix epoch seconds
compute_note_id() {
  local file="$1"
  local time="$2"  # YYYY-MM-DD HH:MM:SSZ
  
  # Strip Z suffix and convert to epoch
  local time_sec="${time%Z}"
  date -j -u -f "%Y-%m-%d %H:%M:%S" "$time_sec" "+%s" 2>/dev/null
}

# Parse all notes in directory (recursive)
parse_all_notes() {
  local dir="${1:-$(get_notes_dir)}"
  
  # Find all .md files, sort by ID (oldest first)
  find "$dir" -type f -name "*.md" | while read -r file; do
    parse_note_file "$file"
  done | sort -t$'\t' -k1
}

# Find note by ID
find_note_by_id() {
  local id="$1"
  local result=""
  
  result=$(parse_all_notes | while IFS= read -r line; do
    local note_id=$(echo "$line" | cut -f1)
    if [ "$note_id" = "$id" ]; then
      echo "$line"
      break
    fi
  done)
  
  [ -n "$result" ] && echo "$result" && return 0
  return 1
}

# Resolve note ID from various input formats
resolve_note_id() {
  local input="$1"
  
  case "$input" in
    # Full epoch seconds ID (10 digits)
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
      echo "$input"
      return 0
      ;;
    
    # Relative: latest, oldest, -1, -2, etc.
    latest|-1)
      parse_all_notes | tail -n 1 | cut -f1
      return 0
      ;;
    
    oldest)
      parse_all_notes | head -n 1 | cut -f1
      return 0
      ;;
    
    -[0-9]*)
      local offset="${input#-}"
      parse_all_notes | tail -n "$offset" | head -n 1 | cut -f1
      return 0
      ;;
    
    *)
      # Try to find by title match
      local result=""
      result=$(parse_all_notes | while IFS= read -r line; do
        local id=$(echo "$line" | cut -f1)
        local title=$(echo "$line" | cut -f5)
        if [[ "$title" == *"$input"* ]]; then
          echo "$id"
          break
        fi
      done)
      [ -n "$result" ] && echo "$result" && return 0
      return 1
      ;;
  esac
}
