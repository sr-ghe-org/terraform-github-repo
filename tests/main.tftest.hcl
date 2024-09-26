
mock_provider "github" {}
mock_provider "vault" {}
mock_provider "google" {}
mock_provider "google-beta" {}

# dummy values which are provided by the context
variables {
  repository_description = "A sample repo that will never exist."
  repository_name        = "pso-test-repo"
  repository_topics      = [ "test", "does-not-exist" ]
  repository_type        = {
    template_name      = "twf-sample-template",
    template_owner     = "fakeorg"
    gitignore_template = "Terraform"
    license_template   = "None"
  }
  team_id                = "test_team_id" 
  wif         = {
    gcp = {
      test_one = {
        service_account = "projects/dummypr/serviceAccounts/prsdfsdf@dummysa.iam.gserviceaccount.com"
        project_number  = "prblah"
        pool_id         = "prtestpool"
        provider_id     = "prtestprovider"
      },
      test_two = {
        service_account = "projects/dummynp/serviceAccounts/npsdfsdf@dummysa.iam.gserviceaccount.com"
        project_number  = "npblah"
        pool_id         = "nptestpool"
        provider_id     = "nptestprovider"
      }
    },
    hve = {
      address           = "blah.bloo.blee"
      auth_path         = "/foo/fee/fum"
    }
  }
  workload_id           = "abcd"
}

# ensure that the repository is private.
run "is_repo_private" {
  assert {
    condition     = output.repository.visibility == "private"
    error_message = "The expectation is a private repository."
  }
}

# ensure that the repository is private.
run "is_git_ignore_correct" {
  assert {
    condition     = output.repository.gitignore_template == var.repository_type.gitignore_template
    error_message = "The expectation is the gitignore template matches what was provided."
  }
}

# ensure that the repository is private.
run "is_license_correct" {
  assert {
    condition     = output.repository.license_template == var.repository_type.license_template
    error_message = "The expectation is the license template matches what was provided."
  }
}

# ensure it was created using the requested template
run "is_repo_using_the_right_template" {
  assert {
    condition     = output.repository.template[0].include_all_branches == false && output.repository.template[0].owner == var.repository_type.template_owner  && output.repository.template[0].repository == var.repository_type.template_name
    error_message = "The expectation is the 'twf-sample-template' from the 'fakeorg'."
  }
}

# ensure that the only branch on the repository is the main branch.
run "is_repo_using_main" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main"
    error_message = "The expectation is a single 'main' branch."
  }
}

# ensure that you cannot delete the main branch.
run "ensure_branch_cannot_be_deleted" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main" && output.branch_protection.pattern == "main" && output.branch_protection.allows_deletions == false
    error_message = "The expectation is that branch protections are enabled and you are not allowed to delete the main branch."
  }
}

# ensure that all contributions to the main branch need to come from a pull request.
run "ensure_no_force_push" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main" && output.branch_protection.pattern == "main" && output.branch_protection.allows_force_pushes == false && length(output.branch_protection.restrict_pushes[0].push_allowances) < 1 && length(output.branch_protection.force_push_bypassers) < 1
    error_message = "The expectation is that branch protections are enabled and you are not allowed to delete the main branch."
  }
}

# ensure that no one is able to bypass the pull request control.
run "ensure_pull_request_only" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main" && output.branch_protection.pattern == "main" && length(output.branch_protection.required_pull_request_reviews[0].pull_request_bypassers) < 1
    error_message = "The expectation is that no individual is allow to bypass the pull request control."
  }
}

# ensure that all pull requests must be approved by a Code Owner.
run "ensure_pull_request_code_owner_approval" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main" && output.branch_protection.pattern == "main" && output.branch_protection.required_pull_request_reviews[0].require_code_owner_reviews == true
    error_message = "The expectation is that no individual is allow to bypass the pull request control."
  }
}

# ensure that all pull requests must have at least human 2 approvals.
run "ensure_pull_request_conspiracy_of_three" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main" && output.branch_protection.pattern == "main" && output.branch_protection.required_pull_request_reviews[0].required_approving_review_count == 2
    error_message = "The expectation is that no individual is allow to bypass the pull request control."
  }
}

# ensure that all pull requests must pass automated validation.
run "ensure_pull_request_needs_robot_validation" {
  assert {
    condition     = output.repository.name == output.branch.repository && output.branch.branch == "main" && output.branch_protection.pattern == "main" && length(output.branch_protection.required_status_checks) > 0 && output.branch_protection.required_status_checks[0].strict == true
    error_message = "The expectation is that strict status checks are required"
  }
}

# ensure that all pull requests must pass automated validation.
run "ensure_environment_variables_are_made" {
  assert {
    condition     = length(keys(github_actions_variable.wif_gcp_pool_name)) == 2
    error_message = "The expectation is that 2 environment variables for the pool name got created."
  }
}

