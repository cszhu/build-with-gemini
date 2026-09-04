---
name: publish-to-github
description: >-
  Publish the participant's finished lab project to THEIR OWN personal GitHub and
  hand them a pre-filled swag/gallery submission form. Use at the very end of the
  lab when the user wants to "publish my project to GitHub", "push my code to
  GitHub", "upload my agent/project", "put my code on my own GitHub", "ship my
  project", "submit my project for swag", or "enter the gallery". Signs in to the
  user's personal GitHub via the gh CLI device flow (a one-time code, no SSH keys
  or tokens to paste), creates a PUBLIC repo, and pushes — but ALWAYS asks the
  user to confirm the repo name and account before pushing anything. Then prints a
  Google Form link with the repo URL pre-filled. Ships ./publish.sh for the
  deterministic parts. Not for deploying the agent (agents-cli) or the frontend
  (Cloud Run) — this publishes source code to GitHub.
---

# Publish the project to the participant's own GitHub

The lab runs inside an **ephemeral workstation** — when the lab ends, the machine
and the code on it are gone. This skill gets the participant's project safely onto
**their own personal GitHub** (so they keep it and can share it), then hands them a
**pre-filled submission form** for swag and the project gallery.

The friction-killer is the **GitHub CLI device flow**: the participant enters a
one-time code at `github.com/login/device` from *any* device — no SSH keys, no
tokens to paste. The gh token lives and dies with the workstation; the repo lives
forever on their account.

> **The one rule — never push without explicit confirmation.** This creates a repo
> on the participant's *personal* GitHub. Before creating the repo or pushing,
> STOP and get an explicit "yes" on the repo name and that it's their account.
> Don't let them blind-approve — call out the name and account first.

## How it works

```
project files ─▶ publish.sh prep ─▶ gh auth login (device code) ─▶ publish.sh commit
              ─▶ [CONFIRM with the user] ─▶ gh repo create --public --push ─▶ repo URL
              ─▶ publish.sh formlink <repo_url> ─▶ pre-filled submission form
```

`./publish.sh` does the deterministic, non-interactive parts (install gh, write
`.gitignore`, scan for secrets, start a fresh history, build the form link). The
**interactive** parts — the device-flow sign-in and the push — are driven here so
the participant explicitly approves the push.

Run everything from the **project root** (where `app/` / `project_brief.md` /
`agents-cli-manifest.yaml` live). Ideally the participant has already done the
"Share What You Built" step, so a `README.md` and demo GIF are in the repo.

> **Honesty over polish.** A not-yet-working project is fine to publish — a
> dishonest one is not. If you (re)generate the README, ground it in the actual
> code (`app/`, `agents-cli-manifest.yaml`): list only the tools/services really
> wired up, and mark planned-but-unfinished features as such. The demo GIF must
> be a real `record-demo` recording of the running app — never a drawn or
> AI-synthesized mock-up. Don't inflate claims to make the project look more
> complete than it is. Strip any live links to `localhost` or ephemeral lab Cloud
> URLs (Cloud Run / Agent Engine) from the README — they 404 once the workstation
> is gone; give run instructions instead of a dead clickable link.

## Step 1 — Prep (install gh, stage, scan). No commit, no push.

```bash
bash .agents/skills/publish-to-github/publish.sh prep
export PATH="$HOME/.local/bin:$PATH"   # in case prep just installed gh here
```

This installs `gh` if missing (into `~/.local/bin`, no sudo), writes a `.gitignore`
(ignores `.venv/`, `__pycache__/`, `node_modules/`, `*.webm`, secrets; **keeps the
demo GIF**), scans the staged files for accidental secrets (aborts if it finds any),
starts a **fresh git history** if the folder is still the cloned lab repo, and
stages everything. It does **not** commit or push.

If the secret scan aborts, remove or `.gitignore` the flagged file and re-run.

## Step 2 — Sign in to the participant's OWN GitHub (device flow)

Check first, then log in only if needed:

```bash
gh auth status >/dev/null 2>&1 || printf 'y\n' | gh auth login --hostname github.com --git-protocol https --web
```

