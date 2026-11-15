"""Runs in the Python runtime with the service requirements installed."""
import importlib.util
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock, patch
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

ROOT = Path(__file__).resolve().parents[2]


class PythonTelemetryTest(unittest.TestCase):
    def test_analytics_extracts_producer_and_instruments_dynamodb(self):
        exporter = InMemorySpanExporter()
        provider = TracerProvider()
        provider.add_span_processor(SimpleSpanProcessor(exporter))
        trace.set_tracer_provider(provider)
        sys.path.insert(0, str(ROOT / 'toggle-master/analytics-service'))
        spec = importlib.util.spec_from_file_location('analytics_test', ROOT / 'toggle-master/analytics-service/app.py')
        module = importlib.util.module_from_spec(spec)
        with patch.dict(os.environ, {'AWS_REGION': 'us-east-1', 'AWS_SQS_URL': 'test', 'AWS_DYNAMODB_TABLE': 'test', 'OTEL_EXPORTER_OTLP_ENDPOINT': ''}), patch('boto3.Session'), patch('threading.Thread.start'):
            spec.loader.exec_module(module)
        trace_id = '0123456789abcdef0123456789abcdef'
        message = {'MessageId': 'test', 'ReceiptHandle': 'receipt',
                   'MessageAttributes': {'traceparent': {'StringValue': '00-' + trace_id + '-0123456789abcdef-01'}},
                   'Body': '{"user_id":"test","flag_name":"test","result":true,"timestamp":"2026-01-01"}'}
        module.process_message(message)
        module.dynamodb_client.put_item.assert_called_once()
        module.sqs_client.delete_message.assert_called_once()
        span = next(s for s in exporter.get_finished_spans() if s.name == 'evaluations process')
        self.assertEqual(format(span.context.trace_id, '032x'), trace_id)
        self.assertEqual(format(span.parent.span_id, '016x'), '0123456789abcdef')
        self.assertEqual(span.kind, trace.SpanKind.CONSUMER)
        module.dynamodb_client.put_item.side_effect = RuntimeError('simulated failure')
        module.sqs_client.delete_message.reset_mock()
        module.process_message(message)
        module.sqs_client.delete_message.assert_not_called()
        self.assertEqual(exporter.get_finished_spans()[-1].status.status_code, trace.StatusCode.ERROR)


if __name__ == '__main__':
    unittest.main()
