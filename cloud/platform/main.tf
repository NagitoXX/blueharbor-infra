terraform {
  required_providers {
    vercel = {
      source = "vercel/vercel"
    }
  }
}

provider "vercel" {} # reads VERCEL_API_TOKEN

variable "github_repo" {
  type        = string
  description = "owner/name of the repository, for example jdoe/blueharbor-infra"
}

variable "initials" {
  type = string
}

resource "vercel_project" "trackit" {
  name           = "bh-trackit-${var.initials}"
  root_directory = "trackit"
  git_repository = {
    type              = "github"
    repo              = var.github_repo
    production_branch = "main"
  }
}

resource "vercel_project_environment_variable" "version" {
  project_id = vercel_project.trackit.id
  key        = "APP_VERSION"
  value      = "1.1.0"
  target     = ["production", "preview"]
  sensitive  = false
}

output "project_id" {
  value = vercel_project.trackit.id
}
