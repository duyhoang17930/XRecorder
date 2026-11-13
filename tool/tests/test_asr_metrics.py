"""Host-only ASR metric regressions; no downloads, devices or corpus writes."""

import itertools
import unittest

from tool.asr_metrics import distance
from tool.evaluate_task07_asr import normalize


class AsrMetricsTest(unittest.TestCase):
    def test_known_character_errors(self):
        for reference, actual, expected in [
            ('', '', 0), ('', 'abc', 3), ('abc', '', 3),
            ('kitten', 'sitting', 3), ('abc', 'ab', 1), ('ab', 'ba', 2),
            ('Tiếng Việt', 'Tieng Viet', 2), ('こんにちは', 'こんばんは', 2),
            ('مرحبا', 'مرحبا', 0), ('é', 'e\u0301', 2),
        ]:
            with self.subTest(reference=reference, actual=actual):
                self.assertEqual(distance(reference, actual), expected)

    def test_word_tokens_remain_sequences(self):
        self.assertEqual(distance(['one', 'two'], ['one', 'three', 'two']), 1)
        self.assertEqual(distance(['one'], ['two']), 1)
        self.assertEqual(distance((), ('one',)), 1)

    def test_metric_invariants_for_short_sequences(self):
        values = ['', 'a', 'b', 'aa', 'ab', 'ba', 'bb', 'aab']
        for left, right in itertools.product(values, repeat=2):
            result = distance(left, right)
            self.assertEqual(result, distance(right, left))
            self.assertGreaterEqual(result, abs(len(left) - len(right)))
            self.assertLessEqual(result, max(len(left), len(right)))
            self.assertEqual(result == 0, left == right)

    def test_task07_normalization_retains_script_marks_and_numbers(self):
        self.assertEqual(normalize(' Tiếng, Việt! １２ '), 'tiếng việt 12')
        self.assertEqual(normalize('हिन्दी'), 'हिन्दी')
        self.assertNotEqual(normalize('हिन्दी'), normalize('हिनदी'))
        self.assertNotEqual(normalize('عَرَبِيّ'), normalize('عربي'))


if __name__ == '__main__':
    unittest.main()
