output "artifact_repository" {
  value = google_artifact_registry_repository.backend.name
}

output "cloud_run_service_uri" {
  value = google_cloud_run_v2_service.api.uri
}

output "api_load_balancer_ip" {
  description = "Create an A record for api_domain when the optional custom-domain load balancer is enabled."
  value       = var.enable_custom_domain ? google_compute_global_address.api[0].address : null
}

output "public_api_base_url" {
  description = "Public HTTPS base URL used by the mobile production configuration."
  value       = local.api_base_url
}

output "cloud_sql_instance_connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}

output "cloud_sql_private_ip" {
  value     = google_sql_database_instance.postgres.private_ip_address
  sensitive = true
}

output "redis_host" {
  value     = google_redis_instance.cache.host
  sensitive = true
}

output "redis_tls_port" {
  value = google_redis_instance.cache.port
}

output "play_rtdn_topic" {
  value = var.store_billing_enabled ? google_pubsub_topic.play_rtdn.id : null
}

output "play_api_service_account" {
  value = google_service_account.api.email
}

output "play_push_service_account" {
  value = google_service_account.play_push.email
}
