import unittest
from unittest.mock import patch

from app.routers import service_requests


class ServiceRequestResponseTests(unittest.TestCase):
    def test_completed_response_includes_safe_thinking_steps(self):
        out = service_requests._build_response(
            {
                "status": "completed",
                "intent": {
                    "intent_type": "book",
                    "service_type": "plumber",
                    "area": "F-10",
                    "scheduled_at": "2026-05-20T09:00:00+05:00",
                    "confidence": 0.9,
                    "language": "en",
                },
                "selected": {
                    "id": "provider-1",
                    "name": "Ali Plumbing",
                    "category": "plumber",
                    "area": "F-10",
                    "rating": 4.8,
                    "distance_km": 1.2,
                },
                "reasoning": "Ali Plumbing was selected for rating and distance.",
                "formatted_response": "Done! Ali Plumbing, 1.2 km, 4.8★, tomorrow 9 AM.",
                "trace_steps": [
                    {"node": "intent_parser", "ms": 12, "output": {}},
                    {"node": "ranking", "ms": 8, "output": {}},
                    {"node": "decision_and_format", "ms": 21, "output": {}},
                    {"node": "booking_step", "ms": 18, "output": {}},
                ],
            },
            "conversation-1",
        )

        self.assertTrue(out.thinking_steps)
        self.assertEqual(out.thinking_steps[0].key, "intent_parser")
        self.assertEqual(out.thinking_steps[-1].status, "done")
        self.assertNotIn("reasoning", out.thinking_steps[0].title.lower())

    def test_clarification_response_marks_last_step_waiting(self):
        out = service_requests._build_response(
            {
                "status": "needs_clarification",
                "question": "Which sector?",
                "intent": {
                    "intent_type": "book",
                    "service_type": "electrician",
                    "confidence": 0.7,
                    "language": "en",
                },
                "trace_steps": [
                    {"node": "intent_parser", "ms": 10, "output": {}},
                    {"node": "clarifier", "ms": 15, "output": {}},
                ],
            },
            "conversation-2",
        )

        self.assertEqual(out.status, "needs_clarification")
        self.assertTrue(out.thinking_steps)
        self.assertEqual(out.thinking_steps[-1].key, "clarifier")
        self.assertEqual(out.thinking_steps[-1].status, "waiting")

    def test_abandoned_response_includes_safe_terminal_step(self):
        out = service_requests._build_response(
            {
                "status": "abandoned",
                "reason": "Could not understand your request after several tries.",
                "intent": {"intent_type": "book", "confidence": 0.0, "language": "en"},
                "trace_steps": [
                    {"node": "intent_parser", "ms": 9, "output": {}},
                    {"node": "give_up", "ms": 5, "output": {}},
                ],
            },
            "conversation-3",
        )

        self.assertEqual(out.status, "abandoned")
        self.assertTrue(out.thinking_steps)
        self.assertEqual(out.thinking_steps[-1].key, "give_up")
        self.assertEqual(out.thinking_steps[-1].status, "stopped")

    def test_idempotency_replay_preserves_thinking_steps(self):
        with patch.object(
            service_requests.T,
            "find_trace_by_idempotency",
            return_value={
                "id": "trace-1",
                "conversation_id": "conversation-4",
                "parsed_intent": {
                    "intent_type": "book",
                    "service_type": "plumber",
                    "area": "F-10",
                    "confidence": 0.9,
                    "language": "en",
                },
                "reasoning": "Ali Plumbing was selected for rating and distance.",
                "steps": [
                    {"node": "intent_parser", "ms": 11, "output": {}},
                    {"node": "booking_step", "ms": 13, "output": {}},
                ],
            },
        ):
            out = service_requests._idempotency_replay("user-1", "key-1")

        self.assertIsNotNone(out)
        self.assertTrue(out.thinking_steps)
        self.assertEqual(out.thinking_steps[-1].status, "done")


if __name__ == "__main__":
    unittest.main()
