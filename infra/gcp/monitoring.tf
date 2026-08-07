resource "google_monitoring_notification_channel" "email" {
  display_name = "ConvoCoach production incidents"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
  force_delete = false
}

resource "google_monitoring_uptime_check_config" "readiness" {
  display_name     = "ConvoCoach API readiness"
  timeout          = "10s"
  period           = "60s"
  selected_regions = ["ASIA_PACIFIC", "USA", "EUROPE"]

  http_check {
    path           = "/health/ready"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host       = var.api_domain
      project_id = var.project_id
    }
  }
}

resource "google_monitoring_alert_policy" "readiness" {
  display_name          = "ConvoCoach API unavailable"
  combiner              = "OR"
  severity              = "CRITICAL"
  notification_channels = [google_monitoring_notification_channel.email.name]

  conditions {
    display_name = "Readiness failed for five minutes"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.readiness.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "300s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_TRUE"
        group_by_fields      = ["resource.label.host"]
      }
      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Run the production incident procedure in docs/Operations-Runbook.md. Do not include request bodies or user content in incident channels."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "server_errors" {
  display_name          = "ConvoCoach elevated API 5xx rate"
  combiner              = "OR"
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.email.name]

  conditions {
    display_name = "Five or more 5xx responses in five minutes"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"convocoach-api\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.label.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  documentation {
    content   = "Check only correlation IDs, status codes, provider-safe error codes, and aggregate dependency health. Never copy private conversation content into logs or tickets."
    mime_type = "text/markdown"
  }
}
