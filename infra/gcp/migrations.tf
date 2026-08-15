resource "google_cloud_run_v2_job" "migrations" {
  name                = "convocoach-migrations"
  location            = var.region
  deletion_protection = true

  template {
    template {
      service_account = google_service_account.api.email
      timeout         = "600s"
      max_retries     = 0

      vpc_access {
        network_interfaces {
          network    = google_compute_network.production.name
          subnetwork = google_compute_subnetwork.production.name
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.postgres.connection_name]
        }
      }

      containers {
        image   = var.backend_image
        command = ["python", "-m", "alembic"]
        args    = ["upgrade", "head"]

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }

        env {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.runtime["database-url"].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.runtime_access,
    google_secret_manager_secret_version.database_url,
  ]
}
