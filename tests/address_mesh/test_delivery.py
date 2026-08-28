import unittest

from services.address_mesh.delivery import AttentionCommand, ContextDeliveryCommand, materialize_delivery
from services.address_mesh.model import AddressMeshError
from services.address_mesh.routing import DeliveryMatch, DeliveryMode, Priority, RoutingEvent


class AddressMeshDeliveryTests(unittest.TestCase):
    def _match(self, mode: DeliveryMode) -> DeliveryMatch:
        return DeliveryMatch(
            delivery_receipt_id="delivery-abc",
            subscriber_ref="mason-42",
            subscription_id="sub-1",
            source_kind="DIAGNOSTIC_INCIDENT",
            source_ref="incident-1",
            event_kind="ERROR",
            delivery_mode=mode,
            matched_entity_ids=("W8-FN-AAA", "W8-FN-BBB"),
        )

    def _event(self) -> RoutingEvent:
        return RoutingEvent(
            source_kind="DIAGNOSTIC_INCIDENT",
            source_ref="incident-1",
            event_kind="ERROR",
            priority=Priority.HIGH,
            affected_entity_ids=("W8-FN-AAA",),
            metadata={"title": "Known pricing failure", "summary": "Read incident before editing", "action_kind": "ACK"},
        )

    def test_attention_delivery_reuses_delivery_receipt_as_idempotency_key(self):
        command = materialize_delivery(match=self._match(DeliveryMode.ATTENTION), event=self._event())
        self.assertIsInstance(command, AttentionCommand)
        self.assertEqual("delivery-abc", command.idempotency_key)
        self.assertEqual("mason-42", command.recipient_ref)
        self.assertEqual("Known pricing failure", command.title)

    def test_mason_preflight_delivery_is_context_not_new_message(self):
        command = materialize_delivery(match=self._match(DeliveryMode.MASON_PREFLIGHT), event=self._event())
        self.assertIsInstance(command, ContextDeliveryCommand)
        self.assertEqual(DeliveryMode.MASON_PREFLIGHT, command.delivery_mode)

    def test_source_mismatch_fails_closed(self):
        event = RoutingEvent("GITHUB_CHANGE", "commit-2", "CHANGE", Priority.NORMAL)
        with self.assertRaises(AddressMeshError) as caught:
            materialize_delivery(match=self._match(DeliveryMode.ATTENTION), event=event)
        self.assertEqual("DELIVERY_SOURCE_MISMATCH", caught.exception.code)


if __name__ == "__main__":
    unittest.main()
