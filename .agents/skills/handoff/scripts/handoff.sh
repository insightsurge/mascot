#!/usr/bin/env bash
# Handoff helper: scaffold and check dev/handoffs/ (local, gitignored notes).
#
#   handoff.sh init                 root index + overview/ (multi-area projects)
#   handoff.sh start <name>         a new area or feature folder from the templates
#   handoff.sh status [<name>]      one line per folder: Status and Next step
#   handoff.sh check [<name>]       lint: README present and short, status dated and
#                                   not stale, handoff-internal paths exist; exit 1 on warnings
#
# Handoffs always live in the main checkout, also when this runs in a git worktree.
# Options (environment): HANDOFF_STALE_DAYS (default 14), HANDOFF_README_MAX (default 60),
# HANDOFF_CHECK_REPO_PATHS=1 (also check repository paths such as `tools/x.R`).
# Portable to macOS's bash 3.2 (no associative arrays, no mapfile).
set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
stale_days="${HANDOFF_STALE_DAYS:-14}"
readme_max="${HANDOFF_README_MAX:-60}"

# Main checkout, even from a worktree: the parent of the common .git directory.
common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
  echo "not inside a git repository" >&2
  exit 2
}
root="$(cd "$common/.." && pwd)"
base="$root/dev/handoffs"
today="$(date +%Y-%m-%d)"

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

require_ignored() {
  if ! git -C "$root" check-ignore -q "dev/handoffs/probe.md"; then
    echo "refusing: dev/handoffs/ is not gitignored in $root (add 'dev/handoffs/' to .gitignore)" >&2
    exit 1
  fi
  mkdir -p "$base"
}

fill() { # template name -> destination, with {{NAME}} and {{DATE}}
  sed -e "s/{{NAME}}/$2/g" -e "s/{{DATE}}/$today/g" "$1" > "$3"
}

