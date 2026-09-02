#!/usr/bin/env bash
#
# publish.sh — deterministic helpers for the publish-to-github skill.
#
# The INTERACTIVE steps (gh auth login device flow, the push-permission
# confirmation, and gh repo create --push) are driven by the agent from
# SKILL.md so the participant explicitly approves the push. This script only
# does the safe, non-interactive parts:
#
#   publish.sh prep                 Install gh if missing, write .gitignore,
#                                   scan for secrets, start a fresh git history
#                                   for the participant's own repo, and commit.
#                                   Does NOT create a remote or push.
#
#   publish.sh formlink <repo_url>  Print a pre-filled Google Form submission
#                                   URL with the repo URL (and, if available,
#                                   the project title + description from
#                                   project_brief.md) already filled in.
#
#   publish.sh reponame             Print the default repo name:
#                                   buildwithgemini-<project-folder-name>.
#                                   Registration staff look for this prefix
#                                   when redeeming swag, so it's the name
#                                   proposed by default (the participant can
#                                   still override it).
#
# Usage:
#   bash .agents/skills/publish-to-github/publish.sh prep      # install gh, stage, scan
#   bash .agents/skills/publish-to-github/publish.sh commit    # set identity + commit (after auth)
#   bash .agents/skills/publish-to-github/publish.sh reponame  # print the default repo name
#   bash .agents/skills/publish-to-github/publish.sh formlink https://github.com/<you>/<repo>
#
set -euo pipefail

# gh may have been installed to ~/.local/bin by a previous `prep` run; make sure
# every subcommand can find it.
export PATH="$HOME/.local/bin:$PATH"

# --- Swag / gallery submission form -----------------------------------------
# "Build with Gemini: Project Submission and Gallery Entry"
FORM_ID="1FAIpQLSfvbIUMrHLf2iUYVgQkr981unQwuLdigLB7yJp3VdtYH85Dzw"
FORM_BASE="https://docs.google.com/forms/d/e/${FORM_ID}/viewform?usp=pp_url"
ENTRY_TITLE="entry.339694639"     # Project Title
ENTRY_REPO="entry.896374137"      # Public GitHub Repository URL
ENTRY_DESC="entry.82550013"       # Brief Project Description
# Fields deliberately NOT pre-filled (only the participant can answer honestly):
#   entry.1722955442 Full Name        entry.281180358  Email Address
#   entry.86658339   GDP badge claim   entry.1609312251 Consent to be featured

# Upstream lab repo the participant may have cloned (full owner/repo path). If
# the project's origin still points at it, we start a fresh history so the
# published repo is the participant's own. Matching the FULL owner/repo path
# (not just the repo name) means a participant's own same-named repo is not
# mistaken for the upstream on a re-run.
LAB_UPSTREAM_MATCH_1="cszhu/build-with-gemini"

info() { printf '\033[1;34m›\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# gh install (no sudo): drop the binary into ~/.local/bin
# ---------------------------------------------------------------------------
ensure_gh() {
  if command -v gh >/dev/null 2>&1; then
    ok "GitHub CLI (gh) is installed: $(command -v gh)"
    return 0
  fi
  info "GitHub CLI (gh) not found — installing to ~/.local/bin (no sudo needed)…"

  local os arch ghos gharch tag ver tmp url rel_json
  os="$(uname -s)"; arch="$(uname -m)"
  case "$os" in
    Linux)  ghos="linux" ;;
    Darwin) ghos="macOS" ;;
    *) die "Unsupported OS '$os' for auto-install. Install gh manually: https://github.com/cli/cli#installation" ;;
  esac
  case "$arch" in
    x86_64|amd64)   gharch="amd64" ;;
    aarch64|arm64)  gharch="arm64" ;;
    *) die "Unsupported arch '$arch' for auto-install. Install gh manually: https://github.com/cli/cli#installation" ;;
  esac

  command -v curl >/dev/null 2>&1 || die "curl is required to auto-install gh. Install gh manually: https://github.com/cli/cli#installation"

  # Capture the release JSON into a variable FIRST, then parse it. Piping curl
  # straight into `grep -m1` makes grep close the pipe early; under `set -o
  # pipefail` curl then dies with exit 23 ("failure writing output") and aborts
  # the whole script. Parsing a variable avoids the broken pipe entirely.
  rel_json="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null || true)"
  tag="$(printf '%s' "$rel_json" | grep '"tag_name"' | head -n1 \
          | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)"
  if [ -z "$tag" ]; then
    tag="v2.63.2"   # pinned fallback if the API is unreachable or rate-limited
    warn "Could not query the latest gh release — falling back to $tag"
  fi
  ver="${tag#v}"
  tmp="$(mktemp -d)"
  # macOS release assets are .zip; Linux are .tar.gz
  if [ "$ghos" = "macOS" ]; then
    url="https://github.com/cli/cli/releases/download/${tag}/gh_${ver}_${ghos}_${gharch}.zip"
    info "Downloading $url"
    curl -fsSL "$url" -o "$tmp/gh.zip" || die "Download failed: $url"
    ( cd "$tmp" && unzip -q gh.zip )
  else
    url="https://github.com/cli/cli/releases/download/${tag}/gh_${ver}_${ghos}_${gharch}.tar.gz"
    info "Downloading $url"
    curl -fsSL "$url" -o "$tmp/gh.tgz" || die "Download failed: $url"
    ( cd "$tmp" && tar -xzf gh.tgz )
  fi
  mkdir -p "$HOME/.local/bin"
  cp "$tmp"/gh_*/bin/gh "$HOME/.local/bin/gh"
  chmod +x "$HOME/.local/bin/gh"
  rm -rf "$tmp"

  export PATH="$HOME/.local/bin:$PATH"
  command -v gh >/dev/null 2>&1 || die "gh installed to ~/.local/bin but not on PATH. Add: export PATH=\"\$HOME/.local/bin:\$PATH\""
  ok "Installed gh $ver to ~/.local/bin"
  warn "If a later step can't find gh, run:  export PATH=\"\$HOME/.local/bin:\$PATH\""
}

