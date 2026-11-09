import copy
import importlib.util
import json
import os
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('agent_server', Path(__file__).parents[1] / 'backend/server.py')
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)

DRAFT = {'steps': [{'title': 'Locate the practice lid', 'instruction': 'Point to the cardboard lid.',
                   'action': 'marker', 'confirmation': 'I can see the lid', 'pages': []}]}
REVIEW = {'decision': 'pass', 'summary': 'Harmless practice proposal; human review remains required.'}
PRESENT = {'summary': 'Review this unapproved cardboard-box demonstration.'}

class AgentTests(unittest.TestCase):
    def test_three_roles_and_non_executable_contract(self):
        with patch.object(server, 'model_json', side_effect=[DRAFT, REVIEW, PRESENT]) as model:
            result = server.plan({'domain': 'education', 'goal': 'Show a cardboard lid'})
        self.assertEqual(model.call_count, 3)
        self.assertEqual([a['role'] for a in result['agents']], ['planner', 'reviewer', 'presenter'])
        self.assertEqual(result['status'], 'proposal')
        self.assertIs(result['executable'], False)
        self.assertIs(result['requiresHumanReview'], True)
        self.assertEqual(result['steps'][0]['action'], 'marker')

    def test_reviewer_blocks_and_presenter_never_called(self):
        with patch.object(server, 'model_json', side_effect=[DRAFT, {'decision': 'block', 'summary': 'Missing context'}]) as model:
            result = server.plan({'domain': 'assembly', 'goal': 'Show a cardboard lid'})
        self.assertEqual(model.call_count, 2)
        self.assertEqual(result['status'], 'blocked')
        self.assertEqual(result['steps'], [])

    def test_hazardous_goal_blocked_before_provider(self):
        with patch.object(server, 'model_json', side_effect=AssertionError('must not call')):
            result = server.plan({'domain': 'maintenance', 'goal': 'Repair a live electrical circuit'})
        self.assertEqual(result['status'], 'blocked')

    def test_maintenance_requires_relevant_evidence(self):
        with patch.object(server, 'model_json', side_effect=AssertionError('must not call')):
            result = server.plan({'domain': 'maintenance', 'goal': 'Inspect the latch', 'pages': [{'page': 1, 'text': 'Warranty terms'}]})
        self.assertEqual(result['status'], 'needs_evidence')

    def test_maintenance_step_requires_citation(self):
        with patch.object(server, 'model_json', return_value=DRAFT):
            with self.assertRaises(ValueError):
                server.plan({'domain': 'maintenance', 'goal': 'Inspect lid', 'pages': [{'page': 1, 'text': 'Inspect the lid visually.'}]})

    def test_reject_fabricated_citation(self):
        draft = copy.deepcopy(DRAFT); draft['steps'][0]['pages'] = [99]
        with self.assertRaises(ValueError):
            server.validate_steps(draft, [{'page': 1, 'text': 'Lid'}], 'education')

    def test_reject_executable_action(self):
        draft = copy.deepcopy(DRAFT); draft['steps'][0]['action'] = 'run_shell'
        with self.assertRaises(ValueError):
            server.validate_steps(draft, [], 'education')

    def test_reject_extra_coordinates_or_code(self):
        draft = copy.deepcopy(DRAFT); draft['steps'][0]['code'] = 'untrusted()'
        with self.assertRaises(ValueError):
            server.validate_steps(draft, [], 'education')

    def test_reject_oversized_steps(self):
        draft = {'steps': DRAFT['steps'] * 9}
        with self.assertRaises(ValueError):
            server.validate_steps(draft, [], 'education')

    def test_invalid_reviewer_cannot_approve(self):
        with patch.object(server, 'model_json', side_effect=[DRAFT, {'decision': 'approve', 'summary': 'safe'}]):
            with self.assertRaises(ValueError):
                server.plan({'domain': 'education', 'goal': 'Show a lid'})

    def test_presenter_cannot_replace_steps(self):
        with patch.object(server, 'model_json', side_effect=[DRAFT, REVIEW, {'summary': 'hi', 'steps': []}]):
            with self.assertRaises(ValueError):
                server.plan({'domain': 'creative', 'goal': 'Show a lid'})

    def test_generated_hazard_blocks(self):
        draft = copy.deepcopy(DRAFT); draft['steps'][0]['instruction'] = 'Open the high-voltage power supply.'
        with patch.object(server, 'model_json', return_value=draft) as model:
            result = server.plan({'domain': 'education', 'goal': 'Show a lid'})
        self.assertEqual(model.call_count, 1)
        self.assertEqual(result['status'], 'blocked')
        self.assertEqual(result['steps'], [])

    def test_invalid_payloads(self):
        for payload in [None, {}, {'domain': 'surgery', 'goal': 'hello'},
                        {'domain': 'creative', 'goal': ''},
                        {'domain': 'creative', 'goal': 'x'*2001},
                        {'domain': 'creative', 'goal': 'hi', 'pages': 'bad'},
                        {'domain': 'creative', 'goal': 'hi', 'execute': True}]:
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                server.validate_plan_request(payload)

    def test_missing_provider_is_not_demo_success(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RuntimeError):
                server.plan({'domain': 'creative', 'goal': 'Explain a cardboard shape'})

