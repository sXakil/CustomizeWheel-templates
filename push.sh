#!/bin/bash

# Exit on any error
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/templates_source"
DEST_DIR="$SCRIPT_DIR/templates"

echo "📦 Zipping templates from '$SOURCE_DIR' → '$DEST_DIR'"
echo "──────────────────────────────────────────────────────"

# Iterate over every folder inside templates_source
for folder in "$SOURCE_DIR"/*/; do
  # Skip if not a directory
  [ -d "$folder" ] || continue

  folder_name="$(basename "$folder")"

  # if folder_name/wheel-preview.png exists, delete it
  if [ -f "$SOURCE_DIR/$folder_name/wheel-preview.png" ]; then
    rm "$SOURCE_DIR/$folder_name/wheel-preview.png"
  fi

  zip_path="$DEST_DIR/$folder_name.zip"

  echo "  ▸ Zipping '$folder_name'..."
  # -r  recursive
  # -q  quiet
  # -FS sync: removes files in zip that are no longer in source (acts as overwrite/sync)
  # We run from inside templates_source so the zip contains folder_name/... at the root
  (cd "$SOURCE_DIR" && zip -rq "$zip_path" "$folder_name")
  echo "    ✓ Saved to templates/$folder_name.zip"
done

echo ""
echo "✅ All templates zipped."
echo ""

# Git commit & push
echo "🚀 Pushing to git..."
cd "$SCRIPT_DIR"
git add .
git commit -m "chore: update templates $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo ""
echo "🎉 Done!"
