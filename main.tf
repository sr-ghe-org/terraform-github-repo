/**
 * This module standardizes the initialization of resources sets required to onboard as per the Seed pattern requested.
 *
 * ## Intended Use
 * 
 * If we wanted to onboard a repository of a particular type (for example a TFW control repo) it would look like the following:
 *
 * ```hcl
 * module "control_repository" {
 *   source                 = "https://app.terraform.io/bankofnovascotia/terraform-github-repo/bns"
 *   repository_description = "A sample Terraform Workspace control repo that will never exist."
 *   repository_name        = "tfw-abcd-small-description-here"
 *   repository_topics      = [ "test", "does-not-exist" ]
 *   repository_type        = {
 *     template_name      = "twf-sample-template",
 *     template_owner     = "fakeorg"
 *     gitignore_template = "Terraform"
 *     license_template   = "None"
 *   }
 *   wif         = {
 *     gcp = {
 *       service_account = "projects/dummysa/serviceAccounts/sdfsdf@dummysa.iam.gserviceaccount.com"
 *       project_number  = "blah"
 *       pool_id         = "testpool"
 *       provider_id     = "testprovider"
 *     },
 *     hve = {
 *       address           = "blah.bloo.blee"
 *       namespace         = "doesnotexist"
 *       auth_path         = "/foo/fee/fum"
 *       binding_claim_org = "dne"
 *     }
 *   }
 *   team_id                = "test_team_id"
 *   workload_id            = "ABCD"
 * }
 * ```
 *  
 * The following templates are supported:
 *
 * | Repo Type | Description | Pull Request | Merge | Tag |
 * | --------- | ----------- | ---------- | ----------- | -------- |
 * | [Docker Image](https://github.com/bns-infra/docker-image-template) | A Bank standard for managing custom Docker images | [Validate](./.github/workflows/validate_docker.yaml) | N/A | [Publish](./.github/workflows/publish_docker.yaml) |
 * | [Helm Chart](https://github.com/bns-infra/helm-chart-template) | A Bank standard for managing custom Helm charts | [Validate](./.github/workflows/validate_helm.yaml) | N/A | [Publish](./.github/workflows/publish_helm.yaml) |
 * | [Rego Policy Set](https://github.com/bns-infra/rego-policy-set-template) | A Bank standard for managing Rego-based policy sets | [Validate](./.github/workflows/validate_rego_policy_set.yaml) | N/A | [Publish](./.github/workflows/publish_rego_policy_set.yaml) |
 * | [Rego Policy Controller](https://github.com/bns-infra/rego-policy-controller-template) | A Bank standard for managing Rego-based GKE attestation policies | [Validate](./.github/workflows/validate_rego_policy_controller.yaml) | N/A | N/A |
 * | [Config Sync: Root](https://github.com/bns-infra/config-sync-root-template) | A Bank standard for managing standard GKE configuration | [Validate](./.github/workflows/validate_config_sync_root.yaml) | N/A | N/A |
 * | [Terraform Module](https://github.com/bns-infra/terraform-module-template)| A Bank standard terraform module repository | [Validate](./.github/workflows/validate_terraform_module.yaml) | N/A | [Publish](./.github/workflows/publish_terraform_module.yaml) |
 *
 * Any other repository templates entered will fail validation.
 *
 */

# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2


# -------------------------
# Repository Configuration.
# -------------------------

resource "github_repository" "ghe_repo" {
  name                   = var.repository_name
  description            = var.repository_description
  visibility             = "private"
  has_issues             = false
  has_discussions        = false
  has_projects           = false
  has_wiki               = true
  is_template            = false
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = false
  allow_auto_merge       = false
  delete_branch_on_merge = false
  auto_init              = false
  gitignore_template     = var.repository_type.gitignore_template
  license_template       = var.repository_type.license_template
  archived               = false
  archive_on_destroy     = true
  allow_update_branch    = false
  topics                 = var.repository_topics
  template {
    owner                = var.repository_type.template_owner
    repository           = var.repository_type.template_name
    include_all_branches = false
  }
}

