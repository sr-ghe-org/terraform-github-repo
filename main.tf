


# -------------------------
# Repository Configuration.
# -------------------------

resource "github_repository" "ghe_repo" {
  name                   = var.repository_name
  description            = var.repository_description
  visibility             = "public"
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

# module "repo_policy_and_jwt_role" {
#   source          = "../terraform-vault-policy"
#   auth_path       = var.wif.hve.auth_path
#   bound_audiences = ["vault.workload.identity", "https://github.com/${var.organization}"]
#   bound_claims    = {
#     repository = github_repository.ghe_repo.full_name
#   }
#   path = {
#       svc = [ "ghec" ],
#       org = [ var.organization ],
#       epm = [ var.workload_id ],
#       env = [ "prd", "noenv" ],
#       obj = [ github_repository.ghe_repo.name ],
#       ctx = [ "all" ]
#     }
#   policy_name     = "c1/ghec/repo-${github_repository.ghe_repo.name}"
#   role_name       = github_repository.ghe_repo.name
#   user_claim      = "iss"
#   depends_on      = [ github_repository.ghe_repo ]
# }


# ------------------------------------------------------------------------------------------
# Create the required Actions Variables as per the following:
#   https://github.com/hashicorp/vault-action?tab=readme-ov-file#jwt-with-github-oidc-tokens
# ------------------------------------------------------------------------------------------

# resource "github_actions_variable" "vault_url" {
#   # repository       = var.repository_name
#   repository       = github_repository.ghe_repo.name
#   variable_name    = "VAULT_URL"
#   value            = var.wif.hve.address
# }

# resource "github_actions_variable" "vault_role" {
#   repository       = var.repository_name
#   variable_name    = "VAULT_ROLE"
#   value            = module.repo_policy_and_jwt_role.jwt_role.role_name
# }


# ------------------------------------------------------------------------
# Enable access to Google Cloud services via Workload Identity Federation.
# ------------------------------------------------------------------------

# Create the entry in the WIF provider allowing the repository to impersonate the service account.
resource "google_service_account_iam_member" "ghe_wif_iam" {
  for_each           = var.wif.gcp
  # service_account_id = each.value.service_account
  service_account_id = "projects/${each.value.sa_project_id}/serviceAccounts/${each.value.service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${each.value.project_number}/locations/global/workloadIdentityPools/${each.value.pool_id}/subject/github::${github_repository.ghe_repo.full_name}::refs/heads/main"
}

# Configure the required Actions environment variables for WIF enablement.
resource "github_actions_variable" "wif_gcp_pool_name" {
  for_each         = var.wif.gcp
  # repository       = var.repository_name
  repository       = github_repository.ghe_repo.name
  variable_name    = "GCP_WIF_POOL_FULL_NAME_${upper(each.key)}"
  value            = "projects/${each.value.project_number}/locations/global/workloadIdentityPools/${each.value.pool_id}"
}

# Configure the required Actions environment varialbes for WIF enablement using SA impersonation.
resource "github_actions_variable" "wif_gcp_sa" {
  for_each         = var.wif.gcp
  # repository       = var.repository_name
  repository       = github_repository.ghe_repo.name
  variable_name    = "GCP_SERVICE_ACCOUNT_${upper(each.key)}"
  value            = each.value.service_account
}

