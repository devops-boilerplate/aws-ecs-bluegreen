#!/usr/bin/env bash
#
# Protect the main branch and enforce the pull-request workflow.
#
# Run this script once, after the CI/CD pull request has been merged.
# It requires the "repo" scope on the gh token and admin rights on the
# repository.
#
# Usage:
#   ./scripts/protect-main.sh
#
# Environment overrides:
#   GITHUB_REPOSITORY  owner/repo (default: detected with gh)

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh is required" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

if [[ -z "$REPO" ]]; then
  echo "error: unable to detect the GitHub repository. Set GITHUB_REPOSITORY=owner/repo." >&2
  exit 1
fi

echo "repository: ${REPO}"

protection_applied=false
if gh api --method PUT "repos/${REPO}/branches/main/protection" --input - >/dev/null 2>&1 <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Workflow lint",
      "Dockerfile lint",
      "App quality",
      "Secret scan",
      "Dependency and IaC scan",
      "Terraform format",
      "Terraform validate (bootstrap)",
      "Terraform validate (dev)",
      "Terraform validate (prod)",
      "Terraform plan (dev)"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
then
  protection_applied=true
else
  echo "warning: branch protection is unavailable for this repository on the current GitHub plan." >&2
fi

# These repository settings do not require branch protection and are safe to
# apply on every plan.
gh api --method PATCH "repos/${REPO}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true \
  -F allow_update_branch=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY >/dev/null

# Release tags must not be moved or deleted: the image tag is immutable and the
# deployed digest is resolved from it.
RULESET_NAME="release-tags"
RULESET_ID="$(gh api "repos/${REPO}/rulesets" --paginate \
  --jq ".[] | select(.name == \"${RULESET_NAME}\") | .id" 2>/dev/null | head -n 1 || true)"

RULESET_PAYLOAD="$(jq -n --arg name "$RULESET_NAME" '{
  name: $name,
  target: "tag",
  enforcement: "active",
  conditions: {
    ref_name: {
      include: ["refs/tags/v*"],
      exclude: []
    }
  },
  rules: [
    {type: "deletion"},
    {type: "update"}
  ]
}')"

ruleset_applied=false
if [[ -n "$RULESET_ID" ]]; then
  if gh api --method PUT "repos/${REPO}/rulesets/${RULESET_ID}" --input - <<<"$RULESET_PAYLOAD" >/dev/null 2>&1; then
    ruleset_applied=true
  fi
else
  if gh api --method POST "repos/${REPO}/rulesets" --input - <<<"$RULESET_PAYLOAD" >/dev/null 2>&1; then
    ruleset_applied=true
  fi
fi

if [[ "$ruleset_applied" != true ]]; then
  echo "warning: repository rulesets are unavailable for this repository on the current GitHub plan." >&2
fi

cat <<EOF

Protection status:
  - branch protection: $(if [[ "$protection_applied" == true ]]; then echo "applied"; else echo "unavailable"; fi)
  - release-tag ruleset: $(if [[ "$ruleset_applied" == true ]]; then echo "applied"; else echo "unavailable"; fi)
  - repository merges: squash-only, branch deleted after merge
  - post-push guard: .github/workflows/main-guard.yml fails when a commit
    reaches main without a merged pull request

EOF

if [[ "$protection_applied" == true ]]; then
  cat <<EOF
main is protected:
  - pull requests are mandatory, even for administrators
  - the branch must be up to date with main
  - all CI checks must pass
  - linear history only (squash merge), force pushes and deletions blocked
  - conversations must be resolved before merging

EOF
else
  cat <<EOF
Hard branch protection could not be applied. GitHub Free for private
repositories does not provide branch protection or repository rulesets.
The squash-only merge setting and the Main guard workflow remain active.

To enable hard protection, upgrade the repository to GitHub Pro or make it
public, then rerun this script.

EOF
fi

if [[ "$ruleset_applied" == true ]]; then
  cat <<EOF
Release tags matching v* cannot be moved or deleted. To recover from a bad tag,
disable the release-tags ruleset in Settings > Rules, fix the tag, then re-enable
it.

EOF
else
  cat <<EOF
Release tags are not protected by a ruleset on this plan. Do not move or delete
a v* tag manually; publish a new patch version instead.

EOF
fi

cat <<EOF
If a check is renamed in .github/workflows/ci.yml, update the contexts list in
this script and run it again.
EOF
