import unittest

from services.address_mesh.indexer import index_python, descriptor_to_card
from services.address_mesh.model import AddressMeshError
from services.address_mesh.rebind import explicit_rebind


class AddressMeshRebindTests(unittest.TestCase):
    def test_explicit_rename_preserves_entity_id_and_creates_alias(self):
        old_desc = index_python(
            "def old_name(x):\n    return x\n",
            path_ref="services/a.py",
            society_id="company",
            project_id="taminyaran",
            artifact_id="artifact-pricing",
        )[0]
        old_card = descriptor_to_card(
            old_desc,
            world_id="world-001",
            society_id="company",
            project_id="taminyaran",
            artifact_id="artifact-pricing",
            module_name="services.a",
        )
        new_desc = index_python(
            "def new_name(x):\n    return x\n",
            path_ref="services/b.py",
            society_id="company",
            project_id="taminyaran",
            artifact_id="artifact-pricing",
        )[0]
        decision = explicit_rebind(
            previous_card=old_card,
            new_descriptor=new_desc,
            world_id="world-001",
            society_id="company",
            project_id="taminyaran",
            artifact_id="artifact-pricing",
            module_name="services.b",
            source_ref="git:rename-commit-1",
            evidence_refs=("review:rename-confirmed",),
        )
        self.assertEqual(old_card.entity_id, decision.new_card.entity_id)
        self.assertEqual(old_card.canonical_address, decision.alias.alias_address)
        self.assertNotEqual(old_card.canonical_address, decision.new_card.canonical_address)
        self.assertEqual(old_card.revision + 1, decision.new_card.revision)

    def test_rebind_without_evidence_fails_closed(self):
        old_desc = index_python(
            "def a():\n    pass\n",
            path_ref="a.py",
            society_id="company",
            project_id="x",
            artifact_id="artifact-a",
        )[0]
        old_card = descriptor_to_card(
            old_desc,
            world_id="world-001",
            society_id="company",
            project_id="x",
            artifact_id="artifact-a",
            module_name="a",
        )
        new_desc = index_python(
            "def b():\n    pass\n",
            path_ref="b.py",
            society_id="company",
            project_id="x",
            artifact_id="artifact-a",
        )[0]
        with self.assertRaises(AddressMeshError) as caught:
            explicit_rebind(
                previous_card=old_card,
                new_descriptor=new_desc,
                world_id="world-001",
                society_id="company",
                project_id="x",
                artifact_id="artifact-a",
                module_name="b",
                source_ref="git:x",
                evidence_refs=(),
            )
        self.assertEqual("REBIND_EVIDENCE_REQUIRED", caught.exception.code)

    def test_cross_artifact_move_requires_explicit_override(self):
        old_desc = index_python(
            "def a():\n    pass\n",
            path_ref="a.py",
            society_id="company",
            project_id="x",
            artifact_id="artifact-a",
        )[0]
        old_card = descriptor_to_card(
            old_desc,
            world_id="world-001",
            society_id="company",
            project_id="x",
            artifact_id="artifact-a",
            module_name="a",
        )
        new_desc = index_python(
            "def a():\n    pass\n",
            path_ref="b.py",
            society_id="company",
            project_id="x",
            artifact_id="artifact-b",
        )[0]
        with self.assertRaises(AddressMeshError) as caught:
            explicit_rebind(
                previous_card=old_card,
                new_descriptor=new_desc,
                world_id="world-001",
                society_id="company",
                project_id="x",
                artifact_id="artifact-b",
                module_name="b",
                source_ref="git:move",
                evidence_refs=("review:move",),
            )
        self.assertEqual("CROSS_ARTIFACT_REBIND_REQUIRES_EXPLICIT_GOVERNED_OVERRIDE", caught.exception.code)


if __name__ == "__main__":
    unittest.main()
