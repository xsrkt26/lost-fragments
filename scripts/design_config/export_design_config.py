from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from design_config_common import (
    DesignConfigValidator,
    REPO_ROOT,
    load_json_file,
    parse_item_catalog,
    write_json_file,
)


SOURCE_JSON_FILES = {
    "schema": Path("data/config/design_config_schema.json"),
    "tools": Path("data/tools/tools.json"),
    "ornaments": Path("data/ornaments/ornaments.json"),
    "events": Path("data/events/events.json"),
    "routes": Path("data/routes/routes.json"),
    "stages": Path("data/stages/stages.json"),
    "economy": Path("data/economy/economy.json"),
}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Export normalized planner config bundle.")
    parser.add_argument("--root", default=str(REPO_ROOT), help="Repository root. Defaults to the current script's repo.")
    parser.add_argument("--out", default="package/design_config_export", help="Output directory.")
    parser.add_argument("--clean", action="store_true", help="Delete the output directory before writing.")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    out_dir = Path(args.out)
    if not out_dir.is_absolute():
        out_dir = root / out_dir
    out_dir = out_dir.resolve()

    validator = DesignConfigValidator(root)
    result = validator.validate_all()
    if result.error_count > 0:
        for message in result.messages:
            print(f"{message.level}: {message.path}: {message.message}")
        print(f"DESIGN_CONFIG_EXPORT: FAIL validation failed with {result.error_count} errors")
        return 1

    if args.clean and out_dir.exists():
        _safe_clean_output(root, out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    exported_files: list[str] = []
    for name, relative_path in SOURCE_JSON_FILES.items():
        source_path = root / relative_path
        data = load_json_file(source_path)
        target_path = out_dir / f"{name}.json"
        write_json_file(target_path, data)
        exported_files.append(target_path.relative_to(root).as_posix() if root in target_path.parents else str(target_path))

    item_catalog_path = out_dir / "item_catalog.json"
    item_catalog = parse_item_catalog(root)
    write_json_file(item_catalog_path, item_catalog)
    exported_files.append(item_catalog_path.relative_to(root).as_posix() if root in item_catalog_path.parents else str(item_catalog_path))

    manifest = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_root": str(root),
        "summary": result.summary,
        "files": exported_files,
    }
    write_json_file(out_dir / "manifest.json", manifest)

    print(f"DESIGN_CONFIG_EXPORT: PASS {out_dir}")
    print(f"DESIGN_CONFIG_EXPORT_FILES: {len(exported_files) + 1}")
    return 0


def _safe_clean_output(root: Path, out_dir: Path) -> None:
    protected = {root, root / "data", root / "src", root / "scripts", root / "tools", root / "test", root / "spec"}
    if out_dir in protected or root not in out_dir.parents:
        raise ValueError(f"Refusing to clean unsafe output path: {out_dir}")
    shutil.rmtree(out_dir)


if __name__ == "__main__":
    raise SystemExit(main())
