"""Environment-backed application settings."""

import re
from dataclasses import dataclass, field
from functools import lru_cache
from os import getenv
from typing import Literal
from urllib.parse import parse_qs, urlsplit

DEFAULT_DATABASE_URL = (
    "postgresql+asyncpg://convocoach:convocoach_local_only@127.0.0.1:5432/convocoach"
)
DEFAULT_REDIS_URL = "redis://127.0.0.1:6379/0"
_BOOLEAN_TRUE = frozenset({"1", "true", "yes", "on"})
_BOOLEAN_FALSE = frozenset({"0", "false", "no", "off"})
_ENVIRONMENTS = frozenset({"local", "test", "staging", "production"})
_LOG_LEVELS = frozenset({"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"})
_AUTHENTICATION_VERIFIER_MODES = frozenset({"development", "production_contract"})
_AUTHENTICATION_ALGORITHMS = frozenset({"ES256", "RS256"})
_AI_PROVIDER_MODES = frozenset({"mock", "openai_terra", "zai_glm", "openrouter_tiered"})
_OPENROUTER_REASONING_EFFORTS = frozenset({"none", "minimal", "low", "medium", "high", "max"})
_STORE_ENVIRONMENTS = frozenset({"sandbox", "production"})
OPENAI_TERRA_MODEL: Literal["gpt-5.6-terra"] = "gpt-5.6-terra"
ZAI_GLM_MODEL: Literal["glm-5.2"] = "glm-5.2"
ZAI_GLM_BASE_URL = "https://api.z.ai/api/paas/v4/"
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1/"
OPENROUTER_FREE_MODEL = "openai/gpt-4o-mini"
OPENROUTER_PAID_MODEL = "openai/gpt-5.6-terra"
_OPENROUTER_MODEL_PATTERN = re.compile(r"^[A-Za-z0-9._~:-]+/[A-Za-z0-9._~:-]+$")
_LOCAL_HOSTS = frozenset({"127.0.0.1", "::1", "localhost", "testserver"})
_MAX_REQUEST_BODY_LIMIT = 10 * 1024 * 1024
_MAX_AUTHENTICATION_CLOCK_SKEW = 300
_MAX_AUTHENTICATION_TOKEN_LIFETIME = 24 * 60 * 60


class SettingsValidationError(RuntimeError):
    """Content-free fail-closed configuration failure."""

    def __init__(self, failures: tuple[str, ...]) -> None:
        self.failures = failures
        super().__init__("Invalid application configuration: " + ",".join(failures))


def _parse_bool(value: str, field_name: str) -> bool:
    """Parse a conventional environment boolean without ambiguous fallback."""
    normalized = value.strip().lower()
    if normalized in _BOOLEAN_TRUE:
        return True
    if normalized in _BOOLEAN_FALSE:
        return False
    raise SettingsValidationError((f"{field_name}_invalid",))


def _parse_positive_int(value: str, field_name: str) -> int:
    try:
        parsed = int(value)
    except ValueError as error:
        raise SettingsValidationError((f"{field_name}_invalid",)) from error
    if parsed <= 0:
        raise SettingsValidationError((f"{field_name}_invalid",))
    return parsed


def _parse_non_negative_int(value: str, field_name: str) -> int:
    try:
        parsed = int(value)
    except ValueError as error:
        raise SettingsValidationError((f"{field_name}_invalid",)) from error
    if parsed < 0:
        raise SettingsValidationError((f"{field_name}_invalid",))
    return parsed


def _parse_hosts(value: str) -> tuple[str, ...]:
    hosts = tuple(item.strip().lower() for item in value.split(",") if item.strip())
    if len(set(hosts)) != len(hosts):
        raise SettingsValidationError(("allowed_hosts_duplicate",))
    return hosts


def _parse_csv(value: str, field_name: str) -> tuple[str, ...]:
    values = tuple(item.strip() for item in value.split(",") if item.strip())
    if len(set(values)) != len(values):
        raise SettingsValidationError((f"{field_name}_duplicate",))
    return values


