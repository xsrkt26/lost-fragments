from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


CELL_SIZE = 256
ALPHA_THRESHOLD = 4
CROP_MARGIN = 12
CANVAS_PADDING = 20

SOURCE_DIR = Path("assets/sourceImage/\u7269\u54c1\u3010\u6c61\u67d3\u3011")
OUTPUT_DIR = Path("assets/ui/items/pollution")
ITEM_DIR = Path("data/items")


@dataclass(frozen=True)
class PollutionItemArt:
	item_id: str
	source_name: str

	@property
	def source_path(self) -> Path:
		return SOURCE_DIR / self.source_name

	@property
	def output_path(self) -> Path:
		return OUTPUT_DIR / f"{self.item_id}.png"

	@property
	def tres_path(self) -> Path:
		return ITEM_DIR / f"{self.item_id}.tres"


POLLUTION_ITEMS: tuple[PollutionItemArt, ...] = (
	PollutionItemArt("paper_ball", "\u7eb8\u56e2.png"),
	PollutionItemArt("syringe", "\u9488\u7ba1.png"),
	PollutionItemArt("old_soccer_ball", "\u65e7\u8db3\u7403.png"),
	PollutionItemArt("expired_medicine", "\u8fc7\u671f\u836f\u54c1.png"),
	PollutionItemArt("trash_recycler", "\u5783\u573e\u56de\u6536\u5668.png"),
	PollutionItemArt("rusty_gear", "\u751f\u9508\u9f7f\u8f6e.png"),
	PollutionItemArt("leaky_pen", "\u6f0f\u6c34\u94a2\u7b14.png"),
	PollutionItemArt("wet_cardboard_box", "\u6f6e\u6e7f\u7eb8\u7bb1.png"),
	PollutionItemArt("sticky_note", "\u4fbf\u5229\u8d34.png"),
	PollutionItemArt("trash_bag", "\u5783\u573e\u888b.png"),
	PollutionItemArt("pill_bottle", "\u5c0f\u836f\u74f6.png"),
	PollutionItemArt("joker", "joker\uff08\u4e00\u5f20\u5e9f\u5f03\u6251\u514b\u724c\uff09.png"),
	PollutionItemArt("leftover_box", "\u5269\u996d\u76d2.png"),
	PollutionItemArt("sad_teddy_bear", "\u4f24\u5fc3\u6cf0\u8fea\u718a.png"),
)


def _read_text(path: Path) -> str:
	return path.read_text(encoding="utf-8")


def _write_text(path: Path, text: str) -> None:
	path.write_text(text, encoding="utf-8", newline="\n")


def _shape_size_from_tres(path: Path) -> tuple[int, int]:
	text = _read_text(path)
	match = re.search(r"shape = Array\[Vector2i\]\(\[(.*?)\]\)", text, re.DOTALL)
	if match is None:
		raise ValueError(f"Missing shape in {path}")
	points = [
		(int(x), int(y))
		for x, y in re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", match.group(1))
	]
	if not points:
		raise ValueError(f"Empty shape in {path}")
	min_x = min(x for x, _y in points)
	max_x = max(x for x, _y in points)
	min_y = min(y for _x, y in points)
	max_y = max(y for _x, y in points)
	return max_x - min_x + 1, max_y - min_y + 1


def _alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
	alpha = image.getchannel("A")
	mask = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
	bounds = mask.getbbox()
	if bounds is None:
		raise ValueError("Image has no visible pixels")
	left, top, right, bottom = bounds
	return (
		max(0, left - CROP_MARGIN),
		max(0, top - CROP_MARGIN),
		min(image.width, right + CROP_MARGIN),
		min(image.height, bottom + CROP_MARGIN),
	)


def _fit_crop_to_canvas(crop: Image.Image, canvas_size: tuple[int, int]) -> Image.Image:
	available_width = max(1, canvas_size[0] - CANVAS_PADDING * 2)
	available_height = max(1, canvas_size[1] - CANVAS_PADDING * 2)
	scale = min(available_width / crop.width, available_height / crop.height)
	target_size = (
		max(1, round(crop.width * scale)),
		max(1, round(crop.height * scale)),
	)
	resized = crop.resize(target_size, Image.Resampling.LANCZOS)
	canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
	canvas.alpha_composite(
		resized,
		(
			round((canvas_size[0] - resized.width) / 2),
			round((canvas_size[1] - resized.height) / 2),
		),
	)
	return canvas


