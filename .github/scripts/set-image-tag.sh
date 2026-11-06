#!/usr/bin/env bash
# Sets the image tag in a values file.
# Usage: set-image-tag.sh <values file> <tag>
# The tag must be a full commit SHA in lower case hex. The file must have
# exactly one line that starts with two spaces and `tag: `, which is the tag
# under `image:`. Prints `changed` or `unchanged`.
set -euo pipefail

file="${1:?values file}"
tag="${2:?image tag}"

case "$tag" in
  *[!0-9a-f]*)
    echo "the tag must be a lower case hex commit SHA" >&2
    exit 2
    ;;
esac
if [ "${#tag}" -ne 40 ]; then
  echo "the tag must be a full 40 character commit SHA" >&2
  exit 2
fi

count="$(grep -cE '^  tag: ' "$file" || true)"
if [ "$count" != "1" ]; then
  echo "expected one 'tag:' line in $file, found $count" >&2
  exit 1
fi

current="$(sed -nE 's/^  tag: (.*)$/\1/p' "$file")"
if [ "$current" = "$tag" ]; then
  echo "unchanged"
  exit 0
fi

sed -E "s/^(  tag: ).*\$/\1${tag}/" "$file" >"${file}.new"
mv "${file}.new" "$file"
echo "changed"