@dataclass(frozen=True, slots=True)
class Settings:
    """Runtime settings required by the API."""

    app_name: str = "ConvoCoach API"
    app_environment: str = "local"
    debug: bool = False
    database_url: str = DEFAULT_DATABASE_URL
    redis_url: str = DEFAULT_REDIS_URL
    redis_ca_certificate_path: str = ""
    development_auth_token: str = "convocoach-local-token"
    development_auth_subject: str = "local-user"
    development_auth_email: str = "local@convocoach.invalid"
    authentication_verifier_mode: str = "development"
    authentication_issuer: str = ""
    authentication_audience: str = ""
    authentication_jwks_url: str = ""
    authentication_allowed_algorithms: tuple[str, ...] = ("ES256", "RS256")
    authentication_clock_skew_seconds: int = 60
    authentication_maximum_token_lifetime_seconds: int = 60 * 60
    ai_coaching_enabled: bool = False
    ai_mock_execution_enabled: bool = False
    ai_provider_mode: str = "mock"
    ai_external_processing_approved: bool = False
    ai_safety_evaluation_approved: bool = False
    openai_api_key: str = field(default="", repr=False)
    openai_model: str = OPENAI_TERRA_MODEL
    openai_request_timeout_seconds: int = 30
    openai_safety_identifier_secret: str = field(default="", repr=False)
    zai_api_key: str = field(default="", repr=False)
    zai_model: str = ZAI_GLM_MODEL
    zai_request_timeout_seconds: int = 30
    zai_user_identifier_secret: str = field(default="", repr=False)
    openrouter_api_key: str = field(default="", repr=False)
    openrouter_free_model: str = OPENROUTER_FREE_MODEL
    openrouter_paid_model: str = OPENROUTER_PAID_MODEL
    openrouter_free_reasoning_effort: str = "none"
    openrouter_paid_reasoning_effort: str = "medium"
    openrouter_request_timeout_seconds: int = 30
    openrouter_user_identifier_secret: str = field(default="", repr=False)
    ai_usage_enforcement_enabled: bool = False
    ai_new_requests_per_minute: int = 5
    ai_reservation_cost_microusd: int = 100_000
    ai_user_monthly_budget_microusd: int = 2_000_000
    ai_global_monthly_budget_microusd: int = 100_000_000
    ai_budget_alert_percent: int = 80
    openai_input_price_microusd_per_million_tokens: int = 2_500_000
    openai_output_price_microusd_per_million_tokens: int = 15_000_000
    zai_input_price_microusd_per_million_tokens: int = 1_400_000
    zai_output_price_microusd_per_million_tokens: int = 4_400_000
    openrouter_free_input_price_microusd_per_million_tokens: int = 150_000
    openrouter_free_output_price_microusd_per_million_tokens: int = 600_000
    openrouter_paid_input_price_microusd_per_million_tokens: int = 1_000_000
    openrouter_paid_output_price_microusd_per_million_tokens: int = 6_000_000
    store_billing_enabled: bool = False
    store_transaction_hash_secret: str = field(default="", repr=False)
    apple_iap_bundle_id: str = ""
    apple_iap_app_id: int = 0
    apple_iap_environment: str = "sandbox"
    apple_iap_product_ids: tuple[str, ...] = ()
    google_play_package_name: str = ""
    google_play_product_ids: tuple[str, ...] = ()
    google_play_use_application_default_credentials: bool = False
    google_play_service_account_json: str = field(default="", repr=False)
    google_play_pubsub_audience: str = ""
    google_play_pubsub_service_account: str = ""
    store_verification_timeout_seconds: int = 15
    openapi_enabled: bool = True
    operational_checks_enabled: bool = False
    max_request_body_bytes: int = 1024 * 1024
    log_level: str = "INFO"
    allowed_hosts: tuple[str, ...] = ("testserver", "localhost", "127.0.0.1")

    @property
    def dependencies_configured(self) -> bool:
        """Whether required dependency locations are present, without probing them."""
        return bool(self.database_url.strip() and self.redis_url.strip())


