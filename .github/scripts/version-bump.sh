#!/usr/bin/env bash
set -euo pipefail

before=${1:-}
project=Breathe.xcodeproj/project.pbxproj

version=$(grep -m1 -oE 'MARKETING_VERSION = [^;]+' "$project" | awk '{print $3}')
build=$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [^;]+' "$project" | awk '{print $3}')

bumped=false
if [ -n "$before" ] && ! [[ "$before" =~ ^0+$ ]] && git cat-file -e "$before^{commit}" 2>/dev/null; then
  if git diff "$before" HEAD -- "$project" | grep -qE '^\+[[:space:]]*(MARKETING_VERSION|CURRENT_PROJECT_VERSION) = '; then
    bumped=true
  fi
fi

echo "Breathe $version ($build), bumped since ${before:-nothing}: $bumped"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=$version"
    echo "build=$build"
    echo "bumped=$bumped"
  } >> "$GITHUB_OUTPUT"
fi
