#!/usr/bin/env bash
#
# Configure the GitHub environments and variables used by the workflows.
#
# Prerequisites:
#   - gh authenticated with the "repo" scope (gh auth login)
#   - jq and terraform installed
#   - AWS credentials allowed to read the Terraform state
#   - the target environment has already been applied with Terraform
#
# Usage:
#   AWS_PROFILE=dev-admin ./scripts/setup-github-env.sh dev
#   AWS_PROFILE=dev-admin ./scripts/setup-github-env.sh prod
#   AWS_PROFILE=dev-admin ./scripts/setup-github-env.sh all
#
# Environment overrides:
#   REVIEWER_LOGIN   GitHub user approving prod deployments (default: ebouther)
#   GITHUB_REPOSITORY  owner/repo (default: detected with gh)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVIEWER_LOGIN="${REVIEWER_LOGIN:-ebouther}"

for tool in gh jq terraform; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool is required" >&2
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

if [[ -z "$REPO" ]]; then
  echo "error: unable to detect the GitHub repository. Set GITHUB_REPOSITORY=owner/repo." >&2
  exit 1
fi

resolve_environments() {
  case "${1:-}" in
    dev | prod) printf '%s\n' "$1" ;;
    all) printf '%s\n' dev prod ;;
    *)
      echo "usage: $0 <dev|prod|all>" >&2
      exit 1
      ;;
  esac
}

ensure_environment() {
  local environment="$1"
  gh api --method PUT "repos/${REPO}/environments/${environment}" >/dev/null
  echo "environment ${environment}: ready"
}

configure_prod_protection() {
  local reviewer_id
  reviewer_id="$(gh api "users/${REVIEWER_LOGIN}" --jq .id)"

  if [[ -z "$reviewer_id" || "$reviewer_id" == "null" ]]; then
    echo "error: unable to resolve the GitHub user id for ${REVIEWER_LOGIN}" >&2
    exit 1
  fi

  jq -n \
    --argjson reviewer_id "$reviewer_id" \
    '{
      prevent_self_review: false,
      reviewers: [{type: "User", id: $reviewer_id}],
      deployment_branch_policy: {
        protected_branches: false,
        custom_branch_policies: true
      }
    }' |
    gh api --method PUT "repos/${REPO}/environments/prod" --input - >/dev/null

  local existing
  existing="$(gh api "repos/${REPO}/environments/prod/deployment-branch-policies" --paginate --jq '.branch_policies[] | "\(.type):\(.name)"')"

  if ! grep -Fxq "branch:main" <<<"$existing"; then
    gh api --method POST "repos/${REPO}/environments/prod/deployment-branch-policies" \
      -f name=main -f type=branch >/dev/null
    echo "environment prod: allowed branch main"
  fi

  if ! grep -Fxq "tag:v*" <<<"$existing"; then
    gh api --method POST "repos/${REPO}/environments/prod/deployment-branch-policies" \
      -f name='v*' -f type=tag >/dev/null
    echo "environment prod: allowed tag v*"
  fi

  echo "environment prod: reviewer ${REVIEWER_LOGIN} (self-review allowed)"
}

configure_environment_variables() {
  local environment="$1"
  local output_file error_file
  output_file="$(mktemp)"
  error_file="$(mktemp)"

  if ! terraform -chdir="${ROOT_DIR}/infra/envs/${environment}" output -json >"$output_file" 2>"$error_file"; then
    echo "error: unable to read Terraform outputs for ${environment}." >&2
    echo "       Run 'terraform init' and 'terraform apply' for this environment first." >&2
    sed 's/^/       /' "$error_file" >&2
    rm -f "$output_file" "$error_file"
    exit 1
  fi

  local aws_region app_role terraform_role ecr_repository ecs_cluster ecs_service
  local task_family codedeploy_app codedeploy_group alb_name container_name container_port

  aws_region="$(jq -r '.aws_region.value // empty' "$output_file")"
  app_role="$(jq -r '.github_app_role_arn.value // empty' "$output_file")"
  terraform_role="$(jq -r '.github_terraform_role_arn.value // empty' "$output_file")"
  ecr_repository="$(jq -r '.ecr_repository_name.value // empty' "$output_file")"
  ecs_cluster="$(jq -r '.ecs_cluster_name.value // empty' "$output_file")"
  ecs_service="$(jq -r '.ecs_service_name.value // empty' "$output_file")"
  task_family="$(jq -r '.task_definition_family.value // empty' "$output_file")"
  codedeploy_app="$(jq -r '.codedeploy_application.value // empty' "$output_file")"
  codedeploy_group="$(jq -r '.codedeploy_deployment_group.value // empty' "$output_file")"
  alb_name="$(jq -r '.alb_name.value // empty' "$output_file")"
  container_name="$(jq -r '.container_name.value // empty' "$output_file")"
  container_port="$(jq -r '.container_port.value // empty' "$output_file")"

  local -A values=(
    [AWS_REGION]="$aws_region"
    [AWS_ROLE_ARN]="$app_role"
    [TERRAFORM_ROLE_ARN]="$terraform_role"
    [ECR_REPOSITORY]="$ecr_repository"
    [ECS_CLUSTER]="$ecs_cluster"
    [ECS_SERVICE]="$ecs_service"
    [TASK_DEFINITION_FAMILY]="$task_family"
    [CODEDEPLOY_APPLICATION]="$codedeploy_app"
    [CODEDEPLOY_DEPLOYMENT_GROUP]="$codedeploy_group"
    [ALB_NAME]="$alb_name"
    [CONTAINER_NAME]="$container_name"
    [CONTAINER_PORT]="$container_port"
  )

  local name value
  for name in "${!values[@]}"; do
    value="${values[$name]}"
    if [[ -z "$value" ]]; then
      echo "error: Terraform output for ${name} is empty in ${environment}." >&2
      exit 1
    fi
  done

  for name in $(printf '%s\n' "${!values[@]}" | sort); do
    gh variable set "$name" --env "$environment" --body "${values[$name]}" --repo "$REPO" >/dev/null
    echo "environment ${environment}: ${name}=${values[$name]}"
  done

  rm -f "$output_file" "$error_file"
}

main() {
  local environments environment
  environments="$(resolve_environments "${1:-}")"

  echo "repository: ${REPO}"

  for environment in $environments; do
    ensure_environment "$environment"
    configure_environment_variables "$environment"

    if [[ "$environment" == "prod" ]]; then
      configure_prod_protection
    fi
  done

  cat <<EOF

GitHub configuration complete.

Next steps:
  - run ./scripts/protect-main.sh (after the pull request is merged)
  - trigger the "Deploy" workflow for the first dev deployment
  - apply infra/envs/prod manually, then push a vX.Y.Z tag for production
EOF
}

main "$@"