def validate_settings(settings: Settings) -> None:
    """Reject unsafe or internally inconsistent runtime configuration."""
    failures: list[str] = []
    environment = settings.app_environment.strip().lower()
    log_level = settings.log_level.strip().upper()
    try:
        database = urlsplit(settings.database_url)
        _ = database.port
    except ValueError:
        database = urlsplit("")
        failures.append("database_url_invalid")
    try:
        redis = urlsplit(settings.redis_url)
        _ = redis.port
    except ValueError:
        redis = urlsplit("")
        failures.append("redis_url_invalid")
    try:
        authentication_issuer = urlsplit(settings.authentication_issuer)
        _ = authentication_issuer.port
    except ValueError:
        authentication_issuer = urlsplit("")
        failures.append("authentication_issuer_invalid")
    try:
        authentication_jwks = urlsplit(settings.authentication_jwks_url)
        _ = authentication_jwks.port
    except ValueError:
        authentication_jwks = urlsplit("")
        failures.append("authentication_jwks_url_invalid")

    if environment not in _ENVIRONMENTS:
        failures.append("app_environment_unsupported")
    elif settings.app_environment != environment:
        failures.append("app_environment_not_normalized")
    if not settings.app_name.strip():
        failures.append("app_name_missing")
    if (
        settings.database_url
        and "database_url_invalid" not in failures
        and database.scheme
        not in {
            "postgresql",
            "postgresql+asyncpg",
            "sqlite+aiosqlite",
        }
    ):
        failures.append("database_url_unsupported")
    if (
        settings.redis_url
        and "redis_url_invalid" not in failures
        and redis.scheme not in {"redis", "rediss"}
    ):
        failures.append("redis_url_unsupported")
    if settings.max_request_body_bytes > _MAX_REQUEST_BODY_LIMIT:
        failures.append("request_body_limit_excessive")
    if settings.max_request_body_bytes <= 0:
        failures.append("request_body_limit_invalid")
    if log_level not in _LOG_LEVELS:
        failures.append("log_level_unsupported")
    elif settings.log_level != log_level:
        failures.append("log_level_not_normalized")
    if len(set(settings.allowed_hosts)) != len(settings.allowed_hosts):
        failures.append("allowed_hosts_duplicate")
    if any(
        host != host.strip().lower()
        or not host
        or any(character in host for character in ("*", "/", ":", " "))
        for host in settings.allowed_hosts
    ):
        failures.append("allowed_hosts_invalid")
    if settings.ai_mock_execution_enabled and not settings.ai_coaching_enabled:
        failures.append("mock_requires_ai_execution")
    if settings.ai_provider_mode not in _AI_PROVIDER_MODES:
        failures.append("ai_provider_mode_unsupported")
    if settings.ai_mock_execution_enabled and settings.ai_provider_mode != "mock":
        failures.append("mock_provider_mode_mismatch")
    if settings.ai_provider_mode == "openai_terra":
        if settings.openai_model != OPENAI_TERRA_MODEL:
            failures.append("openai_model_unsupported")
        if settings.ai_mock_execution_enabled:
            failures.append("openai_mock_execution_enabled")
        if settings.ai_coaching_enabled:
            if not settings.ai_usage_enforcement_enabled:
                failures.append("openai_usage_enforcement_disabled")
            if len(settings.openai_api_key) < 20 or any(
                character.isspace() for character in settings.openai_api_key
            ):
                failures.append("openai_api_key_missing")
            if len(settings.openai_safety_identifier_secret) < 32:
                failures.append("openai_safety_identifier_secret_missing")
    if settings.ai_provider_mode == "zai_glm":
        if settings.zai_model != ZAI_GLM_MODEL:
            failures.append("zai_model_unsupported")
        if settings.ai_mock_execution_enabled:
            failures.append("zai_mock_execution_enabled")
        if settings.ai_coaching_enabled:
            if not settings.ai_usage_enforcement_enabled:
                failures.append("zai_usage_enforcement_disabled")
            if len(settings.zai_api_key) < 20 or any(
                character.isspace() for character in settings.zai_api_key
            ):
                failures.append("zai_api_key_missing")
            if len(settings.zai_user_identifier_secret) < 32:
                failures.append("zai_user_identifier_secret_missing")
    if settings.ai_provider_mode == "openrouter_tiered":
        for tier, model in (
            ("free", settings.openrouter_free_model),
            ("paid", settings.openrouter_paid_model),
        ):
            if len(model) > 96 or _OPENROUTER_MODEL_PATTERN.fullmatch(model) is None:
                failures.append(f"openrouter_{tier}_model_invalid")
        if settings.openrouter_free_model == settings.openrouter_paid_model:
            failures.append("openrouter_tier_models_not_distinct")
        for tier, effort in (
            ("free", settings.openrouter_free_reasoning_effort),
            ("paid", settings.openrouter_paid_reasoning_effort),
        ):
            if effort not in _OPENROUTER_REASONING_EFFORTS:
                failures.append(f"openrouter_{tier}_reasoning_effort_invalid")
        if settings.ai_mock_execution_enabled:
            failures.append("openrouter_mock_execution_enabled")
        if settings.ai_coaching_enabled:
            if not settings.ai_usage_enforcement_enabled:
                failures.append("openrouter_usage_enforcement_disabled")
            if len(settings.openrouter_api_key) < 20 or any(
                character.isspace() for character in settings.openrouter_api_key
            ):
                failures.append("openrouter_api_key_missing")
            if len(settings.openrouter_user_identifier_secret) < 32:
                failures.append("openrouter_user_identifier_secret_missing")
    if not 1 <= settings.ai_new_requests_per_minute <= 60:
        failures.append("ai_rate_limit_invalid")
    if any(
        value <= 0
        for value in (
            settings.ai_reservation_cost_microusd,
            settings.ai_user_monthly_budget_microusd,
            settings.ai_global_monthly_budget_microusd,
            settings.openai_input_price_microusd_per_million_tokens,
            settings.openai_output_price_microusd_per_million_tokens,
            settings.zai_input_price_microusd_per_million_tokens,
            settings.zai_output_price_microusd_per_million_tokens,
            settings.openrouter_free_input_price_microusd_per_million_tokens,
            settings.openrouter_free_output_price_microusd_per_million_tokens,
            settings.openrouter_paid_input_price_microusd_per_million_tokens,
            settings.openrouter_paid_output_price_microusd_per_million_tokens,
        )
    ):
        failures.append("ai_budget_configuration_invalid")
    if settings.ai_user_monthly_budget_microusd > settings.ai_global_monthly_budget_microusd:
        failures.append("ai_budget_order_invalid")
    if not 1 <= settings.ai_budget_alert_percent <= 100:
        failures.append("ai_budget_alert_percent_invalid")
    if not 5 <= settings.openai_request_timeout_seconds <= 60:
        failures.append("openai_request_timeout_invalid")
    if not 5 <= settings.zai_request_timeout_seconds <= 60:
        failures.append("zai_request_timeout_invalid")
    if not 5 <= settings.openrouter_request_timeout_seconds <= 60:
        failures.append("openrouter_request_timeout_invalid")
    if settings.apple_iap_environment not in _STORE_ENVIRONMENTS:
        failures.append("apple_iap_environment_unsupported")
    if not 5 <= settings.store_verification_timeout_seconds <= 30:
        failures.append("store_verification_timeout_invalid")
    if settings.store_billing_enabled:
        if len(settings.store_transaction_hash_secret) < 32:
            failures.append("store_transaction_hash_secret_missing")
        if settings.apple_iap_bundle_id != "com.convocoach.convoCoach":
            failures.append("apple_iap_bundle_id_invalid")
        if settings.apple_iap_app_id <= 0:
            failures.append("apple_iap_app_id_missing")
        if not settings.apple_iap_product_ids:
            failures.append("apple_iap_products_missing")
        if settings.google_play_package_name != "com.convocoach.convo_coach":
            failures.append("google_play_package_name_invalid")
        if not settings.google_play_product_ids:
            failures.append("google_play_products_missing")
        if (
            not settings.google_play_use_application_default_credentials
            and not settings.google_play_service_account_json.strip().startswith("{")
        ):
            failures.append("google_play_service_account_missing")
        google_pubsub_audience = urlsplit(settings.google_play_pubsub_audience)
        if (
            google_pubsub_audience.scheme != "https"
            or not google_pubsub_audience.hostname
            or google_pubsub_audience.username
            or google_pubsub_audience.password
            or google_pubsub_audience.query
            or google_pubsub_audience.fragment
        ):
            failures.append("google_play_pubsub_audience_unsafe")
        if "@" not in settings.google_play_pubsub_service_account or any(
            character.isspace() for character in settings.google_play_pubsub_service_account
        ):
            failures.append("google_play_pubsub_service_account_invalid")
        for field_name, values in (
            ("apple_iap_products", settings.apple_iap_product_ids),
            ("google_play_products", settings.google_play_product_ids),
        ):
            if (
                len(values) != 2
                or len(set(values)) != len(values)
                or any(
                    not value
                    or value != value.strip()
                    or len(value) > 128
                    or any(not (character.isalnum() or character in "._-") for character in value)
                    for value in values
                )
            ):
                failures.append(f"{field_name}_invalid")
    if settings.authentication_verifier_mode not in _AUTHENTICATION_VERIFIER_MODES:
        failures.append("authentication_verifier_mode_unsupported")
    if (
        not settings.authentication_allowed_algorithms
        or len(set(settings.authentication_allowed_algorithms))
        != len(settings.authentication_allowed_algorithms)
        or not set(settings.authentication_allowed_algorithms).issubset(_AUTHENTICATION_ALGORITHMS)
    ):
        failures.append("authentication_algorithms_unsafe")
    if not 0 <= settings.authentication_clock_skew_seconds <= _MAX_AUTHENTICATION_CLOCK_SKEW:
        failures.append("authentication_clock_skew_invalid")
    if not (
        60
        <= settings.authentication_maximum_token_lifetime_seconds
        <= _MAX_AUTHENTICATION_TOKEN_LIFETIME
    ):
        failures.append("authentication_token_lifetime_invalid")

    if environment in {"staging", "production"}:
        if settings.authentication_verifier_mode != "production_contract":
            failures.append(f"{environment}_authentication_verifier_unsafe")
        if (
            authentication_issuer.scheme != "https"
            or not authentication_issuer.hostname
            or authentication_issuer.username
            or authentication_issuer.password
            or authentication_issuer.query
            or authentication_issuer.fragment
        ):
            failures.append(f"{environment}_authentication_issuer_unsafe")
        if not settings.authentication_audience.strip():
            failures.append(f"{environment}_authentication_audience_missing")
        if (
            authentication_jwks.scheme != "https"
            or not authentication_jwks.hostname
            or authentication_jwks.username
            or authentication_jwks.password
            or authentication_jwks.query
            or authentication_jwks.fragment
        ):
            failures.append(f"{environment}_authentication_jwks_url_unsafe")

    if environment == "production":
        if settings.debug:
            failures.append("production_debug_enabled")
        if settings.openapi_enabled:
            failures.append("production_openapi_enabled")
        if not settings.operational_checks_enabled:
            failures.append("production_operational_checks_disabled")
        if not settings.database_url:
            failures.append("production_database_missing")
        database_query = parse_qs(database.query, keep_blank_values=True)
        cloud_sql_hosts = database_query.get("host", [])
        cloud_sql_socket = (
            len(cloud_sql_hosts) == 1
            and cloud_sql_hosts[0].startswith("/cloudsql/")
            and ".." not in cloud_sql_hosts[0]
        )
        remote_tcp_database = bool(
            database.hostname and (database.hostname or "").lower() not in _LOCAL_HOSTS
        )
        if settings.database_url and (
            database.scheme != "postgresql+asyncpg"
            or not (cloud_sql_socket or remote_tcp_database)
            or database.password == "convocoach_local_only"
        ):
            failures.append("production_database_unsafe")
        if not settings.redis_url:
            failures.append("production_redis_missing")
        elif (
            redis.scheme != "rediss"
            or not redis.hostname
            or (redis.hostname or "").lower() in _LOCAL_HOSTS
        ):
            failures.append("production_redis_unsafe")
        if not settings.redis_ca_certificate_path.startswith(
            "/"
        ) or ".." in settings.redis_ca_certificate_path.split("/"):
            failures.append("production_redis_ca_path_unsafe")
        if any(
            value
            for value in (
                settings.development_auth_token,
                settings.development_auth_subject,
                settings.development_auth_email,
            )
        ):
            failures.append("production_development_auth_configured")
        if settings.ai_mock_execution_enabled:
            failures.append("production_mock_execution_enabled")
        if settings.ai_coaching_enabled:
            if settings.ai_provider_mode not in {
                "openai_terra",
                "zai_glm",
                "openrouter_tiered",
            }:
                failures.append("production_ai_provider_unsafe")
            if not settings.ai_external_processing_approved:
                failures.append("production_external_processing_unapproved")
            if not settings.ai_safety_evaluation_approved:
                failures.append("production_ai_safety_evaluation_unapproved")
        if settings.store_billing_enabled and settings.apple_iap_environment != "production":
            failures.append("production_apple_iap_environment_unsafe")
        if (
            not settings.allowed_hosts
            or any("*" in host for host in settings.allowed_hosts)
            or any(host in _LOCAL_HOSTS for host in settings.allowed_hosts)
        ):
            failures.append("production_allowed_hosts_unsafe")
        if log_level == "DEBUG":
            failures.append("production_debug_logging_enabled")

    if failures:
        raise SettingsValidationError(tuple(dict.fromkeys(failures)))


