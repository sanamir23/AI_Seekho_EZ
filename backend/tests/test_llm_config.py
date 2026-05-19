import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.agents import llm


class LlmConfigTests(unittest.TestCase):
    def test_fast_llm_uses_configured_model_when_fast_model_is_not_set(self):
        with (
            patch.object(
                llm,
                "get_settings",
                return_value=SimpleNamespace(
                    gemini_api_key="test-key",
                    gemini_model="configured-model",
                    gemini_fast_model=None,
                ),
            ),
            patch.object(llm, "_build", return_value=object()) as build,
        ):
            llm.get_llm(fast=True)

        build.assert_called_once_with("configured-model", 0.2)

    def test_fast_llm_uses_fast_model_when_set(self):
        with (
            patch.object(
                llm,
                "get_settings",
                return_value=SimpleNamespace(
                    gemini_api_key="test-key",
                    gemini_model="configured-model",
                    gemini_fast_model="fast-model",
                ),
            ),
            patch.object(llm, "_build", return_value=object()) as build,
        ):
            llm.get_llm(fast=True)

        build.assert_called_once_with("fast-model", 0.2)


if __name__ == "__main__":
    unittest.main()
