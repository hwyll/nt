#!/usr/bin/env bash

# Format notes to different output formats

# Convert note data to JSON
# Input: tab-separated note data (from parser)
format_as_json() {
  local output=""
  
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    local id=$(echo "$line" | cut -f1)
    local file=$(echo "$line" | cut -f2)
    local lineno=$(echo "$line" | cut -f3)
    local time=$(echo "$line" | cut -f4)
    local title=$(echo "$line" | cut -f5)
    local tags=$(echo "$line" | cut -f6)
    local content=$(echo "$line" | cut -f7)
    local comments=$(echo "$line" | cut -f8)
    
    # Unescape content
    content=$(echo "$content" | tr '␤' '\n' | tr '␉' '\t')
    comments=$(echo "$comments" | tr '␤' '\n' | tr '␉' '\t')
    
    # Parse tags into array
    local tag_array=$(echo "$tags" | grep -oE "#[$TAG_CHARS]+" | sed 's/^#//' | awk '{printf "\"%s\",", $0}' | sed 's/,$//')
    
    # Parse comments into array
    local comment_array=""
    if [ -n "$comments" ]; then
      comment_array=$(echo "$comments" | awk -F'|' 'NF>=2 {printf "{\"time\":\"%s\",\"text\":\"%s\"},", $1, $2}' | sed 's/,$//')
    fi
    
    # Escape for JSON (backslashes first, then quotes)
    title=$(echo "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
    content=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    
    # Add comma separator if not first
    [ -n "$output" ] && output="$output,"$'\n'
    
    output="$output  {
    \"id\": \"$id\",
    \"file\": \"$file\",
    \"line\": $lineno,
    \"time\": \"$time\",
    \"title\": \"$title\",
    \"tags\": [$tag_array],
    \"content\": \"$content\",
    \"comments\": [$comment_array]
  }"
  done
  
  echo "["
  echo "$output"
  echo "]"
}

# Convert note data to CSV
format_as_csv() {
  echo "id,date,time,title,tags,content"
  
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    local id=$(echo "$line" | cut -f1)
    local time=$(echo "$line" | cut -f4)
    local title=$(echo "$line" | cut -f5)
    local tags=$(echo "$line" | cut -f6)
    local content=$(echo "$line" | cut -f7)
    
    # Extract date from ID
    local date="${id:0:8}"  # YYYYMMDD
    local formatted_date="${date:0:4}-${date:4:2}-${date:6:2}"
    
    # Unescape and clean content
    content=$(echo "$content" | tr '␤' ' ' | tr '␉' ' ' | sed 's/  */ /g')
    
    # Clean tags
    tags=$(echo "$tags" | sed 's/#//g' | tr ' ' ';')
    
    # Escape quotes and commas for CSV
    title=$(echo "$title" | sed 's/"/""/g')
    content=$(echo "$content" | sed 's/"/""/g')
    
    printf '"%s","%s","%s","%s","%s","%s"\n' \
      "$id" "$formatted_date" "$time" "$title" "$tags" "$content"
  done
}

# Convert note data to plain markdown
format_as_markdown() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    local time=$(echo "$line" | cut -f4)
    local title=$(echo "$line" | cut -f5)
    local tags=$(echo "$line" | cut -f6)
    local content=$(echo "$line" | cut -f7)
    local comments=$(echo "$line" | cut -f8)
    
    # Unescape content
    content=$(echo "$content" | tr '␤' '\n' | tr '␉' '\t')
    
    echo "## [$time] $title"
    echo ""
    
    if [ -n "$tags" ]; then
      echo "tags: $tags"
      echo ""
    fi
    
    if [ -n "$content" ]; then
      echo "$content"
    fi
    
    # Parse comments (format: time|text␤time|text␤)
    if [ -n "$comments" ]; then
      echo "$comments" | tr '␤' '\n' | while IFS='|' read -r comment_time comment_text; do
        [ -n "$comment_time" ] && echo "> [$comment_time] $comment_text"
      done
      echo ""
    fi
    
    echo "---"
    echo ""
  done
}

# Convert note data to plain text with colors
format_as_plain() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local id=$(echo "$line" | cut -f1)
    local time=$(echo "$line" | cut -f4)
    local title=$(echo "$line" | cut -f5)
    local tags=$(echo "$line" | cut -f6)
    format_note_line "$id" "$time" "$title" "$tags"
  done
}
