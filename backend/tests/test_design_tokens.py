"""Shared design-token smoke tests."""

import json
from pathlib import Path
from typing import cast

import pytest

TOKEN_DIRECTORY = Path(__file__).resolve().parents[2] / "design" / "tokens"


def _theme_colors(theme_file: str) -> dict[str, str]:
    payload = cast(
        dict[str, object],
        json.loads((TOKEN_DIRECTORY / theme_file).read_text(encoding="utf-8")),
    )
    colors = cast(dict[str, dict[str, str]], payload["color"])
    return {name: token["$value"] for name, token in colors.items()}


def _linearized_channel(channel: int) -> float:
    value = channel / 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def _relative_luminance(color: str) -> float:
    red, green, blue = (
        _linearized_channel(int(color[index : index + 2], 16)) for index in (1, 3, 5)
    )
    return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)


def _contrast_ratio(foreground: str, background: str) -> float:
    foreground_luminance = _relative_luminance(foreground)
    background_luminance = _relative_luminance(background)
    lighter = max(foreground_luminance, background_luminance)
    darker = min(foreground_luminance, background_luminance)
    return (lighter + 0.05) / (darker + 0.05)


@pytest.mark.parametrize(
    "token_file",
    ["core.json", "light.json", "dark.json", "motion.json"],
)
def test_design_token_file_is_valid_json(token_file: str) -> None:
    payload = json.loads((TOKEN_DIRECTORY / token_file).read_text(encoding="utf-8"))

    assert isinstance(payload, dict)
    assert payload


@pytest.mark.parametrize("theme_file", ["light.json", "dark.json"])
def test_theme_defines_required_semantic_roles(theme_file: str) -> None:
    colors = _theme_colors(theme_file)

    assert {"background", "surface", "text", "primary", "danger", "focus"} <= colors.keys()


@pytest.mark.parametrize("theme_file", ["light.json", "dark.json"])
@pytest.mark.parametrize(
    ("foreground_role", "background_role", "minimum_ratio"),
    [
        ("text", "background", 4.5),
        ("text", "surface", 4.5),
        ("textOnPrimary", "primary", 4.5),
        ("focus", "background", 3.0),
        ("focus", "surface", 3.0),
    ],
)
def test_theme_roles_meet_contrast_targets(
    theme_file: str,
    foreground_role: str,
    background_role: str,
    minimum_ratio: float,
) -> None:
    colors = _theme_colors(theme_file)

    assert _contrast_ratio(colors[foreground_role], colors[background_role]) >= minimum_ratio
