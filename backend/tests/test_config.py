"""Settings parsing tests."""

import pytest

from app.core.config import get_settings


def test_settings_are_loaded_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_NAME", "Test Coach")
    monkeypatch.setenv("APP_ENVIRONMENT", "test")
    monkeypatch.setenv("APP_DEBUG", "yes")
    monkeypatch.setenv("DATABASE_URL", "postgresql://database/test")
    monkeypatch.setenv("REDIS_URL", "redis://cache/1")
    monkeypatch.setenv("AI_COACHING_ENABLED", "true")
    monkeypatch.setenv("AI_MOCK_EXECUTION_ENABLED", "true")
    get_settings.cache_clear()

    settings = get_settings()

    assert settings.app_name == "Test Coach"
    assert settings.app_environment == "test"
    assert settings.debug is True
    assert settings.dependencies_configured is True
    assert settings.ai_coaching_enabled is True
    assert settings.ai_mock_execution_enabled is True

    get_settings.cache_clear()


def test_ai_coaching_is_disabled_by_default(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("AI_COACHING_ENABLED", raising=False)
    monkeypatch.delenv("AI_MOCK_EXECUTION_ENABLED", raising=False)
    get_settings.cache_clear()

    assert get_settings().ai_coaching_enabled is False
    assert get_settings().ai_mock_execution_enabled is False

    get_settings.cache_clear()
