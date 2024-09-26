# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2

variable "organization" {
  description = "The Github Enterprise organization"
  type        = string
  nullable    = false
  default     = "sr-ghe-org"
}

variable "repository_description" {
  description = "A description of the repository."
  type        = string
  nullable    = false
}

variable "repository_type" {
  description = "The repository classification"
  type        = object({
    template_owner     = string
    template_name      = string
    gitignore_template = string
    license_template   = string
  })
  nullable = false
}

variable "repository_name" {
  description = "The name of the seed control repository."
  type        = string
  nullable    = false
}

variable "repository_topics" {
  description = "The topics to apply to the repository."
  type        = list
  nullable    = false
}

variable "team_id" {
  description = "The identifier of the Github Team to which this repository belongs."
  type        = string
  nullable    = false
}

variable "wif" {
  description = "The ensures project creation at the service tier with bindings to the appropriate WIF pool per service."
  type = object({
    gcp = map(object({
      service_account = string
      sa_project_id   = string
      project_number  = string
      pool_id         = string
      provider_id     = string
    })),
    # hve = object({
    #   address           = string
    #   auth_path         = string
    #   namespace         = string
    # })
  })
  nullable = false
}

variable "workload_id" {
  description = "The Application Portfolio Management (APM) Code for the workload."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z][a-z][a-z]$", var.workload_id))
    error_message = "The APM code is expected to be a 4 alphabetic (lower-case) character string."
  }
} 
