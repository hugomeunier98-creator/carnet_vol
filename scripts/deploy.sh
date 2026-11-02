#!/usr/bin/env bash
# Builds the web app and publishes it to GitHub Pages: build/web is a
# checkout of the gh-pages branch. Each deploy is stamped with a build id
# that the app compares against build.json to update itself (see
# web/index.html).
#
# Usage: scripts/deploy.sh "Deploy: short description"
set -euo pipefail
cd "$(dirname "$0")/.."

message="${1:-Deploy}"
build_id="$(date +%Y%m%d-%H%M)-$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain -- lib web pubspec.yaml)" ]; then
  build_id="$build_id-dirty"
fi

# MSYS_NO_PATHCONV stops Git Bash on Windows rewriting /carnet_vol/ into a
# Windows path.
MSYS_NO_PATHCONV=1 flutter build web --base-href /carnet_vol/

cd build/web
sed -i "s/__BUILD_ID__/$build_id/" index.html

# Files the app re-downloads before reloading into a new build.
files=$(find . \( -path ./.git -o -path ./canvaskit \) -prune -o -type f \
  \( -name '*.js' -o -name '*.json' -o -name '*.otf' -o -name '*.ttf' -o -name '*.bin' \) \
  -print | sed 's|^\./||' | grep -v '^build\.json$' | sort | sed 's/.*/"&"/' | paste -sd, -)
printf '{"buildId":"%s","files":[%s]}\n' "$build_id" "$files" > build.json

git add -A
git commit -q -m "$message ($build_id)"
git push -q origin gh-pages
echo "Pushed build $build_id"

# Wait for GitHub Pages to publish it, when the gh CLI is available.
if command -v gh >/dev/null; then
  commit=$(git rev-parse HEAD)
  for _ in $(seq 1 40); do
    status=$(gh api repos/hugomeunier98-creator/carnet_vol/pages/builds/latest \
      --jq '.status + " " + .commit' 2>/dev/null || true)
    case "$status" in
      "built $commit") echo "Live: https://hugomeunier98-creator.github.io/carnet_vol/"; exit 0 ;;
      errored*) echo "GitHub Pages build failed" >&2; exit 1 ;;
    esac
    sleep 5
  done
  echo "Still publishing; check GitHub Pages later." >&2
fi
