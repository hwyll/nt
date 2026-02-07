#!/usr/bin/env bash

# Writer for note - create and modify notes

# Generate UTC timestamp
# Sets: TIMESTAMP (string), NOTE_ID (epoch seconds)
generate_timestamp() {
  NOTE_ID=$(date -u +%s)
  TIMESTAMP="$(date -u -r "$NOTE_ID" "+%Y-%m-%d %H:%M:%S")Z"
}

# Locate note by ID, sets NOTE_FILE and NOTE_LINE
# Usage: locate_note "$note_id" || return 1
locate_note() {
  local note_data=$(find_note_by_id "$1")
  [ -z "$note_data" ] && error "Note not found: $1" && return 1
  NOTE_FILE=$(echo "$note_data" | cut -f2)
  NOTE_LINE=$(echo "$note_data" | cut -f3)
}

# Create a new note
# Usage: create_note "title" "tags" "content"
create_note() {
  local title="$1"
  local tags="$2"
  local content="$3"
  
  local file=$(get_today_file)
  generate_timestamp
  local tags_line=$(format_tags_line "$tags")
  
  # Create note block
  {
    [ -s "$file" ] && echo ""  # separator if file has content
    echo "## [$TIMESTAMP] $title"
    echo ""
    echo "$tags_line"
    
    if [ -n "$content" ]; then
      echo ""
      echo "$content"
    fi
    
    echo ""
    echo "---"
  } >> "$file"
  
  echo "$NOTE_ID"
}

# Add comment to a note
# Usage: add_comment_to_note "note_id" "comment_text"
add_comment_to_note() {
  local note_id="$1"
  local comment_text="$2"
  
  locate_note "$note_id" || return 1
  generate_timestamp
  
  local tmp=$(mktemp)
  local in_target_note=false
  local current_line=0
  local comment_inserted=false
  
  while IFS= read -r file_line; do
    ((current_line++))
    
    # Found our note
    if [ $current_line -eq $NOTE_LINE ]; then
      in_target_note=true
      echo "$file_line" >> "$tmp"
      continue
    fi
    
    # In our note, look for separator or next note header
    if $in_target_note && ! $comment_inserted; then
      if [[ "$file_line" =~ ^---$ ]] || [[ "$file_line" =~ ^##[[:space:]]\[ ]]; then
        # Insert comment before separator or next note
        echo "> [$TIMESTAMP] $comment_text" >> "$tmp"
        comment_inserted=true
      fi
    fi
    
    echo "$file_line" >> "$tmp"
    
  done < "$NOTE_FILE"
  
  # If note was last in file without separator, append comment
  if $in_target_note && ! $comment_inserted; then
    echo "" >> "$tmp"
    echo "> [$TIMESTAMP] $comment_text" >> "$tmp"
  fi
  
  # Replace original file
  mv "$tmp" "$NOTE_FILE"
  
  return 0
}

# Update tags for a note
# Usage: update_note_tags "note_id" "new_tags"
update_note_tags() {
  local note_id="$1"
  local new_tags="$2"
  
  locate_note "$note_id" || return 1
  
  local tags_line=$(format_tags_line "$new_tags")
  
  # Update the tags line (should be within 3 lines after header)
  local tmp=$(mktemp)
  local current_line=0
  local header_found=false
  local tags_updated=false
  
  while IFS= read -r file_line; do
    ((current_line++))
    
    # Found our note header
    if [ $current_line -eq $NOTE_LINE ]; then
      header_found=true
      echo "$file_line" >> "$tmp"
      continue
    fi
    
    # Within first few lines after header, look for tags line
    if $header_found && ! $tags_updated && [ $current_line -le $((NOTE_LINE + 3)) ]; then
      if [[ "$file_line" =~ ^tags: ]]; then
        # Replace tags line
        echo "$tags_line" >> "$tmp"
        tags_updated=true
        continue
      fi
    fi
    
    # Stop looking after separator or next note
    if [[ "$file_line" =~ ^---$ ]] || [[ "$file_line" =~ ^##[[:space:]]\[ ]]; then
      header_found=false
    fi
    
    echo "$file_line" >> "$tmp"
    
  done < "$NOTE_FILE"
  
  mv "$tmp" "$NOTE_FILE"
  
  return 0
}

# Delete a note
# Usage: delete_note "note_id"
delete_note() {
  local note_id="$1"
  
  locate_note "$note_id" || return 1
  
  # Delete note block (from ## to ---)
  local tmp=$(mktemp)
  local in_target_note=false
  local current_line=0
  
  while IFS= read -r file_line; do
    ((current_line++))
    
    # Found our note - start skipping
    if [ $current_line -eq $NOTE_LINE ]; then
      in_target_note=true
      continue
    fi
    
    # Skip lines while in target note
    if $in_target_note; then
      # Found separator - stop skipping, don't output separator
      if [[ "$file_line" =~ ^---$ ]]; then
        in_target_note=false
        continue
      fi
      # Still in note, skip this line
      continue
    fi
    
    # Not in target note, output line
    echo "$file_line" >> "$tmp"
    
  done < "$NOTE_FILE"
  
  # Clean up: trim edges, collapse consecutive blank lines
  sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" 2>/dev/null || sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp"
  sed -i '' '/./,$!d' "$tmp" 2>/dev/null || sed -i '/./,$!d' "$tmp"
  cat -s "$tmp" > "$tmp.squeezed" && mv "$tmp.squeezed" "$tmp"
  
  # Remove file if empty, otherwise replace original
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp" "$NOTE_FILE"
    rmdir -p "$(dirname "$NOTE_FILE")" 2>/dev/null || true  # clean empty parent dirs
  else
    mv "$tmp" "$NOTE_FILE"
  fi
  
  return 0
}

# Open editor for multiline note
# Usage: create_note_with_editor "title" "tags"
create_note_with_editor() {
  local title="$1"
  local tags="$2"
  
  local tmp=$(mktemp)
  generate_timestamp
  local tags_line=$(format_tags_line "$tags")
  
  # Create template
  cat > "$tmp" << EOF
## [$TIMESTAMP] ${title}

$tags_line

(Add your content here. Lines starting with > will be treated as comments.)

EOF
  
  # Open editor (connect to TTY for interactive use)
  "$EDITOR" "$tmp" < /dev/tty > /dev/tty
  
  # Check if file was modified (has content beyond template)
  if grep -q "(Add your content here" "$tmp"; then
    # User didn't edit - remove placeholder
    sed -i '' '/^(Add your content here/d' "$tmp"
  fi
  
  # Append to today's file
  local file=$(get_today_file)
  echo "" >> "$file"
  cat "$tmp" >> "$file"
  echo "" >> "$file"
  echo "---" >> "$file"
  
  rm -f "$tmp"
  
  echo "$NOTE_ID"
}
