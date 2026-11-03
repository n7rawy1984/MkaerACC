"""Focused local regression cases for the Stage C Vary verifier."""

import unittest

from platform_invitation_vary import parse_vary, require_origin_in_vary


class VaryVerificationTests(unittest.TestCase):
    def test_origin(self):
        self.assertEqual(require_origin_in_vary("Origin"), {"origin"})

    def test_encoding_before_origin(self):
        self.assertEqual(
            require_origin_in_vary("Accept-Encoding, Origin"),
            {"accept-encoding", "origin"},
        )

    def test_encoding_after_origin(self):
        self.assertEqual(
            require_origin_in_vary("Origin, Accept-Encoding"),
            {"accept-encoding", "origin"},
        )

    def test_missing_origin(self):
        with self.assertRaises(AssertionError):
            require_origin_in_vary("Accept-Encoding")

    def test_case_and_whitespace(self):
        self.assertEqual(
            require_origin_in_vary(" \tAcCePt-EnCoDiNg\t,  oRiGiN \t"),
            {"accept-encoding", "origin"},
        )

    def test_multiple_lines(self):
        self.assertEqual(
            require_origin_in_vary(["Accept-Encoding", "Origin"]),
            {"accept-encoding", "origin"},
        )

    def test_duplicate_members(self):
        self.assertEqual(require_origin_in_vary("Origin, ORIGIN"), {"origin"})

    def test_additional_valid_members_and_order(self):
        self.assertEqual(
            require_origin_in_vary("X-Region, ORIGIN, Accept-Language"),
            {"x-region", "origin", "accept-language"},
        )

    def test_absent_header(self):
        with self.assertRaises(AssertionError):
            require_origin_in_vary(None)

    def test_empty_header(self):
        with self.assertRaises(AssertionError):
            require_origin_in_vary(" \t")

    def test_substring_is_not_origin(self):
        with self.assertRaises(AssertionError):
            require_origin_in_vary("X-Origin")

    def test_invalid_field_name(self):
        with self.assertRaises(AssertionError):
            require_origin_in_vary("Origin, Not A Field")

    def test_parser_combines_empty_list_members(self):
        self.assertEqual(parse_vary("Origin,, Accept-Encoding"), {"origin", "accept-encoding"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