# ---------------------------------------------------------------------------
# .gitignore — don't ship venvs, caches, secrets, or the big raw recording
# ---------------------------------------------------------------------------
write_gitignore() {
  local marker="# --- added by publish-to-github skill ---"
  if [ -f .gitignore ] && grep -qF "$marker" .gitignore; then
    ok ".gitignore already has the publish-to-github block"
    return 0
  fi
  {
    echo ""
    echo "$marker"
    echo ".venv/"
    echo "venv/"
    echo "__pycache__/"
    echo "*.pyc"
    echo "node_modules/"
    echo ".video_tmp/"
    echo ".DS_Store"
    echo ".env"
    echo "*.env"
    echo "application_default_credentials.json"
    echo "*-sa-key.json"
    echo "service-account*.json"
    echo "# Keep the demo GIF (README embeds it); ignore the large raw recording."
    echo "*.webm"
  } >> .gitignore
  ok "Wrote .gitignore"
}

# ---------------------------------------------------------------------------
# Fresh git history so the participant's published repo is THEIR own project,
# not the full history of the cloned lab upstream.
# ---------------------------------------------------------------------------
reset_git_history() {
  local origin_url=""
  if [ -d .git ]; then
    origin_url="$(git remote get-url origin 2>/dev/null || echo "")"
  fi
  case "$origin_url" in
    *"$LAB_UPSTREAM_MATCH_1"*)
      info "This folder is still the cloned lab repo ($origin_url)."
      info "Starting a fresh git history for your own repo — your files are unchanged."
      rm -rf .git
      git init -q
      ;;
    "")
      [ -d .git ] || git init -q
      ;;
    *)
      ok "Using existing git repo (origin: $origin_url)"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Secret scan over the files that would actually be committed.
# ---------------------------------------------------------------------------
secret_scan() {
  local staged offenders="" f
  staged="$(git diff --cached --name-only)"
  [ -n "$staged" ] || return 0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      application_default_credentials.json|.env|*.env|id_rsa|id_ed25519|*.pem|*.key)
        offenders+="  $f  (sensitive filename)"$'\n' ; continue ;;
    esac
    # content check on smallish text files
    if [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -lt 1000000 ]; then
      if grep -qE '("private_key"[[:space:]]*:|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "$f" 2>/dev/null; then
        offenders+="  $f  (looks like a private key / credential)"$'\n'
      fi
      # Hardcoded API keys / tokens, not just credential files. Conservative
      # patterns to avoid false positives on env-var lookups (os.environ[...]).
      if grep -qE 'AIza[0-9A-Za-z_-]{35}' "$f" 2>/dev/null; then
        offenders+="  $f  (looks like a Google API key)"$'\n'
      elif grep -qE 'AKIA[0-9A-Z]{16}' "$f" 2>/dev/null; then
        offenders+="  $f  (looks like an AWS access key ID)"$'\n'
      elif grep -qiE '(api[_-]?key|secret|token)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_-]{16,}["'"'"']' "$f" 2>/dev/null; then
        offenders+="  $f  (looks like a hardcoded API key / secret / token)"$'\n'
      fi
    fi
  done <<< "$staged"

  if [ -n "$offenders" ]; then
    warn "Potential secrets staged — NOT committing. Review and remove these, or add them to .gitignore:"
    printf '%s' "$offenders" >&2
    die "Aborting for safety. Remove the files above (or gitignore them), then re-run."
  fi
  ok "Secret scan passed — nothing sensitive staged"
}

# ---------------------------------------------------------------------------
cmd_prep() {
  [ -d app ] || [ -f project_brief.md ] || [ -f agents-cli-manifest.yaml ] \
    || warn "This doesn't look like your agent project root (no app/, project_brief.md, or agents-cli-manifest.yaml). Run from the project root."

  ensure_gh
  reset_git_history
  write_gitignore

  git add -A
  secret_scan
  git branch -M main 2>/dev/null || true

  echo
  ok "Prep done — your project is staged (not committed, nothing pushed)."
  ok "Next (agent-driven, see SKILL.md): sign in to YOUR GitHub, then run"
  ok "'publish.sh commit', confirm the repo name, and create + push."
}

