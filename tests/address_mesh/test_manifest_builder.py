import tempfile
import unittest
from pathlib import Path

from scripts.build_address_mesh_manifest import build_manifest


MAPPING = {
    "schema": "WORLD8_ADDRESS_INDEX_MAP/1.0",
    "world_id": "world-001",
    "default": {
        "society_id": "shared-core",
        "project_id": "engineering",
        "artifact_id": "artifact-test",
        "tags": ["DOMAIN:TEST"],
    },
    "rules": [],
}


class AddressManifestBuilderTests(unittest.TestCase):
    def test_repeated_sql_definition_is_one_entity_with_two_file_relations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "001_create.sql").write_text(
                "create or replace function public.foo() returns int language sql as $$ select 1 $$;",
                encoding="utf-8",
            )
            (root / "002_replace.sql").write_text(
                "create or replace function public.foo() returns int language sql as $$ select 2 $$;",
                encoding="utf-8",
            )

            rows = build_manifest(root, MAPPING)
            entities = [row for row in rows if row["record_type"] == "ENTITY"]
            db_functions = [row for row in entities if row["entity_kind"] == "DB_FUNCTION"]
            self.assertEqual(1, len(db_functions))
            function = db_functions[0]
            self.assertTrue(function["canonical_address"].endswith("/db-function/public.foo"))
            self.assertIn("002_replace.sql#public.foo", function["authoritative_ref"])

            definition_relations = [
                row
                for row in rows
                if row["record_type"] == "RELATION" and row["target_entity_id"] == function["entity_id"]
            ]
            self.assertEqual(2, len(definition_relations))
            self.assertEqual(
                {"git:001_create.sql", "git:002_replace.sql"},
                {row["source_ref"] for row in definition_relations},
            )

    def test_same_python_function_name_in_different_modules_stays_distinct(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.py").write_text("def run():\n    return 'a'\n", encoding="utf-8")
            (root / "b.py").write_text("def run():\n    return 'b'\n", encoding="utf-8")

            rows = build_manifest(root, MAPPING)
            functions = [
                row
                for row in rows
                if row["record_type"] == "ENTITY" and row["entity_kind"] == "FUNCTION"
            ]
            self.assertEqual(2, len(functions))
            self.assertEqual(2, len({row["entity_id"] for row in functions}))
            self.assertEqual(2, len({row["canonical_address"] for row in functions}))

    def test_manifest_contains_no_duplicate_entity_ids(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.sql").write_text(
                "create table if not exists public.x(id int);\n"
                "create or replace function public.f() returns int language sql as $$ select 1 $$;",
                encoding="utf-8",
            )
            (root / "b.sql").write_text(
                "create table if not exists public.x(id int);\n"
                "create or replace function public.f() returns int language sql as $$ select 2 $$;",
                encoding="utf-8",
            )
            rows = build_manifest(root, MAPPING)
            entity_ids = [row["entity_id"] for row in rows if row["record_type"] == "ENTITY"]
            self.assertEqual(len(entity_ids), len(set(entity_ids)))


if __name__ == "__main__":
    unittest.main()
