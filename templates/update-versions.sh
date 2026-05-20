#!/usr/bin/env bash
# Updates the "Latest Image Versions" section in README.md based on docker-compose.yml.
#
# Usage:
# 1) From the repo root: ./templates/update-versions.sh
# 2) Commit the updated README.md if needed.
#
# Note: This script is intended for steute internal use only.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
compose_file="$repo_root/docker-compose.yml"
readme_file="$repo_root/README.md"

echo "Warning: This script is intended for steute internal use only." >&2

if [[ ! -f "$compose_file" ]]; then
  echo "Missing $compose_file" >&2
  exit 1
fi

if [[ ! -f "$readme_file" ]]; then
  echo "Missing $readme_file" >&2
  exit 1
fi

images=()
while IFS= read -r img; do
  images+=("$img")
done < <(sed -n 's/^[[:space:]]*image:[[:space:]]*//p' "$compose_file")

if [[ ${#images[@]} -eq 0 ]]; then
  echo "No images found in $compose_file" >&2
  exit 1
fi

bullet_lines=()
for img in "${images[@]}"; do
  if [[ "$img" == dhi.io/* ]]; then
    bullet_lines+=("- \`$img\` or \`${img#dhi.io/}\`")
  else
    bullet_lines+=("- \`$img\`")
  fi
done

date_str="$(date "+%b. %d, %Y" | sed 's/ 0/ /')"

block_file="$(mktemp)"
{
  echo ""
  echo "As of $date_str, the script generates a Docker Compose file using these image versions:"
  echo ""
  printf '%s\n' "${bullet_lines[@]}"
  echo ""
} > "$block_file"

tmp_file="$(mktemp)"
awk -v block_file="$block_file" '
BEGIN { state = 0 }

function print_new_block() {
  while ((getline line < block_file) > 0) {
    print line
  }
  close(block_file)
}

{
  if ($0 ~ /^## Latest Image Versions/) {
    print $0
    print_new_block()
    state = 2
    next
  }

  if (state == 2) {
    if ($0 ~ /^Other versions/ || $0 ~ /^For older versions/) {
      print $0
      state = 0
    }
    next
  }

  print $0
}
' "$readme_file" > "$tmp_file"

mv "$tmp_file" "$readme_file"
rm -f "$block_file"

version_line="$(grep -E '^Version [0-9]+\.[0-9]+\.[0-9]+' "$readme_file" | head -n 1 || true)"
if [[ -z "$version_line" ]]; then
  echo "No version line found in $readme_file" >&2
  exit 1
fi

version="${version_line#Version }"
IFS='.' read -r major minor patch <<< "$version"
minor=$((minor + 1))
new_version="$major.$minor.0"

tmp_file="$(mktemp)"
awk -v new_version="$new_version" '
BEGIN { replaced = 0 }
{
  if (!replaced && $0 ~ /^Version [0-9]+\.[0-9]+\.[0-9]+/) {
    print "Version " new_version
    replaced = 1
    next
  }
  print $0
}
' "$readme_file" > "$tmp_file"

mv "$tmp_file" "$readme_file"
