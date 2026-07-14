"""Settings parsing tests."""

import pytest

from app.core.config import get_settings


def test_settings_are_loaded_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_NAME", "Test Coach")
    monkeypatch.setenv("APP_ENVIRONMENT", "test")
    monkeypatch.setenv("APP_DEBUG", "yes")
    monkeypatch.setenv("DATABASE_URL", "postgresql://database/test")
    monkeypatch.setenv("REDIS_URL", "redis://cache/1")
    get_settings.cache_clear()

    settings = get_settings()

    assert settings.app_name == "Test Coach"
    assert settings.app_environment == "test"
    assert settings.debug is True
    assert settings.dependencies_configured is True

    get_settings.cache_clear()
