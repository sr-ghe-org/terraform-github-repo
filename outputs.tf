/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# All repository object details
output "repository" {
  description = "All repository output attributes"
  value       = github_repository.ghe_repo
}

# The team details
# output "team" {
#   description = "The team and entitlements for the reposoitory"
#   value       = github_team_repository.repo
# }

# The branch configuration
output "branch" {
  description = "The branch configuration for the repository."
  value       = github_branch.ghe_branch
}

# The branch protection configuration
output "branch_protection" {
  description = "The branch protection configuration for the repository."
  value       = github_branch_protection.main_branch_protection
}

