#!/usr/bin/env bash

# Configuration management for note

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/note/note.conf"
COLOR_RESET=$'\033[0m'

# Load user configuration
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^#.*$ ]] && continue
      [[ -z "$key" ]] && continue
      [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue
      
      # Skip if already set in environment (env takes precedence)
      [ -n "${!key}" ] && continue

      # Remove quotes
      # Strip inline comments
      value="${value%%#*}"
      value="${value%"${value##*[![:space:]]}"}"  # trim trailing whitespace
      
      # Remove quotes
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      
      # Expand ~ to home directory
      value="${value/#\~/$HOME}"
      
      # Expand escape sequences for color codes
      [[ "$key" == COLOR_* ]] && value=$(echo -e "$value")

      eval "$key=\$value"
    done <"$CONFIG_FILE"
  fi

  # Tag pattern: allowed characters in tag names
  # Note: separate from alphanumeric checks in commands.sh/utils.sh which validate tag starts
  TAG_CHARS='a-zA-Z0-9._-'

  # Defaults (config and env vars take precedence)
  NOTES_DIR="${NOTES_DIR:-$HOME/notes}"
  EDITOR="${EDITOR:-vim}"
  COLORS_ENABLED="${COLORS_ENABLED:-true}"
  CONFIRM_DELETE="${CONFIRM_DELETE:-true}"
  DISPLAY_TIMEZONE="${DISPLAY_TIMEZONE:-local}"  # local or utc
  COLOR_TIMESTAMP="${COLOR_TIMESTAMP:-$'\033[35m'}"
  COLOR_TITLE="${COLOR_TITLE:-$'\033[0m'}"
  COLOR_TAG="${COLOR_TAG:-$'\033[33m'}"
  COLOR_CONTENT="${COLOR_CONTENT:-$'\033[37m'}"
  COLOR_LABEL="${COLOR_LABEL:-$'\033[2;37m'}"
  COLOR_BORDER="${COLOR_BORDER:-$'\033[2;37m'}"
  BORDER_CHAR="${BORDER_CHAR:-━}"
  BORDER_WIDTH="${BORDER_WIDTH:-0}"
  COLOR_DIVIDER="${COLOR_DIVIDER:-$'\033[2;37m'}"
  COLOR_BRANCH="${COLOR_BRANCH:-$'\033[2;37m'}"
  COLOR_META="${COLOR_META:-$'\033[2;37m'}"
}

# Get notes directory
get_notes_dir() {
  echo "$NOTES_DIR"
}

# Get file path for a date
get_note_file() {
  local date="$1" # Format: YYYY-MM-DD

  local year month day
  year=$(echo "$date" | cut -d- -f1)
  month=$(echo "$date" | cut -d- -f2)
  day=$(echo "$date" | cut -d- -f3)

  local dir="$NOTES_DIR/$year/$month"
  mkdir -p "$dir"

  echo "$dir/$day.md"
}

# Get today's file (UTC)
get_today_file() {
  get_note_file "$(date -u +%Y-%m-%d)"
}