class ExcerptTests(unittest.TestCase):
    def setUp(self):
        self.context = [{'page': 2, 'text': 'Inspect the paper tray visually. Keep the cover closed.'}]
        self.draft = copy.deepcopy(DRAFT)
        self.draft['steps'][0]['pages'] = [2]
        self.draft['steps'][0]['evidence'] = [{'page': 2, 'quote': 'Inspect the paper tray visually.'}]
    def test_exact_source_excerpt_accepted(self):
        steps = server.validate_steps(self.draft, self.context, 'maintenance')
        self.assertEqual(steps[0]['evidence'][0]['page'], 2)
    def test_invented_quote_rejected(self):
        self.draft['steps'][0]['evidence'][0]['quote'] = 'Remove the screws and open the cover.'
        with self.assertRaises(ValueError):
            server.validate_steps(self.draft, self.context, 'maintenance')
    def test_existing_page_without_quote_rejected(self):
        self.draft['steps'][0]['evidence'] = []
        with self.assertRaises(ValueError):
            server.validate_steps(self.draft, self.context, 'maintenance')
    def test_quote_from_uncited_page_rejected(self):
        self.draft['steps'][0]['evidence'][0]['page'] = 3
        with self.assertRaises(ValueError):
            server.validate_steps(self.draft, self.context, 'maintenance')

class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.http = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        self.thread = threading.Thread(target=self.http.serve_forever, daemon=True)
        self.thread.start()
        self.url = 'http://127.0.0.1:' + str(self.http.server_port) + '/plan'
    def tearDown(self):
        self.http.shutdown(); self.http.server_close(); self.thread.join()
    def request(self, payload, token):
        return urllib.request.Request(self.url, data=json.dumps(payload).encode(),
            headers={'Authorization': 'Bearer '+token, 'Content-Type': 'application/json'})
    def test_plan_requires_authentication(self):
        with patch.dict(os.environ, {'FIELDGUIDE_TOKEN': 'secret'}):
            with self.assertRaises(urllib.error.HTTPError) as result:
                urllib.request.urlopen(self.request({'domain':'education','goal':'shape'}, 'wrong'))
            self.assertEqual(result.exception.code, 401)
    def test_plan_routes_with_authentication(self):
        with patch.dict(os.environ, {'FIELDGUIDE_TOKEN': 'secret'}):
            with patch.object(server, 'model_json', side_effect=[DRAFT, REVIEW, PRESENT]):
                with urllib.request.urlopen(self.request({'domain':'education','goal':'shape'}, 'secret')) as result:
                    payload = json.load(result)
                    self.assertEqual(payload['status'], 'proposal')
                    self.assertIs(payload['executable'], False)
    def test_invalid_payload_returns_400(self):
        with patch.dict(os.environ, {'FIELDGUIDE_TOKEN': 'secret'}):
            with self.assertRaises(urllib.error.HTTPError) as result:
                urllib.request.urlopen(self.request({'domain':'unsupported','goal':'shape'}, 'secret'))
            self.assertEqual(result.exception.code, 400)

if __name__ == '__main__': unittest.main()
