locals {
  service_accounts = {
    "a0-backend-sa" = {
      display_name = "Agent Zero Backend SA"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/artifactregistry.reader",
      ]
    }
  }
}

resource "google_service_account" "service_accounts" {
  for_each = local.service_accounts

  project      = local.gc_project_id
  account_id   = each.key
  display_name = each.value.display_name
}

module "service_accounts_iam" {
  for_each = local.service_accounts

  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8.2"

  projects = [local.gc_project_id]

  bindings = {
    for role in each.value.roles :
    role => ["serviceAccount:${google_service_account.service_accounts[each.key].email}"]
  }
}
