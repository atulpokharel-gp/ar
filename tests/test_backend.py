import importlib.util
import os
import unittest
from unittest.mock import patch
from pathlib import Path
spec = importlib.util.spec_from_file_location('server', Path(__file__).parents[1] / 'backend/server.py')
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)

class EvidenceTests(unittest.TestCase):
    def test_duplicate_pages_rejected(self):
        with self.assertRaises(ValueError):
            server.validate({'question': 'lid', 'pages': [{'page': 1, 'text': 'a'}, {'page': 1, 'text': 'b'}]})
    def test_bool_is_not_a_page_number(self):
        with self.assertRaises(ValueError):
            server.validate({'question': 'lid', 'pages': [{'page': True, 'text': 'a'}]})
    def test_retrieval_finds_late_page_content(self):
        result = server.retrieve('latch', [{'page': 7, 'text': 'x ' * 4000 + 'The latch is blue.'}])
        self.assertEqual(result[0]['page'], 7)
        self.assertIn('latch', result[0]['text'])
    def test_fabricated_citation_rejected(self):
        with self.assertRaises(ValueError):
            server.validate_answer({'answer': 'a', 'pages': [99]}, [{'page': 2}])
    def test_missing_citations_rejected(self):
        with self.assertRaises(ValueError):
            server.validate_answer({'answer': 'a', 'pages': []}, [{'page': 2}])
    def test_real_citation_accepted(self):
        result = server.validate_answer({'answer': 'The lid is blue.', 'pages': [2, 2]}, [{'page': 2}])
        self.assertEqual(result['pages'], [2])
    def test_no_evidence_does_not_call_provider(self):
        with patch('urllib.request.urlopen', side_effect=AssertionError('network called')):
            result = server.ask({'question': 'quasar', 'pages': [{'page': 1, 'text': 'Blue lid'}]})
            self.assertEqual(result['mode'], 'No evidence')
    def test_no_keys_never_falls_back_to_mock(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RuntimeError):
                server.ask({'question': 'lid', 'pages': [{'page': 1, 'text': 'Blue lid'}]})

if __name__ == '__main__': unittest.main()
