terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

# Valor de demostración. El endpoint lo devuelve y este repo se publica.
# Descartado random_password: una contraseña generada acabaría en el tfstate y en la respuesta.
locals {
  mongo_root_password = "poc-placeholder"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "eso" {
  account_id   = "poc-eso"
  display_name = "POC External Secrets"
  depends_on   = [google_project_service.apis]
}

resource "google_container_cluster" "poc" {
  name                     = "poc-secretos"
  location                 = var.zone
  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 1
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  depends_on = [google_project_service.apis]
}

resource "google_container_node_pool" "poc" {
  name       = "poc"
  location   = var.zone
  cluster    = google_container_cluster.poc.name
  node_count = 1
  node_config {
    machine_type = "e2-standard-2"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_service_account_iam_member" "wi" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

resource "google_secret_manager_secret" "poc" {
  secret_id = "poc-secrets"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "poc" {
  secret = google_secret_manager_secret.poc.id
  secret_data = jsonencode({
    "mongo-root-password"     = local.mongo_root_password
    "mongo-connection-string" = "mongodb://root:${local.mongo_root_password}@mongodb.demo.svc.cluster.local:27017/demo?authSource=admin"
    "etiqueta"                = "version-1"
    "banner"                  = "hola desde el archivo"
  })
}

resource "google_secret_manager_secret_iam_member" "lector" {
  secret_id = google_secret_manager_secret.poc.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.eso.email}"
}

resource "google_artifact_registry_repository" "poc" {
  location      = var.region
  repository_id = "poc-secretos"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

output "project_id" {
  value = var.project_id
}

output "zone" {
  value = var.zone
}

output "region" {
  value = var.region
}

output "cluster_name" {
  value = google_container_cluster.poc.name
}

output "eso_gsa" {
  value = google_service_account.eso.email
}

output "image" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/poc-secretos/poc:1"
}
