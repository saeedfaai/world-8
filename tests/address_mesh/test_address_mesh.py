import unittest

from services.address_mesh.graph import bounded_impact
from services.address_mesh.indexer import index_python, index_sql, descriptor_to_card
from services.address_mesh.model import (
    AddressCard,
    AddressMeshError,
    AddressRelation,
    EntityKind,
    RelationType,
    semantic_address,
    stable_entity_id,
)
from services.address_mesh.routing import (
    DeliveryMode,
    Priority,
    RoutingEvent,
    Subscription,
    message_target_matches,
    resolve_subscriptions,
)
from services.address_mesh.selector import matches, resolve


class AddressMeshTests(unittest.TestCase):
    def make_card(self, *, name="update_price", tags=(), kind=EntityKind.FUNCTION, society="company"):
        entity_id = stable_entity_id(kind, f"artifact-pricing|{name}")
        return AddressCard(
            entity_id=entity_id,
            entity_kind=kind,
            canonical_address=semantic_address(
                ("society", society),
                ("project", "taminyaran"),
                ("artifact", "pricing"),
                ("symbol", name),
            ),
            society_id=society,
            project_id="taminyaran",
            artifact_id="artifact-pricing",
            tags=tags,
            role_refs=("MASON",),
        )

    def test_stable_id_does_not_embed_mutable_address(self):
        entity_a = stable_entity_id(EntityKind.FUNCTION, "artifact-x|semantic-symbol-17")
        entity_b = stable_entity_id(EntityKind.FUNCTION, "artifact-x|semantic-symbol-17")
        self.assertEqual(entity_a, entity_b)
        self.assertTrue(entity_a.startswith("W8-FN-"))

    def test_semantic_address_is_hierarchical(self):
        address = semantic_address(("society", "company"), ("artifact", "pricing"), ("symbol", "update_price"))
        self.assertEqual(address, "w8://society/company/artifact/pricing/symbol/update_price")

    def test_selector_filters_company_money_functions(self):
        money = self.make_card(tags=("RISK:MONEY", "DOMAIN:PRICING"))
        normal = self.make_card(name="health", tags=("DOMAIN:OPS",))
        selector = {"all": [{"society_id": "company"}, {"entity_kind": "FUNCTION"}, {"tags_all": ["RISK:MONEY"]}]}
        self.assertEqual([money.entity_id], [card.entity_id for card in resolve([normal, money], selector)])

    def test_selector_unknown_key_fails_closed(self):
        with self.assertRaises(AddressMeshError) as caught:
            matches(self.make_card(), {"magic_guess": "anything"})
        self.assertEqual(caught.exception.code, "UNKNOWN_SELECTOR_KEY")

    def test_message_target_can_address_tag_role_artifact_and_selector(self):
        card = self.make_card(tags=("CHANNEL:TELEGRAM", "RUNTIME:SUPABASE"))
        self.assertTrue(message_target_matches(card, {"type": "TAG", "tag": "CHANNEL:TELEGRAM"}))
        self.assertTrue(message_target_matches(card, {"type": "ROLE", "role_ref": "MASON"}))
        self.assertTrue(message_target_matches(card, {"type": "ARTIFACT_TREE", "artifact_id": "artifact-pricing"}))
        self.assertTrue(message_target_matches(card, {"type": "SELECTOR", "selector": {"tags_all": ["CHANNEL:TELEGRAM"]}}))

    def test_subscription_routes_one_source_event_without_duplicate_message_truth(self):
        card = self.make_card(tags=("CHANNEL:TELEGRAM", "RISK:SECURITY"))
        sub = Subscription(
            subscription_id="sub-telegram-security",
            subscriber_ref="mason-42",
            selector={"tags_all": ["CHANNEL:TELEGRAM"]},
            event_kinds=("ERROR", "SECURITY"),
            minimum_priority=Priority.HIGH,
            delivery_mode=DeliveryMode.ATTENTION,
        )
        event = RoutingEvent(
            source_kind="DIAGNOSTIC_INCIDENT",
            source_ref="incident-1",
            event_kind="SECURITY",
            priority=Priority.CRITICAL,
            affected_tags=("CHANNEL:TELEGRAM",),
        )
        matches_out = resolve_subscriptions(subscriptions=[sub], event=event, cards=[card])
        self.assertEqual(1, len(matches_out))
        self.assertEqual((card.entity_id,), matches_out[0].matched_entity_ids)
        self.assertEqual("incident-1", matches_out[0].source_ref)

    def test_low_priority_event_does_not_trigger_high_subscription(self):
        card = self.make_card(tags=("CHANNEL:TELEGRAM",))
        sub = Subscription(
            subscription_id="sub-high",
            subscriber_ref="guardian",
            selector={"tags_all": ["CHANNEL:TELEGRAM"]},
            event_kinds=("CHANGE",),
            minimum_priority=Priority.HIGH,
        )
        event = RoutingEvent("GITHUB_CHANGE", "commit-x", "CHANGE", Priority.NORMAL, affected_entity_ids=(card.entity_id,))
        self.assertEqual([], resolve_subscriptions(subscriptions=[sub], event=event, cards=[card]))

    def test_python_indexer_finds_functions_classes_methods_and_tests(self):
        source = '''\ndef update_price(value):\n    return value\n\nclass Bot:\n    def send(self, text):\n        return text\n\ndef test_price():\n    assert True\n'''
        symbols = index_python(source, path_ref="services/pricing.py", society_id="company", project_id="taminyaran", artifact_id="artifact-pricing")
        kinds = {s.entity_kind for s in symbols}
        self.assertIn(EntityKind.FUNCTION, kinds)
        self.assertIn(EntityKind.CLASS, kinds)
        self.assertIn(EntityKind.METHOD, kinds)
        self.assertIn(EntityKind.TEST, kinds)

    def test_sql_indexer_finds_db_objects(self):
        source = '''\ncreate table if not exists public.price_events(id text);\ncreate or replace function public.update_price() returns void language plpgsql as $$ begin null; end $$;\ncreate procedure public.refresh_prices() language sql as $$ select 1 $$;\n'''
        symbols = index_sql(source, path_ref="supabase/migrations/x.sql", society_id="company", project_id="taminyaran", artifact_id="artifact-db")
        kinds = {s.entity_kind for s in symbols}
        self.assertEqual({EntityKind.TABLE, EntityKind.DB_FUNCTION, EntityKind.RPC}, kinds)

    def test_descriptor_card_uses_symbol_address_not_line_number_identity(self):
        symbols = index_python("def f(x):\n    return x\n", path_ref="a.py", society_id="trading", project_id="forecast", artifact_id="artifact-a")
        card = descriptor_to_card(symbols[0], world_id="world-001", society_id="trading", project_id="forecast", artifact_id="artifact-a", module_name="a")
        self.assertIn("/symbol/", card.canonical_address)
        self.assertNotIn(":1", card.entity_id)

    def test_bounded_reverse_impact_finds_dependents_only_through_explicit_edges(self):
        a = self.make_card(name="base")
        b = self.make_card(name="consumer")
        c = self.make_card(name="outer")
        relations = [
            AddressRelation(b.entity_id, RelationType.DEPENDS_ON, a.entity_id, "code-shadow"),
            AddressRelation(c.entity_id, RelationType.CALLS, b.entity_id, "code-shadow"),
        ]
        impact = bounded_impact(origin_entity_id=a.entity_id, relations=relations, relation_types=[RelationType.DEPENDS_ON, RelationType.CALLS], max_depth=2, reverse=True)
        self.assertEqual([a.entity_id, b.entity_id, c.entity_id], [node.entity_id for node in impact])

    def test_unsupported_language_does_not_fake_symbols(self):
        from services.address_mesh.indexer import index_source
        self.assertEqual([], index_source("whatever", language="unknown", path_ref="x.bin", society_id="company", project_id="x", artifact_id="a"))


if __name__ == "__main__":
    unittest.main()
