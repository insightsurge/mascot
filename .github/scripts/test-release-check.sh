#!/usr/bin/env bash
# Tries release-check.sh against throwaway git repositories: good and bad versions, headings, tags and releases.
# Run it from anywhere: bash .github/scripts/test-release-check.sh. Prints one line per case and fails on a surprise.
set -uo pipefail

script=$(cd "$(dirname "$0")" && pwd)/release-check.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# A fake `gh`: `release view` succeeds only for tags listed in $FAKE_RELEASES; `release create` logs its arguments.
mkdir "$work/bin"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
if [ "$1 $2" = "release view" ]; then grep -qx "$3" "$FAKE_RELEASES"; exit $?; fi
if [ "$1 $2" = "release create" ]; then echo "$*" >>"$FAKE_LOG"; exit 0; fi
exit 1
GH
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" FAKE_RELEASES="$work/releases" FAKE_LOG="$work/log" MAIN_REF=main

# repo <version> <news heading> <news body> <changelog heading>: a repository whose main holds one commit.
repo() {
  rm -rf "$work/r" && mkdir -p "$work/r/vignettes/articles" && cd "$work/r" || exit 1
  git init -q -b main . && git config user.name t && git config user.email t@example.com
  printf 'Package: mascot\nVersion: %s\n' "$1" >DESCRIPTION
  printf '%s\n%s\n\n# mascot 0.0.1\n\n* An older change.\n' "$2" "$3" >NEWS.md
  printf -- '---\ntitle: x\n---\n\n%s\n\n## a\n\n# mascot 0.0.1\n' "$4" >vignettes/articles/engine-changelog.Rmd
  git add -A && git commit -q -m c
  : >"$FAKE_RELEASES" && : >"$FAKE_LOG"
}

# expect <name> <exit 0|1> <text the output must contain> <arguments>
expect() {
  local name=$1 want=$2 text=$3
  shift 3
  local out code
  out=$(bash "$script" "$@" 2>&1)
  code=$?
  if [ "$code" = "$want" ] && printf '%s' "$out" | grep -qF -- "$text"; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $code, wanted $want, wanted text: $text)"
    printf '%s\n' "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
}
created() { grep -c 'release create' "$FAKE_LOG"; }
check_created() {
  if [ "$(created)" = "$1" ]; then echo "ok   $2"; else echo "FAIL $2 (releases created: $(created), wanted $1)"; failures=$((failures + 1)); fi
}

repo 0.1.0 "# mascot 0.1.0" "* A change." "# mascot 0.1.0"
sha=$(git rev-parse HEAD)
expect "check only passes" 0 "agree" "$sha"
expect "short SHA passes" 0 "agree" "${sha:0:8}"
check_created 0 "check only publishes nothing"
expect "publish creates a release" 0 "Published release v0.1.0" --publish "$sha"
check_created 1 "publish created exactly one release"
grep -q -- '--target' "$FAKE_LOG" && echo "ok   a new tag is created at the commit" || { echo "FAIL no --target"; failures=$((failures + 1)); }
grep -q -- '--prerelease' "$FAKE_LOG" && { echo "FAIL release marked as pre-release"; failures=$((failures + 1)); } || echo "ok   a release version is not a pre-release"
expect "not a SHA" 1 "hexadecimal SHA" "main"
expect "no argument" 1 "hexadecimal SHA"
expect "unknown commit" 1 "not found" "deadbeef"

# A tag on this commit but no release yet (a failed first run): the release is created from the existing tag.
git tag v0.1.0
expect "tag without a release gets its release" 0 "Published release v0.1.0" --publish "$sha"
grep -q -- '--verify-tag' "$FAKE_LOG" && echo "ok   an existing tag is verified, not retargeted" || { echo "FAIL no --verify-tag"; failures=$((failures + 1)); }
# A tag and a release: nothing to do.
echo v0.1.0 >"$FAKE_RELEASES"; : >"$FAKE_LOG"
expect "a second run does nothing" 0 "nothing to do" --publish "$sha"
check_created 0 "a second run creates nothing"
# A release but no tag in the clone.
git tag -d v0.1.0 >/dev/null
expect "release without its tag fails" 1 "its tag is not in this clone" --publish "$sha"
git tag v0.1.0

# A tag on another commit is never moved.
echo more >>NEWS.md && git commit -qam second
second=$(git rev-parse HEAD)
: >"$FAKE_RELEASES"
expect "tag on another commit fails" 1 "Tags are never moved" --publish "$second"
check_created 0 "nothing created for a tag on another commit"
# An annotated tag counts too.
git tag -d v0.1.0 >/dev/null && git tag -a v0.1.0 -m x "$sha"
expect "annotated tag on the right commit passes" 0 "agree" "$sha"

# A commit that is not on main.
git checkout -q -b side && echo x >x && git add x && git commit -qm side
expect "commit off main fails" 1 "not on main" "$(git rev-parse HEAD)"
git checkout -q main

# Disagreements and empty sections.
repo 0.1.0 "# mascot 0.1.1" "* A change." "# mascot 0.1.0"
expect "NEWS heading for another version fails" 1 "NEWS.md must have exactly one heading" "$(git rev-parse HEAD)"
repo 0.1.0 "# mascot 0.1.0" "* A change." "# mascot (development version)"
expect "engine changelog heading for another version fails" 1 "engine-changelog.Rmd must have exactly one heading" "$(git rev-parse HEAD)"
repo 0.1.0 "# mascot 0.1.0" "" "# mascot 0.1.0"
expect "empty NEWS section fails" 1 "is empty" "$(git rev-parse HEAD)"
repo 0.1.0 "# mascot (development version)" "* A change." "# mascot 0.1.0"
expect "development heading on a release version fails" 1 "NEWS.md must have exactly one heading" "$(git rev-parse HEAD)"
repo 0.1 "# mascot 0.1" "* A change." "# mascot 0.1"
expect "unusable version fails" 1 "no usable Version" "$(git rev-parse HEAD)"

# Development versions and milestone releases go through the same path.
repo 0.1.0.9000 "# mascot (development version)" "* A change." "# mascot (development version)"
expect "development version publishes as a pre-release" 0 "Published release v0.1.0.9000" --publish "$(git rev-parse HEAD)"
grep -q -- '--prerelease' "$FAKE_LOG" && echo "ok   the development release is marked as a pre-release" || { echo "FAIL not a pre-release"; failures=$((failures + 1)); }
repo 0.0.3 "# mascot 0.0.3" "Development milestone; not released on CRAN." "# mascot 0.0.3"
expect "milestone release publishes" 0 "Published release v0.0.3" --publish "$(git rev-parse HEAD)"

if [ "$failures" = 0 ]; then echo "All release-check cases behaved as expected."; else echo "$failures case(s) failed."; exit 1; fi