start_folder() {
  local name="$1" dest="$base/$1" f
  if ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "name must be kebab-case: $name" >&2
    exit 2
  fi
  if [ -e "$dest" ]; then
    echo "exists: $dest (use /handoff update $name)" >&2
    exit 1
  fi
  mkdir -p "$dest"
  for f in "$skill_dir"/templates/area/*.md; do
    fill "$f" "$name" "$dest/$(basename "$f")"
  done
  echo "created $dest"
}

# Folders to report on: every directory not starting with _ or ., or just the one named.
folders() {
  local only="${1:-}" d
  if [ -n "$only" ]; then
    [ -d "$base/$only" ] || { echo "no such handoff: $only" >&2; exit 2; }
    echo "$base/$only"
    return
  fi
  for d in "$base"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    case "$(basename "$d")" in _* | .*) continue ;; esac
    echo "$d"
  done
}

label() { # README, label -> the text after "**Label...:**"
  grep -m1 -E "^\*\*$2" "$1" 2>/dev/null | sed -E "s/^\*\*$2[^*]*\*\* ?//" || true
}

days_since() { # YYYY-MM-DD -> whole days until today (BSD or GNU date)
  local then
  then="$(date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || true)"
  [ -n "$then" ] || return 0
  echo $((($(date +%s) - then) / 86400))
}

cmd_status() {
  local d status next
  while read -r d; do
    status="$(label "$d/README.md" "Status")"
    next="$(label "$d/README.md" "Next step")"
    printf '%-16s %s\n' "$(basename "$d")" "${status:-(no Status line)}" | cut -c1-140
    if [ -n "$next" ]; then printf '%-16s next: %s\n' "" "$next" | cut -c1-140; fi
  done < <(folders "${1:-}")
}

# Handoff-internal paths in backticks must exist: `dev/handoffs/...`, `../...`, or a path
# whose first folder exists in this folder or in dev/handoffs/ (e.g. `research/x.md`).
# These are the links that break when handoffs are reorganised. A first folder can exist
# in several places (an area `brand/` and the repo's `brand/`): the path is fine if it
# exists under any of them. Bare file names, placeholders (<x>, *, {a,b}, $VAR) and URLs
# are skipped. Paths that match only at the repo root are checked too with
# HANDOFF_CHECK_REPO_PATHS=1.
check_paths() { # folder, file
  local d="$1" file="$2" name path first handoff found
  name="$(basename "$d")"
  { grep -oE '`[^` ]+/[^` ]+\.(md|sh|R|qmd|yml|yaml|json|html|tsv|lua|scss|css)`' "$file" || true; } |
    tr -d '`' | sort -u | while read -r path; do
    case "$path" in *'<'* | *'*'* | *'{'* | *'$'* | http* | /*) continue ;; esac
    first="${path%%/*}"
    handoff=0 found=0
    if [ "${path#dev/handoffs/}" != "$path" ]; then
      handoff=1
      [ ! -e "$root/$path" ] || found=1
    elif [ "$first" = ".." ]; then
      handoff=1
      [ ! -e "$d/$path" ] || found=1
    else
      # Candidates: this folder, dev/handoffs/ and the repo root.
      if [ -d "$d/$first" ]; then
        handoff=1
        [ ! -e "$d/$path" ] || found=1
      fi
      if [ -d "$base/$first" ]; then
        handoff=1
        [ ! -e "$base/$path" ] || found=1
      fi
      if [ -e "$root/$first" ]; then
        [ ! -e "$root/$path" ] || found=1
      fi
    fi
    if [ "$handoff" = "0" ]; then
      [ "${HANDOFF_CHECK_REPO_PATHS:-0}" = "1" ] && [ -e "$root/$first" ] || continue
    fi
    [ "$found" = "1" ] || echo "WARN $name/$(basename "$file"): missing path \`$path\`"
  done
}

# Prints one "WARN ..." line per problem.
cmd_check() {
  local d name readme n status date age file
  [ -f "$base/README.md" ] || echo "WARN dev/handoffs/README.md (root index) is missing: run 'handoff.sh init'"
  while read -r d; do
    name="$(basename "$d")"
    readme="$d/README.md"
    if [ ! -f "$readme" ]; then
      echo "WARN $name: README.md missing"
      continue
    fi
    n="$(wc -l < "$readme" | tr -d ' ')"
    [ "$n" -le "$readme_max" ] ||
      echo "WARN $name: README.md has $n lines (max $readme_max): move finished work to 06-delivered.md"
    status="$(grep -m1 -E '^\*\*Status' "$readme" || true)"
    if [ -z "$status" ]; then
      echo "WARN $name: README has no **Status** line"
    elif ! echo "$status" | grep -qi 'closed'; then
      date="$(echo "$status" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)"
      if [ -z "$date" ]; then
        echo "WARN $name: Status has no date (write **Status (YYYY-MM-DD):**)"
      else
        age="$(days_since "$date")"
        if [ -n "$age" ] && [ "$age" -gt "$stale_days" ]; then
          echo "WARN $name: Status is $age days old: verify it against the tracker"
        fi
      fi
    fi
    for file in "$d"/*.md; do
      if [ -f "$file" ]; then check_paths "$d" "$file"; fi
    done
  done < <(folders "${1:-}")
}

case "${1:-}" in
  init)
    require_ignored
    if [ -e "$base/README.md" ]; then
      echo "exists: $base/README.md"
    else
      fill "$skill_dir/templates/root/README.md" "handoffs" "$base/README.md"
      echo "created $base/README.md"
    fi
    if [ ! -e "$base/overview" ]; then
      start_folder overview
      fill "$skill_dir/templates/overview/decisions.md" "overview" "$base/overview/decisions.md"
      # The overview has no code: drop the code map and its read-order entry.
      rm -f "$base/overview/02-code-map.md"
      sed -i.bak -e 's/ → `02-code-map.md`//' \
        -e 's#`01-feature.md` → `04-plan.md`#`04-plan.md` → `05-questions.md` → `decisions.md`#' \
        "$base/overview/README.md"
      rm -f "$base/overview/README.md.bak"
    fi
    ;;
  start)
    [ -n "${2:-}" ] || usage
    require_ignored
    start_folder "$2"
    ;;
  status)
    cmd_status "${2:-}"
    ;;
  check)
    out="$(cmd_check "${2:-}")"
    if [ -n "$out" ]; then
      echo "$out"
      exit 1
    fi
    echo "OK: handoffs look consistent"
    ;;
  *) usage ;;
esac
