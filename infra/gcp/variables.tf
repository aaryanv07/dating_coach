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
  description = "Verified HTTPS API hostname, without scheme or path."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$", var.api_domain))
    error_message = "api_domain must be a lowercase DNS hostname."
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
  description = "Warm API instances. Set to one for controlled launch."
  type        = number
  default     = 1
}

variable "maximum_instances" {
  description = "Hard spend and connection ceiling for API autoscaling."
  type        = number
  default     = 5
}