def generate_icons() -> list[tuple[PollutionItemArt, tuple[int, int]]]:
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	results: list[tuple[PollutionItemArt, tuple[int, int]]] = []
	for item in POLLUTION_ITEMS:
		cols, rows = _shape_size_from_tres(item.tres_path)
		canvas_size = (cols * CELL_SIZE, rows * CELL_SIZE)
		with Image.open(item.source_path) as raw:
			image = raw.convert("RGBA")
			crop = image.crop(_alpha_bounds(image))
			output = _fit_crop_to_canvas(crop, canvas_size)
			output.save(item.output_path)
		results.append((item, canvas_size))
	return results


def update_item_resources() -> None:
	for item in POLLUTION_ITEMS:
		text = _read_text(item.tres_path)
		icon_resource = (
			f'[ext_resource type="Texture2D" '
			f'path="res://{item.output_path.as_posix()}" id="icon"]'
		)
		if 'id="icon"' not in text:
			text = re.sub(
				r"load_steps=(\d+)",
				lambda match: f"load_steps={int(match.group(1)) + 1}",
				text,
				count=1,
			)
			last_ext = list(re.finditer(r"^\[ext_resource .*$", text, re.MULTILINE))
			if not last_ext:
				raise ValueError(f"Missing ext_resource block in {item.tres_path}")
			insert_at = last_ext[-1].end()
			text = text[:insert_at] + "\n" + icon_resource + text[insert_at:]
		else:
			text = re.sub(
				r'^\[ext_resource type="Texture2D" path="[^"]+" id="icon"\]$',
				icon_resource,
				text,
				count=1,
				flags=re.MULTILINE,
			)

		if not re.search(r"^icon = ExtResource\(\"icon\"\)$", text, re.MULTILINE):
			text = text.replace(
				"runtime_id = -1\n",
				'runtime_id = -1' + "\n" + 'icon = ExtResource("icon")' + "\n",
				1,
			)
		_write_text(item.tres_path, text)


def write_contact_sheet(path: Path, generated: list[tuple[PollutionItemArt, tuple[int, int]]]) -> None:
	thumb_width = 180
	label_height = 30
	cols = 4
	rows = (len(generated) + cols - 1) // cols
	sheet = Image.new("RGBA", (cols * thumb_width, rows * (thumb_width + label_height)), (34, 34, 34, 255))
	draw = ImageDraw.Draw(sheet)
	try:
		font = ImageFont.truetype("arial.ttf", 12)
	except OSError:
		font = ImageFont.load_default()
	for index, (item, _canvas_size) in enumerate(generated):
		x = (index % cols) * thumb_width
		y = (index // cols) * (thumb_width + label_height)
		with Image.open(item.output_path) as raw:
			image = raw.convert("RGBA")
			image.thumbnail((thumb_width - 18, thumb_width - 18), Image.Resampling.LANCZOS)
			sheet.alpha_composite(image, (x + (thumb_width - image.width) // 2, y + (thumb_width - image.height) // 2))
		draw.text((x + 8, y + thumb_width + 6), item.item_id, fill=(255, 255, 255, 255), font=font)
	path.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(path)


def main() -> None:
	parser = argparse.ArgumentParser(description="Generate ratio-correct pollution item icons.")
	parser.add_argument("--update-tres", action="store_true", help="Bind generated icons to matching ItemData resources.")
	parser.add_argument("--contact-sheet", type=Path, default=None, help="Optional preview sheet output path.")
	args = parser.parse_args()

	generated = generate_icons()
	if args.update_tres:
		update_item_resources()
	if args.contact_sheet is not None:
		write_contact_sheet(args.contact_sheet, generated)
	for item, size in generated:
		print(f"{item.item_id}: {item.source_name} -> {item.output_path.as_posix()} ({size[0]}x{size[1]})")


if __name__ == "__main__":
	main()