@lru_cache
def get_settings() -> Settings:
    """Build and cache settings from the process environment."""
    environment = getenv("APP_ENVIRONMENT", "local").strip().lower()
    local_environment = environment in {"local", "test"}
    settings = Settings(
        app_name=getenv("APP_NAME", "ConvoCoach API").strip(),
        app_environment=environment,
        debug=_parse_bool(getenv("APP_DEBUG", "false"), "app_debug"),
        database_url=getenv("DATABASE_URL", DEFAULT_DATABASE_URL).strip(),
        redis_url=getenv("REDIS_URL", DEFAULT_REDIS_URL).strip(),
        redis_ca_certificate_path=getenv("REDIS_CA_CERTIFICATE_PATH", "").strip(),
        development_auth_token=getenv(
            "DEVELOPMENT_AUTH_TOKEN",
            "convocoach-local-token" if local_environment else "",
        ).strip(),
        development_auth_subject=getenv(
            "DEVELOPMENT_AUTH_SUBJECT",
            "local-user" if local_environment else "",
        ).strip(),
        development_auth_email=getenv(
            "DEVELOPMENT_AUTH_EMAIL",
            "local@convocoach.invalid" if local_environment else "",
        ).strip(),
        authentication_verifier_mode=getenv(
            "AUTHENTICATION_VERIFIER_MODE",
            "development" if local_environment else "production_contract",
        )
        .strip()
        .lower(),
        authentication_issuer=getenv("AUTHENTICATION_ISSUER", "").strip(),
        authentication_audience=getenv("AUTHENTICATION_AUDIENCE", "").strip(),
        authentication_jwks_url=getenv("AUTHENTICATION_JWKS_URL", "").strip(),
        authentication_allowed_algorithms=_parse_csv(
            getenv("AUTHENTICATION_ALLOWED_ALGORITHMS", "ES256,RS256"),
            "authentication_allowed_algorithms",
        ),
        authentication_clock_skew_seconds=_parse_non_negative_int(
            getenv("AUTHENTICATION_CLOCK_SKEW_SECONDS", "60"),
            "authentication_clock_skew_seconds",
        ),
        authentication_maximum_token_lifetime_seconds=_parse_positive_int(
            getenv("AUTHENTICATION_MAXIMUM_TOKEN_LIFETIME_SECONDS", "3600"),
            "authentication_maximum_token_lifetime_seconds",
        ),
        ai_coaching_enabled=_parse_bool(
            getenv("AI_COACHING_ENABLED", "false"),
            "ai_coaching_enabled",
        ),
        ai_mock_execution_enabled=_parse_bool(
            getenv("AI_MOCK_EXECUTION_ENABLED", "false"),
            "ai_mock_execution_enabled",
        ),
        ai_provider_mode=getenv("AI_PROVIDER_MODE", "mock").strip().lower(),
        ai_external_processing_approved=_parse_bool(
            getenv("AI_EXTERNAL_PROCESSING_APPROVED", "false"),
            "ai_external_processing_approved",
        ),
        ai_safety_evaluation_approved=_parse_bool(
            getenv("AI_SAFETY_EVALUATION_APPROVED", "false"),
            "ai_safety_evaluation_approved",
        ),
        openai_api_key=getenv("OPENAI_API_KEY", "").strip(),
        openai_model=getenv("OPENAI_MODEL", OPENAI_TERRA_MODEL).strip(),
        openai_request_timeout_seconds=_parse_positive_int(
            getenv("OPENAI_REQUEST_TIMEOUT_SECONDS", "30"),
            "openai_request_timeout_seconds",
        ),
        openai_safety_identifier_secret=getenv("OPENAI_SAFETY_IDENTIFIER_SECRET", "").strip(),
        zai_api_key=getenv("ZAI_API_KEY", "").strip(),
        zai_model=getenv("ZAI_MODEL", ZAI_GLM_MODEL).strip(),
        zai_request_timeout_seconds=_parse_positive_int(
            getenv("ZAI_REQUEST_TIMEOUT_SECONDS", "30"),
            "zai_request_timeout_seconds",
        ),
        zai_user_identifier_secret=getenv("ZAI_USER_IDENTIFIER_SECRET", "").strip(),
        openrouter_api_key=getenv("OPENROUTER_API_KEY", "").strip(),
        openrouter_free_model=getenv(
            "OPENROUTER_FREE_MODEL",
            OPENROUTER_FREE_MODEL,
        ).strip(),
        openrouter_paid_model=getenv(
            "OPENROUTER_PAID_MODEL",
            OPENROUTER_PAID_MODEL,
        ).strip(),
        openrouter_free_reasoning_effort=getenv(
            "OPENROUTER_FREE_REASONING_EFFORT",
            "none",
        )
        .strip()
        .lower(),
        openrouter_paid_reasoning_effort=getenv(
            "OPENROUTER_PAID_REASONING_EFFORT",
            "medium",
        )
        .strip()
        .lower(),
        openrouter_request_timeout_seconds=_parse_positive_int(
            getenv("OPENROUTER_REQUEST_TIMEOUT_SECONDS", "30"),
            "openrouter_request_timeout_seconds",
        ),
        openrouter_user_identifier_secret=getenv("OPENROUTER_USER_IDENTIFIER_SECRET", "").strip(),
        ai_usage_enforcement_enabled=_parse_bool(
            getenv("AI_USAGE_ENFORCEMENT_ENABLED", "false"),
            "ai_usage_enforcement_enabled",
        ),
        ai_new_requests_per_minute=_parse_positive_int(
            getenv("AI_NEW_REQUESTS_PER_MINUTE", "5"),
            "ai_new_requests_per_minute",
        ),
        ai_reservation_cost_microusd=_parse_positive_int(
            getenv("AI_RESERVATION_COST_MICROUSD", "100000"),
            "ai_reservation_cost_microusd",
        ),
        ai_user_monthly_budget_microusd=_parse_positive_int(
            getenv("AI_USER_MONTHLY_BUDGET_MICROUSD", "2000000"),
            "ai_user_monthly_budget_microusd",
        ),
        ai_global_monthly_budget_microusd=_parse_positive_int(
            getenv("AI_GLOBAL_MONTHLY_BUDGET_MICROUSD", "100000000"),
            "ai_global_monthly_budget_microusd",
        ),
        ai_budget_alert_percent=_parse_positive_int(
            getenv("AI_BUDGET_ALERT_PERCENT", "80"),
            "ai_budget_alert_percent",
        ),
        openai_input_price_microusd_per_million_tokens=_parse_positive_int(
            getenv("OPENAI_INPUT_PRICE_MICROUSD_PER_MILLION_TOKENS", "2500000"),
            "openai_input_price_microusd_per_million_tokens",
        ),
        openai_output_price_microusd_per_million_tokens=_parse_positive_int(
            getenv("OPENAI_OUTPUT_PRICE_MICROUSD_PER_MILLION_TOKENS", "15000000"),
            "openai_output_price_microusd_per_million_tokens",
        ),
        zai_input_price_microusd_per_million_tokens=_parse_positive_int(
            getenv("ZAI_INPUT_PRICE_MICROUSD_PER_MILLION_TOKENS", "1400000"),
            "zai_input_price_microusd_per_million_tokens",
        ),
        zai_output_price_microusd_per_million_tokens=_parse_positive_int(
            getenv("ZAI_OUTPUT_PRICE_MICROUSD_PER_MILLION_TOKENS", "4400000"),
            "zai_output_price_microusd_per_million_tokens",
        ),
        openrouter_free_input_price_microusd_per_million_tokens=_parse_positive_int(
            getenv(
                "OPENROUTER_FREE_INPUT_PRICE_MICROUSD_PER_MILLION_TOKENS",
                "150000",
            ),
            "openrouter_free_input_price_microusd_per_million_tokens",
        ),
        openrouter_free_output_price_microusd_per_million_tokens=_parse_positive_int(
            getenv(
                "OPENROUTER_FREE_OUTPUT_PRICE_MICROUSD_PER_MILLION_TOKENS",
                "600000",
            ),
            "openrouter_free_output_price_microusd_per_million_tokens",
        ),
        openrouter_paid_input_price_microusd_per_million_tokens=_parse_positive_int(
            getenv(
                "OPENROUTER_PAID_INPUT_PRICE_MICROUSD_PER_MILLION_TOKENS",
                "1000000",
            ),
            "openrouter_paid_input_price_microusd_per_million_tokens",
        ),
        openrouter_paid_output_price_microusd_per_million_tokens=_parse_positive_int(
            getenv(
                "OPENROUTER_PAID_OUTPUT_PRICE_MICROUSD_PER_MILLION_TOKENS",
                "6000000",
            ),
            "openrouter_paid_output_price_microusd_per_million_tokens",
        ),
        store_billing_enabled=_parse_bool(
            getenv("STORE_BILLING_ENABLED", "false"),
            "store_billing_enabled",
        ),
        store_transaction_hash_secret=getenv("STORE_TRANSACTION_HASH_SECRET", "").strip(),
        apple_iap_bundle_id=getenv("APPLE_IAP_BUNDLE_ID", "").strip(),
        apple_iap_app_id=_parse_non_negative_int(
            getenv("APPLE_IAP_APP_ID", "0"),
            "apple_iap_app_id",
        ),
        apple_iap_environment=getenv("APPLE_IAP_ENVIRONMENT", "sandbox").strip().lower(),
        apple_iap_product_ids=_parse_csv(
            getenv("APPLE_IAP_PRODUCT_IDS", ""),
            "apple_iap_product_ids",
        ),
        google_play_package_name=getenv("GOOGLE_PLAY_PACKAGE_NAME", "").strip(),
        google_play_product_ids=_parse_csv(
            getenv("GOOGLE_PLAY_PRODUCT_IDS", ""),
            "google_play_product_ids",
        ),
        google_play_use_application_default_credentials=_parse_bool(
            getenv("GOOGLE_PLAY_USE_APPLICATION_DEFAULT_CREDENTIALS", "false"),
            "google_play_use_application_default_credentials",
        ),
        google_play_service_account_json=getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip(),
        google_play_pubsub_audience=getenv("GOOGLE_PLAY_PUBSUB_AUDIENCE", "").strip(),
        google_play_pubsub_service_account=getenv("GOOGLE_PLAY_PUBSUB_SERVICE_ACCOUNT", "").strip(),
        store_verification_timeout_seconds=_parse_positive_int(
            getenv("STORE_VERIFICATION_TIMEOUT_SECONDS", "15"),
            "store_verification_timeout_seconds",
        ),
        openapi_enabled=_parse_bool(
            getenv("OPENAPI_ENABLED", "true" if local_environment else "false"),
            "openapi_enabled",
        ),
        operational_checks_enabled=_parse_bool(
            getenv(
                "OPERATIONAL_CHECKS_ENABLED",
                "true" if environment in {"staging", "production"} else "false",
            ),
            "operational_checks_enabled",
        ),
        max_request_body_bytes=_parse_positive_int(
            getenv("MAX_REQUEST_BODY_BYTES", str(1024 * 1024)),
            "max_request_body_bytes",
        ),
        log_level=getenv("APP_LOG_LEVEL", "INFO").strip().upper(),
        allowed_hosts=_parse_hosts(
            getenv(
                "ALLOWED_HOSTS",
                "testserver,localhost,127.0.0.1" if local_environment else "",
            )
        ),
    )
    validate_settings(settings)
    return settings
