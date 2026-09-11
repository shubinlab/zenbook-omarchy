#!/usr/bin/env python3
import importlib.util
import json
import pathlib
import unittest
from importlib.machinery import SourceFileLoader


SCRIPT = pathlib.Path(__file__).with_name("searxng-search")
if SCRIPT.exists():
    LOADER = SourceFileLoader("searxng_search", str(SCRIPT))
    SPEC = importlib.util.spec_from_loader("searxng_search", LOADER)
    MODULE = importlib.util.module_from_spec(SPEC)
    assert SPEC.loader is not None
    SPEC.loader.exec_module(MODULE)
else:
    class MissingImplementation:
        class UpstreamResponseError(Exception):
            pass

        @staticmethod
        def normalize_payload(*args, **kwargs):
            raise NotImplementedError("searxng-search is not implemented")

        @staticmethod
        def validate_query(*args, **kwargs):
            raise NotImplementedError("searxng-search is not implemented")

        @staticmethod
        def parse_payload(*args, **kwargs):
            raise NotImplementedError("searxng-search is not implemented")

    MODULE = MissingImplementation


class SearxngSearchTests(unittest.TestCase):
    def test_normalize_filters_results_to_requested_domains(self):
        payload = {
            "results": [
                {"url": "https://cisa.gov/kev"},
                {"url": "https://www.cisa.gov/kev"},
                {"url": "https://facebook.com/"},
                {"url": "https://notcisa.gov/"},
            ]
        }

        result = MODULE.normalize_payload(
            payload,
            query="kev",
            category="general",
            language="en",
            time_range=None,
            limit=10,
            instance="http://127.0.0.1:8080",
            domains=["cisa.gov"],
        )

        self.assertEqual(result["domains"], ["cisa.gov"])
        self.assertEqual([item["url"] for item in result["results"]], [
            "https://cisa.gov/kev",
            "https://www.cisa.gov/kev",
        ])

    def test_validate_domain_rejects_urls_and_normalizes_hostnames(self):
        self.assertEqual(MODULE.validate_domain(" CISA.GOV. "), "cisa.gov")
        with self.assertRaises(ValueError):
            MODULE.validate_domain("https://cisa.gov")

    def test_normalize_deduplicates_urls_and_preserves_provenance(self):
        payload = {
            "query": "omarchy",
            "results": [
                {"title": "One", "url": "https://example.test/a", "engine": "one"},
                {"title": "Duplicate", "url": "https://example.test/a", "engine": "two"},
                {"title": "Two", "url": "https://example.test/b", "content": "text"},
            ],
        }

        result = MODULE.normalize_payload(
            payload,
            query="omarchy",
            category="general",
            language="all",
            time_range=None,
            limit=10,
            instance="http://127.0.0.1:8080",
        )

        self.assertEqual(result["query"], "omarchy")
        self.assertEqual(result["results_count"], 2)
        self.assertEqual([item["url"] for item in result["results"]], [
            "https://example.test/a",
            "https://example.test/b",
        ])
        self.assertEqual(result["results"][0]["engine"], "one")
        self.assertEqual(result["results"][1]["content"], "text")

    def test_normalize_limits_results_and_fills_optional_fields(self):
        payload = {"results": [{"url": "https://example.test/a"}, {"title": "missing url"}]}

        result = MODULE.normalize_payload(
            payload,
            query="q",
            category="news",
            language="ru",
            time_range="day",
            limit=1,
            instance="http://127.0.0.1:8080",
        )

        self.assertEqual(result["category"], "news")
        self.assertEqual(result["language"], "ru")
        self.assertEqual(result["time_range"], "day")
        self.assertEqual(result["results_count"], 1)
        self.assertIsNone(result["results"][0]["title"])
        self.assertIsNone(result["results"][0]["publishedDate"])

    def test_validate_query_rejects_empty_and_oversized_values(self):
        with self.assertRaises(ValueError):
            MODULE.validate_query("   ")
        with self.assertRaises(ValueError):
            MODULE.validate_query("x" * 1001)

    def test_parse_payload_rejects_invalid_json(self):
        with self.assertRaises(MODULE.UpstreamResponseError):
            MODULE.parse_payload(b"not json")


if __name__ == "__main__":
    unittest.main()