The `printf 'y\n'` pre-answers gh's one interactive prompt — *"Authenticate Git
with your GitHub credentials? (Y/n)"* — which otherwise stalls a non-interactive
run (answering yes sets up the git credential helper so the later push works).
`gh auth login` then prints a **one-time code** and the URL `https://github.com/login/device`.
Relay both to the participant and tell them:

> Open **github.com/login/device** on any device, sign in with **your personal
> GitHub account** (not the Qwiklabs lab account), and enter this code: `XXXX-XXXX`.

The command **blocks while polling**, so allow a generous timeout and have them
authorize promptly. Confirm success with `gh auth status` (it shows the logged-in
account — sanity-check it's their personal account, not a lab/shared one).

## Step 3 — Commit (author = their GitHub identity)

```bash
bash .agents/skills/publish-to-github/publish.sh commit
```

This sets the commit author from their signed-in GitHub login (using the
privacy-preserving `<login>@users.noreply.github.com` email) and commits the staged
project.

## Step 4 — CONFIRM, then create the repo and push

Pick a repo name. Get the default with:

```bash
bash .agents/skills/publish-to-github/publish.sh reponame
```

This prints `buildwithgemini-<project-folder-name>` (slugified) — the naming
convention registration staff check for when redeeming swag. Propose this name
first. The participant can rename it, but if they do, tell them to keep the
`buildwithgemini-` prefix so it's still recognized at the registration desk.

Then **ask for explicit confirmation** before doing anything remote, e.g.:

> I'm about to create a **public** repo **`<name>`** on your GitHub account
> **`<login>`** and push your project to it. Good to go?

Only after they say yes:

```bash
gh repo create <name> --public --source=. --remote=origin --push
gh repo view --json url -q .url    # print the repo URL
```

- **Public** is required for the gallery and social sharing.
- If the name is already taken on their account, gh errors — pick another name
  (e.g. add a short suffix) and re-confirm.

## Step 5 — Hand them the pre-filled submission form

```bash
bash .agents/skills/publish-to-github/publish.sh formlink "<repo_url>"
```

This prints a Google Form link with the **repo URL** (and, if present in
`project_brief.md`, the **project title** and **description**) already filled in.
Tell the participant to open it and add the fields only they can answer — their
**registration name & email**, whether they've **claimed their GDP badge**, and
whether they **consent to be featured** — then submit.

Submitting the form is how they enter for swag and the project gallery (the form
states the current eligibility terms). Standout projects are hand-picked by the
team and featured in the **Build with Gemini track 3 GitHub gallery** — this
skill doesn't touch that repo; the team curates it from submissions.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `gh: command not found` after prep | `export PATH="$HOME/.local/bin:$PATH"`; if still missing, install manually: https://github.com/cli/cli#installation |
| gh auto-install fails | No `curl`/internet, or a locked-down image — install gh manually (link above), then re-run from Step 2. |
| Login stalls at `Authenticate Git with your GitHub credentials? (Y/n)` | Use the Step 2 command (it pipes `printf 'y\n'`), or just answer `Y`. The device code appears right after. |
| Device code expired / login hung | Re-run `gh auth login --hostname github.com --git-protocol https --web`; authorize the new code promptly. |
| Signed into the wrong GitHub account | `gh auth logout`, then log in again with their personal account (or `gh auth switch`). Verify with `gh auth status`. |
| `git commit` fails: no identity | They aren't signed in yet — do Step 2 first, then `publish.sh commit`. |
| `repo create` fails: name already exists | Pick a different repo name (add a suffix) and re-confirm before pushing. |
| `remote origin already exists` | The folder wasn't re-initialized (it's already their own repo). Either push to the existing remote (`git push -u origin main`) or set the remote to the new repo. |
| Secret scan aborted | A credential/key is staged — remove it or add it to `.gitignore`, then re-run. Never commit `application_default_credentials.json`, `.env`, or service-account keys. |
| Permission / 403 during push | See the `troubleshoot-lab-setup` skill; confirm the signed-in GitHub account can create repos. |

## Reference

- Helper: `./publish.sh` (`prep`, `commit`, `reponame`, `formlink`)
- Submission form: "Build with Gemini: Project Submission and Gallery Entry"
- gh device flow: https://cli.github.com/manual/gh_auth_login
