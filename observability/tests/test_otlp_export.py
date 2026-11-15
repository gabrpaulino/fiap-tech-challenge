"""Exercise real Python OTLP exporters against a local receiver, without APM access."""
import subprocess
import sys
import unittest
from pathlib import Path


class OTLPExportTest(unittest.TestCase):
    def test_exports_three_signals_with_http_protobuf(self):
        source = r'''
import http.server
import threading
import os
import logging
import sys
from opentelemetry import trace, metrics
from opentelemetry.proto.collector.metrics.v1.metrics_service_pb2 import ExportMetricsServiceRequest
from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import ExportTraceServiceRequest
from opentelemetry.proto.collector.logs.v1.logs_service_pb2 import ExportLogsServiceRequest
payloads = {}
class Receiver(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        payloads.setdefault(self.path, []).append(self.rfile.read(int(self.headers['Content-Length'])))
        self.send_response(200)
        self.send_header('Content-Length', '0')
        self.end_headers()
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Receiver)
threading.Thread(target=server.serve_forever, daemon=True).start()
os.environ['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://127.0.0.1:' + str(server.server_port)
sys.path.insert(0, 'toggle-master/analytics-service')
from telemetry import setup_telemetry
setup_telemetry('analytics-service')
logging.getLogger().setLevel(logging.INFO)
with trace.get_tracer('test').start_as_current_span('export-test') as span:
    trace_id = span.get_span_context().trace_id
    logging.info('correlated OTLP log')
    metrics.get_meter('test').create_counter('tm.http.requests').add(1, {'http.status_code': 503})
trace.get_tracer_provider().force_flush()
metrics.get_meter_provider().force_flush()
for handler in logging.getLogger().handlers:
    handler.flush()
assert all(p in payloads for p in ['/v1/traces', '/v1/metrics', '/v1/logs']), payloads.keys()
traces = ExportTraceServiceRequest.FromString(payloads['/v1/traces'][0])
assert int.from_bytes(traces.resource_spans[0].scope_spans[0].spans[0].trace_id, 'big') == trace_id
logs = ExportLogsServiceRequest.FromString(payloads['/v1/logs'][0])
assert int.from_bytes(logs.resource_logs[0].scope_logs[0].log_records[0].trace_id, 'big') == trace_id
metric_data = ExportMetricsServiceRequest.FromString(payloads['/v1/metrics'][0])
assert any(m.name == 'tm.http.requests' for r in metric_data.resource_metrics for s in r.scope_metrics for m in s.metrics)
# Shutdown exporters before stopping the test receiver.
for handler in logging.getLogger().handlers:
    if hasattr(handler, '_logger_provider'): handler._logger_provider.shutdown()
trace.get_tracer_provider().shutdown()
metrics.get_meter_provider().shutdown()
server.shutdown()
server.server_close()
'''
        result = subprocess.run([sys.executable, '-c', source],
                                cwd=Path(__file__).resolve().parents[2],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
