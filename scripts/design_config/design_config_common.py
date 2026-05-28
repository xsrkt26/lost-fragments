from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = Path("data/config/design_config_schema.json")


@dataclass
class ValidationMessage:
    level: str
    path: str
    message: str


@dataclass
class ValidationResult:
    messages: list[ValidationMessage] = field(default_factory=list)
    summary: dict[str, int] = field(default_factory=dict)

    @property
    def error_count(self) -> int:
        return sum(1 for msg in self.messages if msg.level == "ERROR")

    @property
    def warning_count(self) -> int:
        return sum(1 for msg in self.messages if msg.level == "WARN")

    def add_error(self, path: Path | str, message: str) -> None:
        self.messages.append(ValidationMessage("ERROR", _display_path(path), message))

    def add_warning(self, path: Path | str, message: str) -> None:
        self.messages.append(ValidationMessage("WARN", _display_path(path), message))


def _display_path(path: Path | str) -> str:
    return str(path).replace("\\", "/")


def load_json_file(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json_file(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def parse_item_catalog(repo_root: Path = REPO_ROOT) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in sorted((repo_root / "data/items").glob("*.tres")):
        item = parse_item_tres(path)
        item["source_path"] = path.relative_to(repo_root).as_posix()
        items.append(item)
    return items


def parse_item_tres(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    return {
        "id": _string_field(text, "id") or path.stem,
        "name": _string_field(text, "item_name"),
        "description": _string_field(text, "description"),
        "tags": _string_array_field(text, "tags"),
        "price": _int_field(text, "price", 0),
        "base_cost": _int_field(text, "base_cost", -1),
        "can_draw": _bool_field(text, "can_draw", True),
        "can_rotate": _bool_field(text, "can_rotate", True),
        "shape": _shape_field(text, "shape"),
        "direction": _int_field(text, "direction", 3),
        "transmission_mode": _int_field(text, "transmission_mode", 0),
        "hit_filter_tags": _string_array_field(text, "hit_filter_tags"),
    }


class DesignConfigValidator:
    def __init__(self, repo_root: Path = REPO_ROOT) -> None:
        self.repo_root = repo_root
        self.result = ValidationResult()
        self.schema: dict[str, Any] = {}
        self.item_ids: set[str] = set()
        self.tool_ids: set[str] = set()
        self.ornament_ids: set[str] = set()
        self.route_ids: set[str] = set()
        self.max_act = 6

    def validate_all(self) -> ValidationResult:
        self.result = ValidationResult()
        self.schema = self._load_schema()
        self._validate_schema_sources()
        self._validate_economy()
        self._validate_items()
        self._validate_tools()
        self._validate_ornaments()
        self._validate_events()
        self._validate_routes()
        self._validate_stages()
        return self.result

    def _load_schema(self) -> dict[str, Any]:
        path = self.repo_root / SCHEMA_PATH
        try:
            schema = load_json_file(path)
        except Exception as exc:
            self.result.add_error(SCHEMA_PATH, f"schema JSON cannot be read: {exc}")
            return {}
        if not isinstance(schema, dict):
            self.result.add_error(SCHEMA_PATH, "schema root must be an object")
            return {}
        return schema

    def _validate_schema_sources(self) -> None:
        sources = self.schema.get("sources", {})
        if not isinstance(sources, dict):
            self.result.add_error(SCHEMA_PATH, "sources must be an object")
            return
        for name, source in sources.items():
            if not isinstance(source, dict):
                self.result.add_error(SCHEMA_PATH, f"source {name} must be an object")
                continue
            raw_path = str(source.get("path", ""))
            if raw_path == "":
                self.result.add_error(SCHEMA_PATH, f"source {name} is missing path")
                continue
            if "*" in raw_path:
                if not list(self.repo_root.glob(raw_path)):
                    self.result.add_error(raw_path, f"source {name} glob has no matches")
            elif not (self.repo_root / raw_path).exists():
                self.result.add_error(raw_path, f"source {name} path does not exist")

    def _validate_economy(self) -> None:
        path = Path("data/economy/economy.json")
        data = self._load_json(path, dict)
        if not isinstance(data, dict):
            return
        acts = _dict_value(data, "acts")
        min_act = _positive_int(acts.get("min", 1), 1)
        max_act = _positive_int(acts.get("max", 6), 6)
        if max_act < min_act:
            self.result.add_error(path, "acts.max must be >= acts.min")
        self.max_act = max_act
        rewards = _dict_value(data, "battle_rewards")
        for key in ["normal_base", "normal_per_act", "boss_base", "boss_per_act"]:
            if not _is_non_negative_int(rewards.get(key)):
                self.result.add_error(path, f"battle_rewards.{key} must be a non-negative integer")
        shop = _dict_value(data, "shop")
        for key in [
            "refresh_base_cost",
            "refresh_act_step",
            "refresh_repeat_step",
            "item_price_act_step_percent",
            "ornament_price_act_step_percent",
            "ornament_advanced_surcharge_percent",
            "ornament_rare_surcharge_percent",
        ]:
            if not _is_non_negative_int(shop.get(key)):
                self.result.add_error(path, f"shop.{key} must be a non-negative integer")
        self.result.summary["economy_configs"] = 1

    def _validate_items(self) -> None:
        seen: set[str] = set()
        item_paths = sorted((self.repo_root / "data/items").glob("*.tres"))
        for path in item_paths:
            item = parse_item_tres(path)
            rel_path = path.relative_to(self.repo_root)
            item_id = str(item.get("id", ""))
            if item_id == "":
                self.result.add_error(rel_path, "item id is required")
            elif item_id in seen:
                self.result.add_error(rel_path, f"duplicate item id: {item_id}")
            seen.add(item_id)
            if str(item.get("name", "")) == "":
                self.result.add_error(rel_path, "item_name is required")
            if not isinstance(item.get("tags"), list):
                self.result.add_error(rel_path, "tags must be a string array")
            if not item.get("shape"):
                self.result.add_error(rel_path, "shape must contain at least one Vector2i")
            if int(item.get("direction", -1)) not in range(0, 4):
                self.result.add_error(rel_path, "direction must be 0..3")
            if int(item.get("transmission_mode", -1)) not in range(0, 7):
                self.result.add_error(rel_path, "transmission_mode must be 0..6")
        self.item_ids = seen
        self.result.summary["items"] = len(seen)

    def _validate_tools(self) -> None:
        path = Path("data/tools/tools.json")
        data = self._load_json(path, list)
        if not isinstance(data, list):
            return
        allowed = _allowed_values(self.schema, "tool_target_type")
        rarities = _allowed_values(self.schema, "tool_rarity")
        seen: set[str] = set()
        for index, tool in enumerate(data):
            entry_path = f"{path}[{index}]"
            if not isinstance(tool, dict):
                self.result.add_error(entry_path, "tool entry must be an object")
                continue
            tool_id = self._required_string(tool, "id", entry_path)
            self._required_string(tool, "name", entry_path)
            self._required_string(tool, "category", entry_path)
            self._required_string(tool, "effect_text", entry_path)
            if tool_id in seen:
                self.result.add_error(entry_path, f"duplicate tool id: {tool_id}")
            seen.add(tool_id)
            if str(tool.get("rarity", "")) not in rarities:
                self.result.add_error(entry_path, "rarity is not in schema.allowed_values.tool_rarity")
            if str(tool.get("target_type", "")) not in allowed:
                self.result.add_error(entry_path, "target_type is not in schema.allowed_values.tool_target_type")
            if not _is_positive_int(tool.get("price")):
                self.result.add_error(entry_path, "price must be a positive integer")
            self._string_array(tool.get("tags"), "tags", entry_path)
        self.tool_ids = seen
        self.result.summary["tools"] = len(seen)

    def _validate_ornaments(self) -> None:
        path = Path("data/ornaments/ornaments.json")
        data = self._load_json(path, list)
        if not isinstance(data, list):
            return
        rarities = _allowed_values(self.schema, "ornament_rarity")
        seen: set[str] = set()
        for index, ornament in enumerate(data):
            entry_path = f"{path}[{index}]"
            if not isinstance(ornament, dict):
                self.result.add_error(entry_path, "ornament entry must be an object")
                continue
            ornament_id = self._required_string(ornament, "id", entry_path)
            self._required_string(ornament, "name", entry_path)
            self._required_string(ornament, "category", entry_path)
            self._required_string(ornament, "effect_text", entry_path)
            if ornament_id in seen:
                self.result.add_error(entry_path, f"duplicate ornament id: {ornament_id}")
            seen.add(ornament_id)
            if str(ornament.get("rarity", "")) not in rarities:
                self.result.add_error(entry_path, "rarity is not in schema.allowed_values.ornament_rarity")
            earliest = ornament.get("earliest_act")
            if not _is_positive_int(earliest) or int(earliest) > self.max_act:
                self.result.add_error(entry_path, f"earliest_act must be 1..{self.max_act}")
            if not _is_positive_int(ornament.get("price")):
                self.result.add_error(entry_path, "price must be a positive integer")
            self._string_array(ornament.get("tags"), "tags", entry_path)
            if "enabled" in ornament and not isinstance(ornament.get("enabled"), bool):
                self.result.add_error(entry_path, "enabled must be a boolean when present")
        self.ornament_ids = seen
        self.result.summary["ornaments"] = len(seen)

    def _validate_events(self) -> None:
        path = Path("data/events/events.json")
        data = self._load_json(path, list)
        if not isinstance(data, list):
            return
        seen: set[str] = set()
        for index, event in enumerate(data):
            entry_path = f"{path}[{index}]"
            if not isinstance(event, dict):
                self.result.add_error(entry_path, "event entry must be an object")
                continue
            event_id = self._required_string(event, "id", entry_path)
            self._required_string(event, "title", entry_path)
            self._required_string(event, "description", entry_path)
            if event_id in seen:
                self.result.add_error(entry_path, f"duplicate event id: {event_id}")
            seen.add(event_id)
            earliest = event.get("earliest_act")
            if not _is_positive_int(earliest) or int(earliest) > self.max_act:
                self.result.add_error(entry_path, f"earliest_act must be 1..{self.max_act}")
            if not _is_positive_number(event.get("weight")):
                self.result.add_error(entry_path, "weight must be > 0")
            for key in ["risk", "reward"]:
                if not _is_unit_float(event.get(key)):
                    self.result.add_error(entry_path, f"{key} must be between 0 and 1")
            self._string_array(event.get("tags"), "tags", entry_path)
            choices = event.get("choices", [])
            if not isinstance(choices, list) or not choices:
                self.result.add_error(entry_path, "choices must be a non-empty array")
                continue
            choice_ids: set[str] = set()
            for choice_index, choice in enumerate(choices):
                self._validate_event_choice(choice, f"{entry_path}.choices[{choice_index}]", choice_ids)
        self.result.summary["events"] = len(seen)

    def _validate_event_choice(self, choice: Any, entry_path: str, choice_ids: set[str]) -> None:
        if not isinstance(choice, dict):
            self.result.add_error(entry_path, "choice must be an object")
            return
        choice_id = self._required_string(choice, "id", entry_path)
        self._required_string(choice, "title", entry_path)
        self._required_string(choice, "description", entry_path)
        if choice_id in choice_ids:
            self.result.add_error(entry_path, f"duplicate choice id in event: {choice_id}")
        choice_ids.add(choice_id)
        if "cost_shards" in choice and not _is_non_negative_int(choice.get("cost_shards")):
            self.result.add_error(entry_path, "cost_shards must be a non-negative integer")
        if "requires_confirm" in choice and not isinstance(choice.get("requires_confirm"), bool):
            self.result.add_error(entry_path, "requires_confirm must be a boolean")
        effects = choice.get("effects", [])
        if not isinstance(effects, list) or not effects:
            self.result.add_error(entry_path, "effects must be a non-empty array")
            return
        for effect_index, effect in enumerate(effects):
            self._validate_event_effect(effect, f"{entry_path}.effects[{effect_index}]")

    def _validate_event_effect(self, effect: Any, entry_path: str) -> None:
        if not isinstance(effect, dict):
            self.result.add_error(entry_path, "effect must be an object")
            return
        effect_type = str(effect.get("type", ""))
        allowed = _allowed_values(self.schema, "event_effect_type")
        if effect_type not in allowed:
            self.result.add_error(entry_path, f"unknown effect type: {effect_type}")
            return
        if effect_type == "item":
            if str(effect.get("id", "")) not in self.item_ids:
                self.result.add_error(entry_path, f"unknown item id: {effect.get('id', '')}")
            destination = str(effect.get("item_destination", "deck"))
            if destination not in _allowed_values(self.schema, "item_destination"):
                self.result.add_error(entry_path, f"invalid item_destination: {destination}")
        elif effect_type == "ornament":
            if str(effect.get("id", "")) not in self.ornament_ids:
                self.result.add_error(entry_path, f"unknown ornament id: {effect.get('id', '')}")
        elif effect_type == "tool":
            if str(effect.get("id", "")) not in self.tool_ids:
                self.result.add_error(entry_path, f"unknown tool id: {effect.get('id', '')}")
        elif effect_type in ["shards", "sanity"]:
            if not isinstance(effect.get("amount"), int):
                self.result.add_error(entry_path, "amount must be an integer")
        elif effect_type == "backpack_space":
            if "width_delta" not in effect and "height_delta" not in effect:
                self.result.add_error(entry_path, "backpack_space requires width_delta or height_delta")
        elif effect_type in ["backpack_lock_cells", "backpack_delete_cells", "backpack_temp_lock_cells", "backpack_force_move"]:
            self._validate_cells(effect.get("cells", []), entry_path)

    def _validate_routes(self) -> None:
        path = Path("data/routes/routes.json")
        data = self._load_json(path, dict)
        if not isinstance(data, dict):
            return
        routes = data.get("routes", {})
        if not isinstance(routes, dict) or not routes:
            self.result.add_error(path, "routes must be a non-empty object")
            return
        self.route_ids = {str(route_id) for route_id in routes.keys()}
        default_route_id = str(data.get("default_route_id", ""))
        if default_route_id not in routes:
            self.result.add_error(path, "default_route_id must reference a route")
        allowed_types = _allowed_values(self.schema, "route_node_type")
        allowed_scenes = _allowed_values(self.schema, "route_scene")
        route_count = 0
        node_count = 0
        for route_id, nodes in routes.items():
            route_count += 1
            route_path = f"{path}.routes.{route_id}"
            if not isinstance(nodes, list) or not nodes:
                self.result.add_error(route_path, "route nodes must be a non-empty array")
                continue
            node_ids: set[str] = set()
            has_boss = False
            for index, node in enumerate(nodes):
                node_count += 1
                node_path = f"{route_path}[{index}]"
                if not isinstance(node, dict):
                    self.result.add_error(node_path, "node must be an object")
                    continue
                node_id = self._required_string(node, "id", node_path)
                if node_id in node_ids:
                    self.result.add_error(node_path, f"duplicate node id in route: {node_id}")
                node_ids.add(node_id)
                node_type = str(node.get("type", ""))
                if node_type not in allowed_types:
                    self.result.add_error(node_path, f"invalid route node type: {node_type}")
                has_boss = has_boss or node_type == "boss_battle"
                scene = str(node.get("scene", ""))
                if scene != "" and scene not in allowed_scenes:
                    self.result.add_error(node_path, f"invalid route scene: {scene}")
                if "score_target" in node:
                    self._validate_score_target(node.get("score_target"), node_path + ".score_target")
            if not has_boss:
                self.result.add_warning(route_path, "route has no boss_battle node")
        self.result.summary["routes"] = route_count
        self.result.summary["route_nodes"] = node_count

    def _validate_stages(self) -> None:
        path = Path("data/stages/stages.json")
        data = self._load_json(path, dict)
        if not isinstance(data, dict):
            return
        max_act = data.get("max_act", self.max_act)
        if not isinstance(max_act, int) or int(max_act) < 1:
            self.result.add_error(path, "max_act must be a positive integer")
            return
        stages = data.get("stages", {})
        if not isinstance(stages, dict) or not stages:
            self.result.add_error(path, "stages must be a non-empty object")
            return
        for act in range(1, int(max_act) + 1):
            if str(act) not in stages:
                self.result.add_error(path, f"missing stage config for act {act}")
        for raw_act, stage in stages.items():
            stage_path = f"{path}.stages.{raw_act}"
            try:
                act = int(raw_act)
            except ValueError:
                self.result.add_error(stage_path, "stage key must be an integer act number")
                continue
            if act < 1 or act > int(max_act):
                self.result.add_error(stage_path, "stage act is outside 1..max_act")
            if not isinstance(stage, dict):
                self.result.add_error(stage_path, "stage must be an object")
                continue
            self._required_string(stage, "id", stage_path)
            self._required_string(stage, "name", stage_path)
            route_id = str(stage.get("route_id", ""))
            if route_id and route_id not in self.route_ids:
                self.result.add_error(stage_path, f"unknown route_id: {route_id}")
            self._validate_stage_visual(stage.get("visual", {}), stage_path + ".visual")
            self._validate_battle_modifiers(stage.get("battle_modifiers", {}), stage_path + ".battle_modifiers")
            self._validate_stage_boss(stage.get("boss", {}), stage_path + ".boss")
            self._validate_weight_modifiers(stage.get("reward_weight_modifiers", {}), stage_path + ".reward_weight_modifiers")
            self._validate_weight_modifiers(stage.get("shop_weight_modifiers", {}), stage_path + ".shop_weight_modifiers")
        self.result.summary["stages"] = len(stages)

    def _validate_stage_visual(self, visual: Any, entry_path: str) -> None:
        if not isinstance(visual, dict):
            self.result.add_error(entry_path, "visual must be an object")
            return
        for key in [
            "battle_bgm_key",
            "hub_bgm_key",
            "ui_tint",
            "dreamcatcher_net_path",
        ]:
            if key in visual and not isinstance(visual.get(key), str):
                self.result.add_error(entry_path, f"{key} must be a string")

    def _validate_battle_modifiers(self, modifiers: Any, entry_path: str) -> None:
        if not isinstance(modifiers, dict):
            self.result.add_error(entry_path, "battle_modifiers must be an object")
            return
        for key in ["draw_cost_delta", "pollution_added_bonus"]:
            if key in modifiers and not isinstance(modifiers.get(key), int):
                self.result.add_error(entry_path, f"{key} must be an integer")
        if "blocked_cells" in modifiers and modifiers.get("blocked_cells"):
            self._validate_cells(modifiers.get("blocked_cells"), entry_path + ".blocked_cells")

    def _validate_stage_boss(self, boss: Any, entry_path: str) -> None:
        if not isinstance(boss, dict):
            self.result.add_error(entry_path, "boss must be an object")
            return
        if "mechanics" in boss:
            mechanics = boss.get("mechanics", [])
            if not isinstance(mechanics, list) or not all(isinstance(value, str) for value in mechanics):
                self.result.add_error(entry_path, "mechanics must be an array of strings")
        if "score_target" in boss:
            self._validate_score_target(boss.get("score_target"), entry_path + ".score_target")

    def _validate_weight_modifiers(self, modifiers: Any, entry_path: str) -> None:
        if not isinstance(modifiers, dict):
            self.result.add_error(entry_path, "weight modifiers must be an object")
            return
        for section in ["types", "ids", "tags", "rarities"]:
            value = modifiers.get(section, {})
            if not isinstance(value, dict):
                self.result.add_error(entry_path, f"{section} must be an object")
                continue
            for key, multiplier in value.items():
                if not isinstance(key, str) or key == "":
                    self.result.add_error(entry_path, f"{section} keys must be non-empty strings")
                if not isinstance(multiplier, (int, float)) or float(multiplier) < 0:
                    self.result.add_error(entry_path, f"{section}.{key} must be a non-negative number")

    def _validate_score_target(self, value: Any, entry_path: str) -> None:
        if not isinstance(value, dict):
            self.result.add_error(entry_path, "score_target must be an object")
            return
        if not isinstance(value.get("enabled", False), bool):
            self.result.add_error(entry_path, "enabled must be a boolean")
        if value.get("enabled", False):
            if "value" in value and not _is_non_negative_int(value.get("value")):
                self.result.add_error(entry_path, "value must be a non-negative integer")
            for key in ["base", "act_multiplier"]:
                if key in value and not isinstance(value.get(key), int):
                    self.result.add_error(entry_path, f"{key} must be an integer")

    def _validate_cells(self, cells: Any, entry_path: str) -> None:
        if not isinstance(cells, list) or not cells:
            self.result.add_error(entry_path, "cells must be a non-empty array")
            return
        for cell_index, cell in enumerate(cells):
            if not isinstance(cell, dict):
                self.result.add_error(f"{entry_path}.cells[{cell_index}]", "cell must be an object")
                continue
            for axis in ["x", "y"]:
                if not isinstance(cell.get(axis), int) or int(cell.get(axis)) < 0:
                    self.result.add_error(f"{entry_path}.cells[{cell_index}]", f"{axis} must be a non-negative integer")

    def _load_json(self, relative_path: Path, expected_type: type) -> Any:
        path = self.repo_root / relative_path
        try:
            data = load_json_file(path)
        except Exception as exc:
            self.result.add_error(relative_path, f"JSON cannot be read: {exc}")
            return None
        if not isinstance(data, expected_type):
            self.result.add_error(relative_path, f"root must be {expected_type.__name__}")
            return None
        return data

    def _required_string(self, obj: dict[str, Any], key: str, entry_path: str) -> str:
        value = str(obj.get(key, ""))
        if value == "":
            self.result.add_error(entry_path, f"{key} is required")
        return value

    def _string_array(self, value: Any, key: str, entry_path: str) -> None:
        if not isinstance(value, list) or any(not isinstance(entry, str) for entry in value):
            self.result.add_error(entry_path, f"{key} must be a string array")


def _allowed_values(schema: dict[str, Any], key: str) -> list[str]:
    values = schema.get("allowed_values", {}).get(key, [])
    return [str(value) for value in values] if isinstance(values, list) else []


def _dict_value(value: dict[str, Any], key: str) -> dict[str, Any]:
    raw = value.get(key, {})
    return raw if isinstance(raw, dict) else {}


def _is_positive_int(value: Any) -> bool:
    return isinstance(value, int) and value > 0


def _is_non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and value >= 0


def _positive_int(value: Any, fallback: int) -> int:
    return int(value) if _is_positive_int(value) else fallback


def _is_unit_float(value: Any) -> bool:
    return isinstance(value, (int, float)) and 0.0 <= float(value) <= 1.0


def _is_positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and float(value) > 0.0


def _field_raw(text: str, name: str) -> str | None:
    match = re.search(rf"^{re.escape(name)}\s*=\s*(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def _string_field(text: str, name: str) -> str:
    raw = _field_raw(text, name)
    if raw is None:
        return ""
    try:
        value = json.loads(raw)
        return str(value)
    except json.JSONDecodeError:
        return raw.strip('"')


def _int_field(text: str, name: str, fallback: int) -> int:
    raw = _field_raw(text, name)
    if raw is None:
        return fallback
    try:
        return int(raw)
    except ValueError:
        return fallback


def _bool_field(text: str, name: str, fallback: bool) -> bool:
    raw = _field_raw(text, name)
    if raw is None:
        return fallback
    return raw == "true"


def _string_array_field(text: str, name: str) -> list[str]:
    raw = _field_raw(text, name)
    if raw is None:
        return []
    return re.findall(r'"([^"]*)"', raw)


def _shape_field(text: str, name: str) -> list[dict[str, int]]:
    raw = _field_raw(text, name)
    if raw is None:
        return []
    result: list[dict[str, int]] = []
    for x_str, y_str in re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", raw):
        result.append({"x": int(x_str), "y": int(y_str)})
    return result
