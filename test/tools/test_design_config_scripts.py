from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = REPO_ROOT / "scripts/design_config"
sys.path.insert(0, str(SCRIPT_DIR))

from design_config_common import DesignConfigValidator, load_json_file, parse_item_catalog
from export_design_config import main as export_main


class DesignConfigScriptTests(unittest.TestCase):
    def test_current_design_config_validates(self) -> None:
        result = DesignConfigValidator(REPO_ROOT).validate_all()

        self.assertEqual(result.error_count, 0, [message.message for message in result.messages])
        self.assertGreaterEqual(result.summary.get("items", 0), 1)
        self.assertEqual(result.summary.get("tools", 0), len(load_json_file(REPO_ROOT / "data/tools/tools.json")))
        self.assertEqual(result.summary.get("ornaments", 0), len(load_json_file(REPO_ROOT / "data/ornaments/ornaments.json")))
        stages = load_json_file(REPO_ROOT / "data/stages/stages.json").get("stages", {})
        self.assertEqual(result.summary.get("stages", 0), len(stages))

    def test_item_catalog_export_reads_godot_resources(self) -> None:
        catalog = parse_item_catalog(REPO_ROOT)
        ids = {entry["id"] for entry in catalog}

        self.assertIn("root_dream", ids)
        self.assertIn("paper_ball", ids)

    def test_export_writes_bundle_manifest_and_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "design_config_export"
            exit_code = export_main(["--root", str(REPO_ROOT), "--out", str(out_dir)])

            self.assertEqual(exit_code, 0)
            manifest = load_json_file(out_dir / "manifest.json")
            self.assertIn("summary", manifest)
            self.assertTrue((out_dir / "item_catalog.json").exists())
            self.assertTrue((out_dir / "economy.json").exists())
            self.assertTrue((out_dir / "stages.json").exists())


if __name__ == "__main__":
    unittest.main()