# Add the repository to the team.
resource "github_team_repository" "repo" {
  team_id    = var.team_id
  repository = github_repository.ghe_repo.name
  permission = "maintain"
}

# Branch Configuration
resource "github_branch" "ghe_branch" {
  repository = github_repository.ghe_repo.name
  branch     = "main"
  depends_on = [github_repository.ghe_repo]
}

# Branch Protection Configuration
resource "github_branch_protection" "main_branch_protection" {
  repository_id                   = github_repository.ghe_repo.node_id
  pattern                         = "main"
  enforce_admins                  = false
  require_signed_commits          = false
  required_linear_history         = true
  require_conversation_resolution = true
  force_push_bypassers            = []
  allows_deletions                = false
  allows_force_pushes             = false
  lock_branch                     = false

  required_status_checks {
    strict = true
  }

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    restrict_dismissals             = false
    dismissal_restrictions          = []
    pull_request_bypassers          = []
    require_code_owner_reviews      = true
    required_approving_review_count = 2
  }

  restrict_pushes {
    blocks_creations = true
    push_allowances  = []
  }
}


# -----------------------------------------
# Create a JWT role and policy per backend.
# -----------------------------------------

module "repo_policy_and_jwt_role" {
  source          = "app.terraform.io/bankofnovascotia/policy/vault"
  version         = ">= 0.0.1, < 1.0.0"
  auth_path       = var.wif.hve.auth_path
  bound_audiences = ["vault.workload.identity", "https://github.com/${var.organization}"]
  bound_claims = {
    repository = github_repository.ghe_repo.full_name
  }
  path = {
    svc = ["ghec"],
    org = [var.organization],
    epm = [var.workload_id],
    env = ["prd", "noenv"],
    obj = [github_repository.ghe_repo.name],
    ctx = ["all"]
  }
  policy_name = "c1/ghec/repo-${github_repository.ghe_repo.name}"
  role_name   = github_repository.ghe_repo.name
  user_claim  = "iss"
  depends_on  = [github_repository.ghe_repo]
}


# ------------------------------------------------------------------------------------------
# Create the required Actions Variables as per the following:
#   https://github.com/hashicorp/vault-action?tab=readme-ov-file#jwt-with-github-oidc-tokens
# ------------------------------------------------------------------------------------------

resource "github_actions_variable" "vault_url" {
  repository    = github_repository.ghe_repo.name
  variable_name = "VAULT_URL"
  value         = var.wif.hve.address
  depends_on    = [github_repository.ghe_repo]
}

resource "github_actions_variable" "vault_role" {
  repository    = github_repository.ghe_repo.name
  variable_name = "VAULT_ROLE"
  value         = module.repo_policy_and_jwt_role.jwt_role.role_name
  depends_on    = [github_repository.ghe_repo]
}


# --------------------------------------------------------------------------------
# Enable access to Google Cloud services via Workload Identity Federation as per:
#   https://github.com/google-github-actions/auth?tab=readme-ov-file#indirect-wif
# --------------------------------------------------------------------------------

locals {
  wif = var.wif.gcp != null ? var.wif.gcp : {}
}

# Configure the required Actions environment variables for WIF enablement.
resource "github_actions_variable" "wif_gcp_pool_name" {
  for_each      = { for k, v in local.wif : k => v if !(v.project_number == "" || v.pool_id == "") }
  repository    = github_repository.ghe_repo.name
  variable_name = "GCP_WIF_POOL_FULL_NAME_${upper(each.key)}"
  value         = "projects/${each.value.project_number}/locations/global/workloadIdentityPools/${each.value.pool_id}"
  depends_on    = [github_repository.ghe_repo]
}

# Configure the required Actions environment varialbes for WIF enablement using SA impersonation.
resource "github_actions_variable" "wif_gcp_sa" {
  for_each      = { for k, v in local.wif : k => v if !(v.service_account == "") }
  repository    = github_repository.ghe_repo.name
  variable_name = "GCP_SERVICE_ACCOUNT_${upper(each.key)}"
  value         = each.value.service_account
  depends_on    = [github_repository.ghe_repo]
}

