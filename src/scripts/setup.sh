#!/bin/sh
# Interactive first-run configuration for Penpot Desktop.
# Walks .env.example line by line: comments and already-set values are
# carried over as-is, unset variables are prompted for (PENPOT_SECRET_KEY
# is auto-generated instead of prompted). Keeping .env.example as the
# single source of truth means adding a variable there is enough to wire
# it into this script — nothing to update here.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env}"
EXAMPLE_FILE="${2:-$SCRIPT_DIR/.env.example}"

if [ -f "$ENV_FILE" ]; then
  echo "$ENV_FILE already exists — nothing to do."
  exit 0
fi

if [ ! -f "$EXAMPLE_FILE" ]; then
  echo "Error: $EXAMPLE_FILE not found." >&2
  exit 1
fi

echo "Penpot Desktop — first-run setup"
echo "Filling in unset variables from $(basename "$EXAMPLE_FILE"). Press Enter to leave blank."
echo

: > "$ENV_FILE"

# Read .env.example on fd 3, keeping stdin free for the prompts below.
while IFS= read -r line <&3 || [ -n "$line" ]; do
  case "$line" in
    ''|'#'*)
      printf '%s\n' "$line" >> "$ENV_FILE"
      continue
      ;;
  esac

  key="${line%%=*}"
  value="${line#*=}"

  if [ -n "$value" ]; then
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    continue
  fi

  if [ "$key" = "PENPOT_SECRET_KEY" ]; then
    value=$(openssl rand -base64 64 | tr -d '\n')
    echo "Generated $key" >&2
  else
    printf '%s: ' "$key" >&2
    read -r value
  fi

  printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
done 3< "$EXAMPLE_FILE"

echo >&2
echo "Wrote $ENV_FILE" >&2
