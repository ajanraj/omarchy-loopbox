#!/usr/bin/env python3

import importlib.util
from importlib.machinery import SourceFileLoader
import socket
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "media-url"
SPEC = importlib.util.spec_from_loader("media_url", SourceFileLoader("media_url", str(SCRIPT)))
assert SPEC is not None and SPEC.loader is not None
media_url = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(media_url)


class MediaUrlTest(unittest.TestCase):
    def test_accepts_canonical_klipy_gif(self):
        media_url.validate_url("https://static.klipy.com/images/example.gif")

    def test_rejects_url_parsing_tricks(self):
        invalid_urls = (
            "http://static.klipy.com/image.gif",
            "HTTPS://static.klipy.com/image.gif",
            "https://STATIC.KLIPY.COM/image.gif",
            "https://user@static.klipy.com/image.gif",
            "https://static.klipy.com:443/image.gif",
            "https://static.klipy.com.evil.test/image.gif",
            "https://static.klipy.com@evil.test/image.gif",
            "https://static.klipy.com/image.gif?download=1",
            "https://static.klipy.com/image.gif?",
            "https://static.klipy.com/image.gif#fragment",
            "https://static.klipy.com/image.gif#",
            "https://static.klipy.com/",
            "https://static.klipy.com/image.png",
            " https://static.klipy.com/image.gif",
            "https://static.klipy.com/image.gif\n",
            "https://static.klipy.com/image.gif\x00",
            "https://static.klipy.com/image.gif\x9f",
        )
        for url in invalid_urls:
            with self.subTest(url=repr(url)), self.assertRaises(media_url.MediaUrlError):
                media_url.validate_url(url)

    def test_resolve_deduplicates_global_addresses_and_brackets_ipv6(self):
        records = [
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443)),
            (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("2606:4700:4700::1111", 443, 0, 0)),
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443)),
        ]
        with patch.object(media_url.socket, "getaddrinfo", return_value=records) as resolver:
            result = media_url.resolve_url("https://static.klipy.com/image.gif")

        self.assertEqual(
            result,
            "static.klipy.com:443:8.8.8.8,[2606:4700:4700::1111]",
        )
        resolver.assert_called_once_with("static.klipy.com", 443, type=socket.SOCK_STREAM)

    def test_resolve_rejects_any_non_global_address(self):
        records = [
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443)),
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443)),
        ]
        with patch.object(media_url.socket, "getaddrinfo", return_value=records):
            with self.assertRaisesRegex(media_url.MediaUrlError, "non-global IP address"):
                media_url.resolve_url("https://static.klipy.com/image.gif")

    def test_resolve_rejects_ipv4_and_ipv6_multicast(self):
        for address in ("224.0.0.1", "ff02::1"):
            family = socket.AF_INET6 if ":" in address else socket.AF_INET
            records = [(family, socket.SOCK_STREAM, 6, "", (address, 443))]
            with self.subTest(address=address), patch.object(
                media_url.socket, "getaddrinfo", return_value=records
            ):
                with self.assertRaisesRegex(media_url.MediaUrlError, "non-global IP address"):
                    media_url.resolve_url("https://static.klipy.com/image.gif")

    def test_resolve_rejects_empty_results(self):
        with patch.object(media_url.socket, "getaddrinfo", return_value=[]):
            with self.assertRaisesRegex(media_url.MediaUrlError, "no addresses"):
                media_url.resolve_url("https://static.klipy.com/image.gif")

    def test_cli_reports_validation_error(self):
        result = subprocess.run(
            [sys.executable, SCRIPT, "validate", "https://evil.test/image.gif"],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("host must be exactly", result.stderr)


if __name__ == "__main__":
    unittest.main()
