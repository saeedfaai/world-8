import unittest

from services.address_mesh.adapters import diagnostic_event, provider_quota_event
from services.address_mesh.context import AddressContextBundle, DiagnosticRecord, MessageRecord, build_context_bundle
from services.address_mesh.model import AddressCard, EntityKind, semantic_address, stable_entity_id
from services.address_mesh.routing import DeliveryMode, Subscription


class AddressMeshContextTests(unittest.TestCase):
    def card(self):
        return AddressCard(
            entity_id=stable_entity_id(EntityKind.FUNCTION, "telegram|send_price"),
            entity_kind=EntityKind.FUNCTION,
            canonical_address=semantic_address(
                ("society", "company"),
                ("project", "taminyaran"),
                ("artifact", "sales-bot"),
                ("symbol", "send_price"),
            ),
            society_id="company",
            project_id="taminyaran",
            artifact_id="artifact-sales-bot",
            owner_ref="mason-42",
            role_refs=("MASON",),
            # Both new namespaced and existing flat Diagnostic Memory tags are legal.
            tags=("CHANNEL:TELEGRAM", "RUNTIME:SUPABASE", "SUPABASE", "RENDER"),
        )

    def test_legacy_flat_diagnostic_tags_remain_queryable(self):
        card = self.card()
        self.assertIn("SUPABASE", card.tags)
        self.assertIn("RENDER", card.tags)

    def test_symbol_targeted_message_appears_when_mason_enters_symbol(self):
        card = self.card()
        message = MessageRecord(
            message_id="msg-symbol-warning",
            sender_ref="guardian",
            direct_recipient_refs=(),
            state="SENT",
            priority="HIGH",
            targets=({"type": "ENTITY_ID", "entity_id": card.entity_id},),
        )
        bundle = build_context_bundle(card=card, actor_ref="mason-99", messages=[message])
        self.assertEqual(("msg-symbol-warning",), bundle.targeted_message_ids)

    def test_tag_broadcast_message_appears_without_duplicate_message_rows(self):
        card = self.card()
        one_message = MessageRecord(
            message_id="msg-all-telegram",
            sender_ref="human-root",
            direct_recipient_refs=(),
            state="SENT",
            priority="HIGH",
            targets=({"type": "TAG", "tag": "CHANNEL:TELEGRAM"},),
        )
        bundle = build_context_bundle(card=card, actor_ref="mason-99", messages=[one_message])
        self.assertEqual(("msg-all-telegram",), bundle.targeted_message_ids)

    def test_existing_diagnostic_tag_surfaces_in_context(self):
        card = self.card()
        diagnostic = DiagnosticRecord(
            diagnostic_ref="incident-edge-html",
            tags=("SUPABASE", "RENDER"),
            state="OPEN",
            severity="HIGH",
        )
        bundle = build_context_bundle(card=card, actor_ref="mason-99", diagnostics=[diagnostic])
        self.assertEqual(("incident-edge-html",), bundle.diagnostic_refs)

    def test_subscription_selector_is_visible_in_context(self):
        card = self.card()
        sub = Subscription(
            subscription_id="sub-telegram-errors",
            subscriber_ref="mason-99",
            selector={"tags_all": ["CHANNEL:TELEGRAM"]},
            event_kinds=("ERROR", "CHANGE"),
            delivery_mode=DeliveryMode.MASON_PREFLIGHT,
        )
        bundle = build_context_bundle(card=card, actor_ref="mason-99", subscriptions=[sub])
        self.assertEqual(("sub-telegram-errors",), bundle.matching_subscription_ids)

    def test_provider_quota_event_has_queryable_provider_and_quota_tags(self):
        event = provider_quota_event(receipt_ref="provider-capacity-1", provider="openai", exhausted=True)
        self.assertIn("PROVIDER:OPENAI", event.affected_tags)
        self.assertIn("RISK:QUOTA", event.affected_tags)
        self.assertEqual("QUOTA", event.event_kind)

    def test_diagnostic_adapter_preserves_legacy_tags(self):
        event = diagnostic_event(incident_id="incident-1", tags=("SUPABASE", "RENDER"), severity="HIGH")
        self.assertIn("SUPABASE", event.affected_tags)
        self.assertIn("RENDER", event.affected_tags)


if __name__ == "__main__":
    unittest.main()
