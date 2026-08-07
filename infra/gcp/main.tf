locals {
  service_name = "convocoach-api"
  required_apis = toset([
    "androidpublisher.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "redis.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
  ])
  runtime_secrets = toset([
    "database-url",
    "redis-url",
    "redis-ca-certificate",
    "store-transaction-hash-secret",
    "openrouter-api-key",
    "openrouter-user-identifier-secret",
    "zai-api-key",
    "zai-user-identifier-secret",
  ])
}

resource "google_project_service" "required" {
  for_each           = local.required_apis
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "api" {
  account_id   = "convocoach-api"
  display_name = "ConvoCoach production API"
  depends_on   = [google_project_service.required]
}

resource "google_service_account" "play_push" {
  account_id   = "convocoach-play-push"
  display_name = "Authenticated Google Play RTDN push"
  depends_on   = [google_project_service.required]
}

resource "google_artifact_registry_repository" "backend" {
  location      = var.region
  repository_id = "convocoach-backend"
  format        = "DOCKER"
  description   = "Digest-pinned ConvoCoach backend images"
  depends_on    = [google_project_service.required]
}

resource "google_compute_network" "production" {
  name                    = "convocoach-production"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}

resource "google_compute_subnetwork" "production" {
  name                     = "convocoach-production-${var.region}"
  ip_cidr_range            = "10.20.0.0/24"
  region                   = var.region
  network                  = google_compute_network.production.id
  private_ip_google_access = true
}

resource "google_vpc_access_connector" "run" {
  name          = "convocoach-run"
  region        = var.region
  network       = google_compute_network.production.name
  ip_cidr_range = "10.20.1.0/28"
  min_instances = 2
  max_instances = 3
}

resource "google_compute_global_address" "private_services" {
  name          = "convocoach-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.production.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.production.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
  depends_on              = [google_project_service.required]
}

resource "google_sql_database_instance" "postgres" {
  name                = "convocoach-production"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = true

  settings {
    tier              = "db-custom-2-7680"
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = 20
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "20:00"
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.production.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    maintenance_window {
      day          = 7
      hour         = 21
      update_track = "stable"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "application" {
  name     = "convocoach"
  instance = google_sql_database_instance.postgres.name
}

resource "random_password" "database" {
  length           = 40
  special          = true
  override_special = "-._~"
}

resource "google_sql_user" "application" {
  name     = "convocoach_app"
  instance = google_sql_database_instance.postgres.name
  password = random_password.database.result
}

resource "google_redis_instance" "cache" {
  name                    = "convocoach-production"
  region                  = var.region
  tier                    = "STANDARD_HA"
  memory_size_gb          = 1
  redis_version           = "REDIS_7_2"
  authorized_network      = google_compute_network.production.id
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  redis_configs = {
    "maxmemory-policy" = "allkeys-lru"
  }
  depends_on = [google_service_networking_connection.private_services]
}

resource "google_secret_manager_secret" "runtime" {
  for_each  = local.runtime_secrets
  secret_id = "convocoach-${each.value}"
  replication {
    auto {}
  }
  depends_on = [google_project_service.required]
}

resource "random_password" "store_transaction_hash" {
  length  = 64
  special = false
}

resource "random_password" "zai_user_identifier" {
  length  = 64
  special = false
}

resource "random_password" "openrouter_user_identifier" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.runtime["database-url"].id
  secret_data = format(
    "postgresql+asyncpg://convocoach_app:%s@/convocoach?host=%s",
    urlencode(random_password.database.result),
    urlencode("/cloudsql/${google_sql_database_instance.postgres.connection_name}"),
  )
  deletion_policy = "DISABLE"
  depends_on      = [google_sql_user.application]
}

resource "google_secret_manager_secret_version" "redis_url" {
  secret = google_secret_manager_secret.runtime["redis-url"].id
  secret_data = format(
    "rediss://default:%s@%s:%s/0",
    urlencode(google_redis_instance.cache.auth_string),
    google_redis_instance.cache.host,
    google_redis_instance.cache.port,
  )
  deletion_policy = "DISABLE"
}

resource "google_secret_manager_secret_version" "redis_ca_certificate" {
  secret          = google_secret_manager_secret.runtime["redis-ca-certificate"].id
  secret_data     = google_redis_instance.cache.server_ca_certs[0].cert
  deletion_policy = "DISABLE"
}

resource "google_secret_manager_secret_version" "store_transaction_hash" {
  secret          = google_secret_manager_secret.runtime["store-transaction-hash-secret"].id
  secret_data     = random_password.store_transaction_hash.result
  deletion_policy = "DISABLE"
}

resource "google_secret_manager_secret_version" "zai_user_identifier" {
  secret          = google_secret_manager_secret.runtime["zai-user-identifier-secret"].id
  secret_data     = random_password.zai_user_identifier.result
  deletion_policy = "DISABLE"
}

resource "google_secret_manager_secret_version" "openrouter_user_identifier" {
  secret          = google_secret_manager_secret.runtime["openrouter-user-identifier-secret"].id
  secret_data     = random_password.openrouter_user_identifier.result
  deletion_policy = "DISABLE"
}

resource "google_secret_manager_secret_iam_member" "runtime_access" {
  for_each  = local.runtime_secrets
  secret_id = google_secret_manager_secret.runtime[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_project_iam_member" "api_cloud_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_project_iam_member" "api_android_publisher" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_pubsub_topic" "play_rtdn" {
  name       = "convocoach-play-rtdn"
  depends_on = [google_project_service.required]
}

resource "google_pubsub_topic_iam_member" "google_play_publisher" {
  topic  = google_pubsub_topic.play_rtdn.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:google-play-developer-notifications@system.gserviceaccount.com"
}

resource "google_cloud_run_v2_service" "api" {
  name                = local.service_name
  location            = var.region
  deletion_protection = true
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account                  = google_service_account.api.email
    timeout                          = "60s"
    max_instance_request_concurrency = 40

    scaling {
      min_instance_count = var.minimum_instances
      max_instance_count = var.maximum_instances
    }

    vpc_access {
      connector = google_vpc_access_connector.run.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    volumes {
      name = "redis-ca"
      secret {
        secret = google_secret_manager_secret.runtime["redis-ca-certificate"].secret_id
        items {
          version = "latest"
          path    = "server-ca.pem"
          mode    = 292
        }
      }
    }

    containers {
      image = var.backend_image

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
        cpu_idle = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      volume_mounts {
        name       = "redis-ca"
        mount_path = "/etc/convocoach/redis-ca"
      }

      startup_probe {
        failure_threshold     = 12
        initial_delay_seconds = 5
        period_seconds        = 5
        timeout_seconds       = 3
        http_get {
          path = "/health/live"
          http_headers {
            name  = "Host"
            value = var.api_domain
          }
        }
      }

      liveness_probe {
        failure_threshold = 3
        period_seconds    = 30
        timeout_seconds   = 3
        http_get {
          path = "/health/live"
          http_headers {
            name  = "Host"
            value = var.api_domain
          }
        }
      }

      dynamic "env" {
        for_each = {
          APP_NAME                                        = "ConvoCoach API"
          APP_ENVIRONMENT                                 = "production"
          APP_DEBUG                                       = "false"
          APP_LOG_LEVEL                                   = "INFO"
          OPENAPI_ENABLED                                 = "false"
          OPERATIONAL_CHECKS_ENABLED                      = "true"
          REDIS_CA_CERTIFICATE_PATH                       = "/etc/convocoach/redis-ca/server-ca.pem"
          MAX_REQUEST_BODY_BYTES                          = "1048576"
          ALLOWED_HOSTS                                   = var.api_domain
          DEVELOPMENT_AUTH_TOKEN                          = ""
          DEVELOPMENT_AUTH_SUBJECT                        = ""
          DEVELOPMENT_AUTH_EMAIL                          = ""
          AUTHENTICATION_VERIFIER_MODE                    = "production_contract"
          AUTHENTICATION_ISSUER                           = var.authentication_issuer
          AUTHENTICATION_AUDIENCE                         = var.authentication_audience
          AUTHENTICATION_JWKS_URL                         = var.authentication_jwks_url
          AUTHENTICATION_ALLOWED_ALGORITHMS               = "ES256,RS256"
          AUTHENTICATION_CLOCK_SKEW_SECONDS               = "60"
          AUTHENTICATION_MAXIMUM_TOKEN_LIFETIME_SECONDS   = "3600"
          AI_COACHING_ENABLED                             = tostring(var.ai_coaching_enabled)
          AI_MOCK_EXECUTION_ENABLED                       = "false"
          AI_PROVIDER_MODE                                = "openrouter_tiered"
          AI_EXTERNAL_PROCESSING_APPROVED                 = tostring(var.external_ai_processing_approved)
          AI_SAFETY_EVALUATION_APPROVED                   = tostring(var.ai_safety_evaluation_approved)
          AI_USAGE_ENFORCEMENT_ENABLED                    = "true"
          AI_NEW_REQUESTS_PER_MINUTE                      = "5"
          AI_RESERVATION_COST_MICROUSD                    = "100000"
          AI_USER_MONTHLY_BUDGET_MICROUSD                 = "2000000"
          AI_GLOBAL_MONTHLY_BUDGET_MICROUSD               = "100000000"
          AI_BUDGET_ALERT_PERCENT                         = "80"
          OPENROUTER_FREE_MODEL                           = "openai/gpt-4o-mini"
          OPENROUTER_PAID_MODEL                           = "openai/gpt-5.6-terra"
          OPENROUTER_FREE_REASONING_EFFORT                = "none"
          OPENROUTER_PAID_REASONING_EFFORT                = "medium"
          OPENROUTER_REQUEST_TIMEOUT_SECONDS              = "30"
          OPENROUTER_FREE_INPUT_PRICE_MICROUSD_PER_MILLION_TOKENS  = "150000"
          OPENROUTER_FREE_OUTPUT_PRICE_MICROUSD_PER_MILLION_TOKENS = "600000"
          OPENROUTER_PAID_INPUT_PRICE_MICROUSD_PER_MILLION_TOKENS  = "1000000"
          OPENROUTER_PAID_OUTPUT_PRICE_MICROUSD_PER_MILLION_TOKENS = "6000000"
          STORE_BILLING_ENABLED                           = "true"
          STORE_VERIFICATION_TIMEOUT_SECONDS              = "15"
          APPLE_IAP_BUNDLE_ID                             = "com.convocoach.convoCoach"
          APPLE_IAP_APP_ID                                = tostring(var.apple_app_store_id)
          APPLE_IAP_ENVIRONMENT                           = "production"
          APPLE_IAP_PRODUCT_IDS                           = join(",", var.apple_product_ids)
          GOOGLE_PLAY_PACKAGE_NAME                        = "com.convocoach.convo_coach"
          GOOGLE_PLAY_PRODUCT_IDS                         = join(",", var.google_product_ids)
          GOOGLE_PLAY_USE_APPLICATION_DEFAULT_CREDENTIALS = "true"
          GOOGLE_PLAY_SERVICE_ACCOUNT_JSON                = ""
          GOOGLE_PLAY_PUBSUB_AUDIENCE                     = "https://${var.api_domain}/api/v1/subscription/notifications/google"
          GOOGLE_PLAY_PUBSUB_SERVICE_ACCOUNT              = google_service_account.play_push.email
        }
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = {
          DATABASE_URL                  = "database-url"
          REDIS_URL                     = "redis-url"
          STORE_TRANSACTION_HASH_SECRET = "store-transaction-hash-secret"
          OPENROUTER_API_KEY             = "openrouter-api-key"
          OPENROUTER_USER_IDENTIFIER_SECRET = "openrouter-user-identifier-secret"
        }
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.runtime[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.required,
    google_secret_manager_secret_iam_member.runtime_access,
    google_sql_database.application,
    google_redis_instance.cache,
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_version.redis_url,
    google_secret_manager_secret_version.redis_ca_certificate,
    google_secret_manager_secret_version.store_transaction_hash,
    google_secret_manager_secret_version.openrouter_user_identifier,
    google_secret_manager_secret_version.zai_user_identifier,
  ]

  lifecycle {
    precondition {
      condition = !var.ai_coaching_enabled || (
        var.external_ai_processing_approved && var.ai_safety_evaluation_approved
      )
      error_message = "Hosted AI cannot be enabled before both external-processing and independent safety approvals are recorded."
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_api" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_project_iam_member" "pubsub_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "play_push_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.play_push.email}"
}

resource "google_pubsub_subscription" "play_push" {
  name  = "convocoach-play-rtdn-push"
  topic = google_pubsub_topic.play_rtdn.name

  ack_deadline_seconds       = 30
  message_retention_duration = "604800s"
  retain_acked_messages      = false

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  expiration_policy {
    ttl = "2678400s"
  }

  push_config {
    push_endpoint = "https://${var.api_domain}/api/v1/subscription/notifications/google"
    oidc_token {
      service_account_email = google_service_account.play_push.email
      audience              = "https://${var.api_domain}/api/v1/subscription/notifications/google"
    }
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.play_push_invoker,
    google_project_iam_member.pubsub_token_creator,
  ]
}

data "google_project" "current" {
  project_id = var.project_id
}
