import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import patch
from unittest.mock import Mock

from app.agents import nodes, tools


class AgentIntentAndAvailabilityTests(unittest.TestCase):
    def test_intent_parser_recovers_roman_urdu_service_area_and_now(self):
        nodes._cached_intent.cache_clear()

        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "F-11 mein electrician chahiye abhi",
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertEqual(intent["service_type"], "electrician")
        self.assertEqual(intent["area"], "F-11")
        self.assertEqual(intent["language"], "roman_ur")
        self.assertIsNone(intent.get("scheduled_at"))
        self.assertEqual(intent["preferred_time_text"], "abhi")
        self.assertGreaterEqual(intent["confidence"], 0.7)

    def test_intent_parser_recovers_english_service_area_and_tomorrow_time(self):
        nodes._cached_intent.cache_clear()

        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "I need a plumber in F-10 tomorrow at 9am",
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertEqual(intent["service_type"], "plumber")
        self.assertEqual(intent["area"], "F-10")
        self.assertEqual(intent["language"], "en")
        scheduled_at = datetime.fromisoformat(intent["scheduled_at"])
        self.assertEqual(scheduled_at.hour, 9)
        self.assertEqual(scheduled_at.minute, 0)
        self.assertEqual(scheduled_at.utcoffset().total_seconds(), 5 * 60 * 60)
        self.assertEqual(nodes.route_after_intent(out), "provider_caller")

    def test_intent_parser_uses_llm_first_for_common_request(self):
        with patch.object(
            nodes,
            "_cached_intent",
            return_value={
                "intent_type": "book",
                "service_type": "ac_technician",
                "area": "G-13",
                "scheduled_at": "2026-05-19T09:00:00+05:00",
                "selected_provider": None,
                "confidence": 0.95,
                "language": "roman_ur",
            },
        ) as cached_intent:
            out = nodes.intent_parser(
                {
                    "input_text": "Mujhe kal subah G-13 mein AC technician chahiye",
                    "trace_steps": [],
                }
            )

        cached_intent.assert_called_once()
        intent = out["intent"]
        self.assertEqual(intent["service_type"], "ac_technician")
        self.assertEqual(intent["area"], "G-13")
        self.assertIsNotNone(intent["scheduled_at"])

    def test_intent_parser_does_not_merge_fallback_over_successful_llm_output(self):
        with patch.object(
            nodes,
            "_cached_intent",
            return_value={
                "intent_type": "book",
                "service_type": "unknown",
                "area": None,
                "scheduled_at": None,
                "selected_provider": None,
                "confidence": 0.2,
                "language": "en",
            },
        ):
            out = nodes.intent_parser(
                {
                    "input_text": "F-11 mein electrician chahiye abhi",
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertIsNone(intent.get("service_type"))
        self.assertIsNone(intent.get("area"))
        self.assertIsNone(intent.get("scheduled_at"))
        self.assertNotIn("preferred_time_text", intent)
        self.assertEqual(intent["confidence"], 0.2)

    def test_intent_parser_falls_back_when_llm_is_unavailable(self):
        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "Mujhe kal subah G-13 mein AC technician chahiye",
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertEqual(intent["service_type"], "ac_technician")
        self.assertEqual(intent["area"], "G-13")
        self.assertIsNotNone(intent["scheduled_at"])

    def test_service_and_area_without_time_does_not_invent_default_time(self):
        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "E-11 m plumber",
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertEqual(intent["service_type"], "plumber")
        self.assertEqual(intent["area"], "E-11")
        self.assertIsNone(intent.get("scheduled_at"))

    def test_abhi_request_asks_provider_and_time_before_booking(self):
        intent = {
            "intent_type": "book",
            "service_type": "electrician",
            "area": "F-11",
            "preferred_time_text": "abhi",
            "language": "roman_ur",
            "confidence": 0.75,
        }
        ranked = [
            {"id": "p1", "name": "Alpha Electric", "rating": 4.8},
            {"id": "p2", "name": "Beta Electric", "rating": 5.0},
        ]

        self.assertIn("scheduled_at", nodes._missing_slots(intent))
        self.assertEqual(
            nodes.route_after_ranking({"intent": intent, "ranked": ranked}),
            "clarifier",
        )
        question = nodes._fallback_clarifier_question(
            intent,
            nodes._missing_slots(intent),
            no_results=False,
            available_areas=[],
            ranked=ranked,
        )

        self.assertIn("1. Alpha Electric", question)
        self.assertIn("2. Beta Electric", question)
        self.assertIn("kis time", question)

    def test_first_one_selection_resolves_without_llm(self):
        ranked = [
            {"id": "p1", "name": "Alpha Electric", "rating": 4.8},
            {"id": "p2", "name": "Beta Electric", "rating": 5.0},
        ]

        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "F-11 mein electrician chahiye abhi",
                    "intent": {
                        "intent_type": "book",
                        "service_type": "electrician",
                        "area": "F-11",
                        "preferred_time_text": "abhi",
                    },
                    "ranked": ranked,
                    "clarification_context": ["first one"],
                    "trace_steps": [],
                }
            )

        self.assertEqual(out["intent"]["selected_provider"], "Alpha Electric")
        self.assertNotEqual(out["intent"]["selected_provider"], "Beta Electric")

    def test_numeric_provider_and_short_roman_urdu_time_resolve_without_llm(self):
        ranked = [
            {"id": "p1", "name": "Alpha Electric", "rating": 4.8},
            {"id": "p2", "name": "Beta Electric", "rating": 5.0},
        ]

        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "F-11 mein electrician chahiye abhi",
                    "intent": {
                        "intent_type": "book",
                        "service_type": "electrician",
                        "area": "F-11",
                        "preferred_time_text": "abhi",
                    },
                    "ranked": ranked,
                    "clarification_context": ["1 aur 2 bjy"],
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertEqual(intent["selected_provider"], "Alpha Electric")
        scheduled_at = datetime.fromisoformat(intent["scheduled_at"])
        self.assertEqual(scheduled_at.hour, 14)
        self.assertEqual(scheduled_at.minute, 0)
        self.assertEqual(
            scheduled_at.date(),
            (datetime.now(nodes._PKT) + timedelta(days=1)).date(),
        )

    def test_provider_name_selection_resolves_via_fallback_parser(self):
        # Reproduces the reported loop: user picks a provider by NAME and the LLM
        # is unavailable, so the local parser runs. Without the deterministic net
        # selected_provider stays None and the clarifier re-shows the same list.
        ranked = [
            {"id": "p1", "name": "A.k AC Technician & Electrition Islamabad",
             "rating": 5.0},
            {"id": "p2", "name": "Cool Line HVAC Islamabad", "rating": 4.9},
        ]

        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "Mujhay kal subah f11 main AC teknishon ki zaroorat hai",
                    "intent": {
                        "intent_type": "book",
                        "service_type": "ac_technician",
                        "area": "F-11",
                        "scheduled_at": "2026-06-03T09:00:00+05:00",
                    },
                    "ranked": ranked,
                    "clarification_context": ["Cool line book karna hai"],
                    "trace_steps": [],
                }
            )

        self.assertEqual(out["intent"]["selected_provider"], "Cool Line HVAC Islamabad")
        self.assertEqual(nodes.route_after_intent(out), "provider_caller")

    def test_provider_name_selection_resolves_when_llm_returns_none(self):
        # Production path: the LLM succeeds but leaves selected_provider null
        # because it never saw the numbered list. The net must still resolve it.
        ranked = [
            {"id": "p1", "name": "A.k AC Technician & Electrition Islamabad",
             "rating": 5.0},
            {"id": "p2", "name": "Cool Line HVAC Islamabad", "rating": 4.9},
        ]

        with patch.object(
            nodes,
            "_cached_intent",
            return_value={
                "intent_type": "book",
                "service_type": "ac_technician",
                "area": "F-11",
                "scheduled_at": None,
                "selected_provider": None,
                "confidence": 0.6,
                "language": "roman_ur",
            },
        ):
            out = nodes.intent_parser(
                {
                    "input_text": "Mujhay kal subah f11 main AC teknishon ki zaroorat hai",
                    "intent": {
                        "intent_type": "book",
                        "service_type": "ac_technician",
                        "area": "F-11",
                        "scheduled_at": "2026-06-03T09:00:00+05:00",
                    },
                    "ranked": ranked,
                    "clarification_context": ["Cool line book karna hai"],
                    "trace_steps": [],
                }
            )

        intent = out["intent"]
        self.assertEqual(intent["selected_provider"], "Cool Line HVAC Islamabad")
        # The earlier-resolved time must survive so the run can book.
        self.assertEqual(intent["scheduled_at"], "2026-06-03T09:00:00+05:00")

    def test_non_selection_reply_does_not_match_a_provider(self):
        # A reply that changes the area must not be coerced into a provider pick.
        ranked = [
            {"id": "p1", "name": "Alpha Electric", "rating": 4.8},
            {"id": "p2", "name": "Beta Electric", "rating": 5.0},
        ]

        with patch.object(nodes, "_cached_intent", side_effect=RuntimeError("quota")):
            out = nodes.intent_parser(
                {
                    "input_text": "F-11 mein electrician chahiye",
                    "intent": {
                        "intent_type": "book",
                        "service_type": "electrician",
                        "area": "F-11",
                    },
                    "ranked": ranked,
                    "clarification_context": ["G-13 try karein"],
                    "trace_steps": [],
                }
            )

        # Area pivoted to G-13 → no stale/garbage provider selection.
        self.assertEqual(out["intent"]["area"], "G-13")
        self.assertIsNone(out["intent"].get("selected_provider"))

    def test_match_reply_to_provider_unit(self):
        ranked = [
            {"id": "p1", "name": "A.k AC Technician & Electrition Islamabad"},
            {"id": "p2", "name": "Cool Line HVAC Islamabad"},
        ]
        self.assertEqual(
            nodes._match_reply_to_provider("Cool line book karna hai", ranked)["id"],
            "p2",
        )
        self.assertEqual(
            nodes._match_reply_to_provider("the second one please", ranked)["id"],
            "p2",
        )
        # No identifying tokens → no match.
        self.assertIsNone(nodes._match_reply_to_provider("kal subah", ranked))

    def test_clarifier_falls_back_to_specific_no_results_message_without_llm(self):
        with patch.object(nodes, "get_llm", side_effect=RuntimeError("quota")):
            question = nodes._build_clarifier_question(
                intent={
                    "intent_type": "book",
                    "service_type": "ac_technician",
                    "area": "G-13",
                    "scheduled_at": "2026-05-19T09:00:00+05:00",
                    "language": "roman_ur",
                },
                missing=["selected_provider"],
                no_results=True,
                available_areas=["F-10", "I-8"],
                ranked=[],
                input_text="Mujhe kal subah G-13 mein AC technician chahiye",
            )

        self.assertIn("G-13", question)
        self.assertIn("AC technician", question)
        self.assertIn("F-10", question)
        self.assertNotIn("Kya service chahiye", question)

    def test_no_results_handler_stops_auto_expanding_into_tried_areas(self):
        # Guards against the area ping-pong loop: providers busy in two areas
        # must not bounce nearby[0] → other → back forever.
        fake_tools = SimpleNamespace(
            find_available_areas=SimpleNamespace(
                invoke=Mock(return_value=["F-11", "D-12"])
            ),
            add_to_waitlist=SimpleNamespace(invoke=Mock()),
        )
        with patch.object(nodes, "T", fake_tools):
            first = nodes.no_results_handler(
                {
                    "user_id": "u",
                    "intent": {"service_type": "ac_technician", "area": "G-13"},
                    "clarification_context": [],
                    "trace_steps": [],
                }
            )
            # First miss auto-expands to the first untried area.
            self.assertEqual(first.get("auto_search_area"), "F-11")

            exhausted = nodes.no_results_handler(
                {
                    "user_id": "u",
                    "intent": {"service_type": "ac_technician", "area": "D-12"},
                    "clarification_context": ["F-11", "D-12"],
                    "trace_steps": [],
                }
            )
            # Both areas already tried → stop and hand off to the clarifier.
            self.assertIsNone(exhausted.get("auto_search_area"))
            self.assertNotIn("intent", exhausted)

    def test_clarifier_auto_expand_passthrough_counts_a_round(self):
        # The auto-expand pass-through skips the interrupt, so it must still
        # advance clarify_rounds or it bypasses the MAX_CLARIFY_ROUNDS cap.
        fake_tools = SimpleNamespace(
            upsert_conversation=SimpleNamespace(invoke=Mock()),
        )
        with patch.object(nodes, "T", fake_tools):
            out = nodes.clarifier(
                {
                    "conversation_id": "c",
                    "user_id": "u",
                    "intent": {"service_type": "ac_technician", "area": "F-11"},
                    "auto_search_area": "F-11",
                    "clarify_rounds": 2,
                    "clarification_context": [],
                    "trace_steps": [],
                }
            )
        self.assertEqual(out["clarify_rounds"], 3)
        self.assertIsNone(out["auto_search_area"])

    def test_provider_open_at_requires_requested_time_inside_hours(self):
        provider = {
            "available_hours": {
                "tue": ["09:00-17:00"],
            }
        }

        self.assertTrue(
            tools.is_provider_open_at(provider, "2026-05-19T10:00:00+05:00")
        )
        self.assertFalse(
            tools.is_provider_open_at(provider, "2026-05-19T18:00:00+05:00")
        )

    def test_booking_step_asks_again_when_selected_provider_is_closed(self):
        selected = {
            "id": "provider-1",
            "name": "Zahid Electric",
            "category": "electrician",
            "area": "F-11",
            "available_hours": {"tue": ["09:00-17:00"]},
        }

        fake_tools = SimpleNamespace(
            is_provider_open_at=tools.is_provider_open_at,
            get_provider_free_slots=SimpleNamespace(invoke=Mock(return_value=[])),
            insert_agent_trace=SimpleNamespace(invoke=Mock()),
            insert_booking=SimpleNamespace(invoke=Mock()),
        )

        with patch.object(nodes, "T", fake_tools):
            out = nodes.booking_step(
                {
                    "user_id": "user-1",
                    "conversation_id": "conversation-1",
                    "input_text": "F-11 mein electrician chahiye",
                    "intent": {
                        "service_type": "electrician",
                        "area": "F-11",
                        "scheduled_at": "2026-05-19T18:00:00+05:00",
                    },
                    "selected": selected,
                    "ranked": [selected],
                    "trace_steps": [],
                }
            )

        self.assertIsNone(out["status"])
        self.assertIn("not available", out["question"])
        self.assertIsNone(out["intent"]["scheduled_at"])
        fake_tools.insert_agent_trace.invoke.assert_not_called()
        fake_tools.insert_booking.invoke.assert_not_called()


if __name__ == "__main__":
    unittest.main()