# Set the commit author from the signed-in GitHub account (privacy-preserving
# noreply email) unless a local identity is already set, then commit.
cmd_commit() {
  [ -d .git ] || die "No git repo here — run 'publish.sh prep' first."

  # Set a per-repo author from the signed-in GitHub account so the participant's
  # own repo is attributed to their personal GitHub (not any global/lab identity).
  # Respect an existing *local* identity if they set one deliberately.
  if ! git config --local user.email >/dev/null 2>&1; then
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      local login name
      login="$(gh api user -q .login 2>/dev/null || echo "")"
      name="$(gh api user -q .name 2>/dev/null || echo "")"
      if [ -n "$login" ]; then
        git config --local user.name "${name:-$login}"
        git config --local user.email "${login}@users.noreply.github.com"
        ok "Commit author set to ${name:-$login} <${login}@users.noreply.github.com>"
      fi
    fi
  fi
  git config user.email >/dev/null 2>&1 \
    || die "No git identity. Sign in first (gh auth login), or set git config user.name/email."

  git add -A
  secret_scan
  if git rev-parse HEAD >/dev/null 2>&1 && git diff --cached --quiet; then
    ok "Already committed — nothing new to add."
  elif git diff --cached --quiet && ! git rev-parse HEAD >/dev/null 2>&1; then
    die "Nothing staged to commit. Run 'publish.sh prep' first."
  else
    git commit -q -m "Build with Gemini: my agentic application"
    ok "Committed your project"
  fi
}

# ---------------------------------------------------------------------------
# Pull a title + one-liner out of project_brief.md if it's there.
# Locate the brief at CWD or the git repo root (the agent is often scaffolded
# into a subfolder, so CWD may not be where project_brief.md lives). Every
# helper returns 0 even on no-match so `set -o pipefail` never aborts formlink.
# ---------------------------------------------------------------------------
brief_file() {
  if [ -f project_brief.md ]; then echo "project_brief.md"; return 0; fi
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ] && [ -f "$root/project_brief.md" ]; then echo "$root/project_brief.md"; fi
  return 0
}
brief_title() {
  local f; f="$(brief_file)"; [ -n "$f" ] || return 0
  # "# My agent: <name>"  ->  <name>
  { grep -m1 -E '^#[[:space:]]*My agent:' "$f" 2>/dev/null \
      | sed -E 's/^#[[:space:]]*My agent:[[:space:]]*//' | tr -d '\r'; } || true
}
brief_desc() {
  local f; f="$(brief_file)"; [ -n "$f" ] || return 0
  # "One-liner: <text>"  ->  <text>
  { grep -m1 -E '^One-liner:' "$f" 2>/dev/null \
      | sed -E 's/^One-liner:[[:space:]]*//' | tr -d '\r'; } || true
}

urlencode() { # via python3 (present in the lab); prints URL-encoded stdin arg
  python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

# ---------------------------------------------------------------------------
# Default repo name: buildwithgemini-<project-folder-name>, slugified.
# Registration staff look for this exact prefix at swag redemption, so it's
# the name proposed by default (the participant can still rename it, but
# should keep the prefix if they do).
# ---------------------------------------------------------------------------
cmd_reponame() {
  local base slug
  base="$(basename "$(pwd)")"
  slug="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  [ -n "$slug" ] || slug="my-agent"
  printf 'buildwithgemini-%s\n' "$slug"
}

cmd_formlink() {
  local repo="${1:-}"
  [ -n "$repo" ] || die "Usage: publish.sh formlink <repo_url>"
  local title desc url
  title="$(brief_title)"
  desc="$(brief_desc)"

  url="${FORM_BASE}&${ENTRY_REPO}=$(urlencode "$repo")"
  [ -n "$title" ] && url="${url}&${ENTRY_TITLE}=$(urlencode "$title")"
  [ -n "$desc" ]  && url="${url}&${ENTRY_DESC}=$(urlencode "$desc")"

  echo
  ok "Pre-filled submission form (repo link already filled in):"
  echo "$url"
  echo
  info "Open it, then add the details only you know: your registration name &"
  info "email, whether you've claimed your GDP badge, and whether you consent to"
  info "be featured in the gallery. Then submit."
}

# ---------------------------------------------------------------------------
main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    prep)      cmd_prep "$@" ;;
    commit)    cmd_commit "$@" ;;
    reponame)  cmd_reponame "$@" ;;
    formlink)  cmd_formlink "$@" ;;
    *) cat >&2 <<EOF
publish.sh — helpers for the publish-to-github skill

Commands:
  prep                 Install gh (if missing), write .gitignore, secret-scan,
                       start a fresh git history, and stage. Does NOT commit or push.
  commit               Set the commit author from your GitHub login, then commit
                       the staged project. Run after 'gh auth login'.
  reponame             Print the default repo name: buildwithgemini-<project-folder-name>.
  formlink <repo_url>  Print the pre-filled swag/gallery submission form URL.
EOF
       exit 2 ;;
  esac
}
main "$@"
