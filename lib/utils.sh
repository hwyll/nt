#!/usr/bin/env bash

# Utility functions for note

# Check if required dependencies are installed
check_dependencies() {
  local missing=()
  
  for cmd in fzf awk sed date; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies: ${missing[*]}" >&2
    echo "Install with: brew install ${missing[*]}" >&2
    return 1
  fi
  
  return 0
}

# Format timestamp with date for list display
# Input: note_id (YYYYMMDDHHMMSS), time (HH:MM:SS±ZZZZ)
format_list_timestamp() {
  local note_id="$1"
  local time="$2"
  
  local year="${note_id:0:4}"
  local month="${note_id:4:2}"
  local day="${note_id:6:2}"
  local hhmm=$(echo "$time" | cut -d: -f1-2)
  local current_year=$(date +%Y)
  
  if [ "$year" = "$current_year" ]; then
    echo "$month/$day $hhmm"
  else
    echo "$year/$month/$day $hhmm"
  fi
}

# Format a single note line with colors
# Output: colored "[time] #tags title" string
format_note_line() {
  local id="$1"
  local time="$2"
  local title="$3"
  local tags="$4"
  
  local display_time=$(format_list_timestamp "$id" "$time")
  local colored_time=$(colorize "$COLOR_TIMESTAMP" "[$display_time]")
  local display_title=""
  [ -n "$title" ] && display_title=$(colorize "$COLOR_TITLE" "$title")
  local display_tags=""
  
  if [ -n "$tags" ] && [ "$COLORS_ENABLED" = "true" ] && [ "$FORCE_COLOR" = "true" ]; then
    display_tags=$(echo "$tags" | sed "s/#\([$TAG_CHARS]*\)/$(printf "$COLOR_TAG")#\1$(printf "$COLOR_RESET")/g")
  elif [ -n "$tags" ]; then
    display_tags="$tags"
  fi
  
  if [ -n "$display_tags" ]; then
    echo "$colored_time $display_tags $display_title"
  else
    echo "$colored_time $display_title"
  fi
}

# Colorize text (only if FORCE_COLOR and colors enabled)
colorize() {
  local color="$1"
  local text="$2"
  
  if [ "$COLORS_ENABLED" = "true" ] && [ "$FORCE_COLOR" = "true" ]; then
    printf "${color}%s${COLOR_RESET}" "$text"
  else
    printf "%s" "$text"
  fi
}

# Confirm action (for deletions, etc.)
confirm() {
  local prompt="$1"
  local response
  
  read -p "$prompt (y/N): " response
  [[ "$response" =~ ^[Yy]$ ]]
}

# Error message
error() {
  echo "Error: $*" >&2
}

# Success message  
success() {
  echo "$*"
}

# Format comma-separated tags into "tags: #tag1 #tag2" line
format_tags_line() {
  local tags="$1"
  local line="tags:"
  local seen=""
  [ -z "$tags" ] && echo "$line" && return
  
  IFS=',' read -ra arr <<< "$tags"
  for tag in "${arr[@]}"; do
    tag="$(echo "$tag" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    # Strip # prefix if present, then sanitize to allowed chars only
    tag="${tag#\#}"
    tag=$(echo "$tag" | grep -oE "[$TAG_CHARS]+" | head -1 | tr '[:upper:]' '[:lower:]')
    # Skip empty or punctuation-only (must have at least one alphanumeric, stricter than TAG_CHARS)
    [[ -z "$tag" || "$tag" =~ ^[^a-zA-Z0-9]+$ ]] && continue
    # Skip duplicates
    [[ " $seen " == *" $tag "* ]] && continue
    seen="$seen $tag"
    line="$line #$tag"
  done
  echo "$line"
}

# Generate note ID from timestamp
# Usage: generate_note_id "HH:MM:SS±ZZZZ"
generate_note_id() {
  local time_digits=$(echo "$1" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | tr -d ':')
  echo "$(date +%Y%m%d)${time_digits}"
}
