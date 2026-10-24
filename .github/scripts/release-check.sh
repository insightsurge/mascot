#!/usr/bin/env bash
# Checks that a commit on main can be released, then tags and publishes it (release.yml runs this by hand, after
# CRAN accepts the version). Usage: release-check.sh [--publish] <commit>
#
# Without --publish it only checks and prints what it would do. The checks, in order:
#   - the commit is on main (an ancestor of origin/main);
#   - DESCRIPTION's version, the NEWS.md heading and the engine changelog heading agree (a release X.Y.Z has the
#     heading "# mascot X.Y.Z", a development version X.Y.Z.9000 has "# mascot (development version)") and the NEWS
#     section has text;
#   - an existing tag vX.Y.Z points at this commit. A tag is never moved or deleted: a tag on another commit fails.
# Then, with --publish, it creates the GitHub release (and with it the tag) unless the release exists already, so a
# re-run after a failed release step finishes the job and a re-run after success does nothing. Development
# versions are published as pre-releases.
# Needs a full clone (fetch-depth 0), and `gh` with GH_TOKEN when publishing. MAIN_REF (default origin/main) names
# main, so the checks can be tried against a throwaway repository.
set -euo pipefail

publish=false
if [ "${1:-}" = "--publish" ]; then
  publish=true
  shift
fi
input=${1:-}
main_ref=${MAIN_REF:-origin/main}
news=NEWS.md
changelog=vignettes/articles/engine-changelog.Rmd

fail() {
  echo "::error::$*"
  exit 1
}

if ! printf '%s' "$input" | grep -Eq '^[0-9a-fA-F]{7,40}$'; then
  fail "Give the commit as a hexadecimal SHA of 7 to 40 characters."
fi
sha=$(git rev-parse --verify -q "$input^{commit}") || fail "Commit $input not found."
if ! git merge-base --is-ancestor "$sha" "$main_ref"; then
  fail "Commit $sha is not on main: only a commit on main is released."
fi
# Read every file from the commit itself, not from the working tree.
git cat-file -e "$sha:DESCRIPTION" 2>/dev/null || fail "DESCRIPTION not found at $sha."
ver=$(git show "$sha:DESCRIPTION" | sed -n 's/^Version:[[:space:]]*//p' | tr -d '[:space:]')
if printf '%s' "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  heading="# mascot $ver"
  prerelease=false
elif printf '%s' "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  heading="# mascot (development version)"
  prerelease=true
else
  fail "DESCRIPTION has no usable Version (found '$ver')."
fi
tag="v$ver"

news_text=$(git show "$sha:$news" 2>/dev/null) || fail "$news not found at $sha."
changelog_text=$(git show "$sha:$changelog" 2>/dev/null) || fail "$changelog not found at $sha."
n=$(printf '%s\n' "$news_text" | grep -cFx "$heading" || true)
[ "$n" = 1 ] || fail "$news must have exactly one heading '$heading' for version $ver (found $n)."
n=$(printf '%s\n' "$changelog_text" | grep -cFx "$heading" || true)
[ "$n" = 1 ] || fail "$changelog must have exactly one heading '$heading' for version $ver (found $n)."

notes_file=$(mktemp)
printf '%s\n' "$news_text" | awk -v h="$heading" '
  $0 == h { p = 1; next }
  /^# / { p = 0 }
  p' >"$notes_file"
if ! grep -q '[^[:space:]]' "$notes_file"; then
  fail "The $news section '$heading' is empty."
fi

tag_state=missing
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  tag_sha=$(git rev-parse "refs/tags/$tag^{commit}")
  if [ "$tag_sha" != "$sha" ]; then
    fail "Tag $tag already points at $tag_sha, not at $sha. Tags are never moved: release the commit the tag points at, or use a new version."
  fi
  tag_state=ok
fi

echo "Version $ver ($tag) at $sha: DESCRIPTION, $news and $changelog agree."
[ "$tag_state" = ok ] && echo "Tag $tag already points at this commit."
$publish || { echo "Check only: nothing published."; exit 0; }

if gh release view "$tag" >/dev/null 2>&1; then
  [ "$tag_state" = ok ] || fail "A release $tag exists but its tag is not in this clone."
  echo "Release $tag already exists: nothing to do."
  exit 0
fi

args=("$tag" --title "mascot $ver" --notes-file "$notes_file" --generate-notes)
if [ "$tag_state" = ok ]; then
  args+=(--verify-tag)
else
  args+=(--target "$sha")
fi
$prerelease && args+=(--prerelease)
gh release create "${args[@]}"
echo "Published release $tag."
