resource "google_compute_region_network_endpoint_group" "api" {
  count                 = var.enable_custom_domain ? 1 : 0
  name                  = "convocoach-api"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.api.name
  }
}

resource "google_compute_backend_service" "api" {
  count                 = var.enable_custom_domain ? 1 : 0
  name                  = "convocoach-api"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 60
  enable_cdn            = false

  backend {
    group = google_compute_region_network_endpoint_group.api[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "api" {
  count           = var.enable_custom_domain ? 1 : 0
  name            = "convocoach-api"
  default_service = google_compute_backend_service.api[0].id
}

resource "google_compute_managed_ssl_certificate" "api" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "convocoach-api"
  managed {
    domains = [var.api_domain]
  }
}

resource "google_compute_target_https_proxy" "api" {
  count            = var.enable_custom_domain ? 1 : 0
  name             = "convocoach-api"
  url_map          = google_compute_url_map.api[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.api[0].id]
}

resource "google_compute_global_address" "api" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "convocoach-api"
}

resource "google_compute_global_forwarding_rule" "api_https" {
  count                 = var.enable_custom_domain ? 1 : 0
  name                  = "convocoach-api-https"
  ip_address            = google_compute_global_address.api[0].id
  port_range            = "443"
  target                = google_compute_target_https_proxy.api[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
