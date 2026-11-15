import copy
import datetime as dt
import importlib.util
from pathlib import Path
import threading
import unittest
from unittest.mock import patch
import urllib.request
import urllib.error
import os
import json

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('runbook', ROOT / 'automation/self-healing/app.py')
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)
NOW = dt.datetime(2026, 1, 1, 12, tzinfo=dt.timezone.utc)


def alert():
    return {'status': 'firing', 'alerts': [{'status': 'firing',
        'startsAt': (NOW - dt.timedelta(minutes=6)).isoformat(),
        'labels': {'alertname': 'AuthHighErrorRate', 'service': 'auth-service', 'namespace': 'auth-ns'}}]}


def deployment():
    return {'metadata': {'resourceVersion': '42', 'generation': 3},
            'spec': {'replicas': 2, 'template': {'metadata': {}}},
            'status': {'observedGeneration': 3, 'updatedReplicas': 2}}


class RunbookTest(unittest.TestCase):
    @patch.object(app, 'kube_request')
    def test_restart_has_fixed_target_and_optimistic_lock(self, api):
        api.return_value = deployment()
        self.assertEqual(app.mitigate(alert(), NOW), 'restart-requested')
        method, target, payload = api.call_args.args
        self.assertEqual((method, target), ('PATCH', app.TARGET))
        self.assertEqual(payload[0], {'op': 'test', 'path': '/metadata/resourceVersion', 'value': '42'})
        self.assertEqual(payload[1]['value'][app.STAMP], NOW.isoformat())

    @patch.object(app, 'kube_request')
    def test_cooldown_survives_process_restart(self, api):
        obj = deployment()
        obj['spec']['template']['metadata']['annotations'] = {
            app.STAMP: (NOW - dt.timedelta(minutes=29)).isoformat()}
        api.return_value = obj
        self.assertEqual(app.mitigate(alert(), NOW), 'cooldown')
        self.assertEqual(api.call_count, 1)

    @patch.object(app, 'kube_request')
    def test_reject_resolved_wrong_service_old_future(self, api):
        variants = []
        p = alert(); p['status'] = 'resolved'; variants.append(p)
        p = alert(); p['alerts'][0]['labels']['service'] = 'other'; variants.append(p)
        p = alert(); p['alerts'][0]['labels']['namespace'] = 'default'; variants.append(p)
        p = alert(); p['alerts'][0]['startsAt'] = (NOW - dt.timedelta(hours=2)).isoformat(); variants.append(p)
        p = alert(); p['alerts'][0]['startsAt'] = (NOW + dt.timedelta(hours=2)).isoformat(); variants.append(p)
        for payload in variants:
            self.assertEqual(app.mitigate(payload, NOW), 'ignored')
        api.assert_not_called()

    @patch.object(app, 'kube_request')
    def test_do_not_overlap_rollouts(self, api):
        obj = deployment(); obj['status']['updatedReplicas'] = 1
        api.return_value = obj
        self.assertEqual(app.mitigate(alert(), NOW), 'rollout-in-progress')
        self.assertEqual(api.call_count, 1)

    @patch.object(app, 'kube_request')
    def test_concurrent_notifications_restart_once(self, api):
        obj = deployment()
        def fake(method, path, payload=None):
            if method == 'PATCH':
                obj['spec']['template']['metadata']['annotations'] = payload[1]['value']
                return obj
            return copy.deepcopy(obj)
        api.side_effect = fake
        results = []
        threads = [threading.Thread(target=lambda: results.append(app.mitigate(alert(), NOW))) for _ in range(5)]
        for t in threads: t.start()
        for t in threads: t.join()
        self.assertEqual(results.count('restart-requested'), 1)
        self.assertEqual(results.count('cooldown'), 4)

    @patch.dict(os.environ, {'SELF_HEALING_TOKEN': 'x' * 32})
    @patch.object(app, 'mitigate', return_value='ignored')
    def test_http_authentication(self, mitigate):
        server = app.ThreadingHTTPServer(('127.0.0.1', 0), app.Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        url = 'http://127.0.0.1:%s/alerts' % server.server_port
        try:
            req = urllib.request.Request(url, data=b'{}', method='POST')
            with self.assertRaises(urllib.error.HTTPError) as raised:
                urllib.request.urlopen(req)
            self.assertEqual(raised.exception.code, 401)
            mitigate.assert_not_called()
            req.add_header('Authorization', 'Bearer ' + 'x' * 32)
            with urllib.request.urlopen(req) as response:
                self.assertEqual(json.load(response), {'result': 'ignored'})
        finally:
            server.shutdown(); server.server_close(); thread.join()


if __name__ == '__main__':
    unittest.main()
