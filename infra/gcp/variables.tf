variable "project_id" {
  description = "Dedicated Google Cloud production project."
  type        = string
}

variable "region" {
  description = "Primary region for the controlled launch."
  type        = string
  default     = "asia-south1"
}

variable "api_domain" {
  description = "Optional verified HTTPS API hostname, without scheme or path."
  type        = string
  default     = ""

  validation {
    condition = var.api_domain == "" || can(
      regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$", var.api_domain)
    )
    error_message = "api_domain must be empty or a lowercase DNS hostname."
  }
}

variable "enable_custom_domain" {
  description = "Create a global HTTPS load balancer for api_domain. Keep false for the lowest-cost run.app launch."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_custom_domain || var.api_domain != ""
    error_message = "api_domain is required when enable_custom_domain is true."
  }
}

variable "backend_image" {
  description = "Immutable backend image reference including an sha256 digest."
  type        = string

  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.backend_image))
    error_message = "backend_image must be pinned to an sha256 digest."
  }
}

variable "authentication_issuer" {
  description = "Exact HTTPS issuer exposed by the production OIDC tenant."
  type        = string
}

variable "authentication_audience" {
  description = "OIDC API audience."
  type        = string
  default     = "convocoach-api"
}

variable "authentication_jwks_url" {
  description = "Exact HTTPS JWKS URL for the production OIDC tenant."
  type        = string
}

variable "apple_app_store_id" {
  description = "Numeric App Store Connect app identifier."
  type        = number
  default     = 0
}

variable "store_billing_enabled" {
  description = "Enable store verification and Play notification resources only after products are configured."
  type        = bool
  default     = false

  validation {
    condition     = !var.store_billing_enabled || var.apple_app_store_id > 0
    error_message = "apple_app_store_id is required when store billing is enabled."
  }
}

variable "database_tier" {
  description = "Cloud SQL tier. One dedicated core is the controlled-launch production floor."
  type        = string
  default     = "db-custom-1-3840"
}

variable "database_availability_type" {
  description = "ZONAL for the cost-controlled launch; upgrade to REGIONAL after traffic justifies HA."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.database_availability_type)
    error_message = "database_availability_type must be ZONAL or REGIONAL."
  }
}

variable "database_disk_size_gb" {
  description = "Initial autoscaling PostgreSQL SSD capacity."
  type        = number
  default     = 10

  validation {
    condition     = var.database_disk_size_gb >= 10
    error_message = "database_disk_size_gb must be at least 10."
  }
}

variable "redis_tier" {
  description = "BASIC for disposable controlled-launch cache; upgrade to STANDARD_HA when needed."
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.redis_tier)
    error_message = "redis_tier must be BASIC or STANDARD_HA."
  }
}

variable "apple_product_ids" {
  description = "Monthly then yearly auto-renewable subscription product IDs."
  type        = list(string)
  default = [
    "com.convocoach.plus.monthly",
    "com.convocoach.plus.yearly",
  ]

  validation {
    condition     = length(var.apple_product_ids) == 2 && length(toset(var.apple_product_ids)) == 2
    error_message = "Exactly two unique Apple product IDs are required."
  }
}

variable "google_product_ids" {
  description = "Monthly then yearly subscription product IDs."
  type        = list(string)
  default = [
    "com.convocoach.plus.monthly",
    "com.convocoach.plus.yearly",
  ]

  validation {
    condition     = length(var.google_product_ids) == 2 && length(toset(var.google_product_ids)) == 2
    error_message = "Exactly two unique Google product IDs are required."
  }
}

variable "alert_email" {
  description = "Monitored production incident mailbox."
  type        = string
}

variable "ai_coaching_enabled" {
  description = "Enable hosted AI only after external-processing and safety approvals pass."
  type        = bool
  default     = false
}

variable "external_ai_processing_approved" {
  description = "Authorized privacy/processor approval; never set from automated tests."
  type        = bool
  default     = false
}

variable "ai_safety_evaluation_approved" {
  description = "Independent production AI safety approval; never self-attested."
  type        = bool
  default     = false
}

variable "minimum_instances" {
  description = "Warm API instances. Keep zero for request-based scale-to-zero billing."
  type        = number
  default     = 0
}

variable "maximum_instances" {
  description = "Hard spend and connection ceiling for API autoscaling."
  type        = number
  default     = 3
}
