import unittest

from audit_dependencies import packages


class DependencyReportTests(unittest.TestCase):
    lock = 'packages:\n  example:\n    source: hosted\n    version: "1.0.0"\nsdks:\n'

    def test_uses_selected_versions_for_constraints_and_bom_entries(self):
        native = '\n'.join([
            '+--- org.example:library:{prefer 1.0} -> 2.0.1 (*)',
            '|    \\--- org.example:library -> 2.0.1 (c)',
        ])
        self.assertEqual(packages(self.lock, native), [
            ('Maven', 'org.example:library', '2.0.1'),
            ('Pub', 'example', '1.0.0'),
        ])

    def test_unresolved_or_empty_native_report_is_not_clean(self):
        for report in ['', '+--- org.example:library:1.0 FAILED', '+--- org.example:library:latest.release']:
            with self.assertRaises(ValueError):
                packages(self.lock, report)

    def test_empty_lockfile_is_not_clean(self):
        with self.assertRaises(ValueError):
            packages('')


if __name__ == '__main__':
    unittest.main()
