#!/usr/bin/env python3
"""Generate candy-themed pixel art and chiptune SFX for Candy Tank Battle."""
from __future__ import annotations

import math
import os
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
SFX = ROOT / "assets" / "sfx"
UI = ROOT / "assets" / "ui"
for p in (SPR, SFX, UI):
    p.mkdir(parents=True, exist_ok=True)

# --- palette ---
TRANSPARENT = (0, 0, 0, 0)


def rgba(hex_color: str, a: int = 255) -> tuple[int, int, int, int]:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


PINK = rgba("#FF7EB3")
PINK_D = rgba("#E84A88")
PINK_L = rgba("#FFD0E6")
CREAM = rgba("#FFF6E9")
CHOCO = rgba("#8B4E2A")
CHOCO_D = rgba("#5A2E14")
CHOCO_L = rgba("#D9A066")
MINT = rgba("#5EEAD4")
MINT_D = rgba("#0F766E")
MINT_L = rgba("#CCFBF1")
BLUE = rgba("#7C83FF")
BLUE_D = rgba("#3730A3")
BLUE_L = rgba("#C7D2FE")
LEMON = rgba("#FFD166")
LEMON_D = rgba("#C27803")
LEMON_L = rgba("#FFF3C4")
BERRY = rgba("#C084FC")
BERRY_D = rgba("#6B21A8")
INK = rgba("#3B2142")
WHITE = rgba("#FFFFFF")
SHADOW = rgba("#3B2142", 70)
FLOOR_A = rgba("#FFE8F2")
FLOOR_B = rgba("#FFD6EA")
COOKIE = rgba("#E0A15A")
COOKIE_D = rgba("#B56B2A")
COOKIE_L = rgba("#F3D09A")
CHIP = rgba("#4A2A12")
STEEL_A = rgba("#F9A8D4")
STEEL_B = rgba("#F472B6")
STEEL_L = rgba("#FCE7F3")
JELLY = rgba("#7DD3FC", 210)
JELLY_D = rgba("#0284C7", 220)
JELLY_L = rgba("#E0F2FE", 230)
COTTON = rgba("#FDA4AF")
COTTON_B = rgba("#93C5FD")
FROST = rgba("#E0F2FE")
FROST_L = rgba("#FFFFFF")
CAKE = rgba("#FBCFE8")
CAKE_D = rgba("#F472B6")
CHERRY = rgba("#EF4444")
GOLD = rgba("#FBBF24")


def new_img(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), TRANSPARENT)


def pset(px, w, h, x, y, c):
    if 0 <= x < w and 0 <= y < h and c[3] > 0:
        if c[3] == 255:
            px[x, y] = c
        else:
            r, g, b, a = c
            br, bg, bb, ba = px[x, y]
            t = a / 255.0
            px[x, y] = (
                int(r * t + br * (1 - t)),
                int(g * t + bg * (1 - t)),
                int(b * t + bb * (1 - t)),
                max(ba, a),
            )


def fill_rect(px, w, h, x, y, rw, rh, c):
    for yy in range(y, y + rh):
        for xx in range(x, x + rw):
            pset(px, w, h, xx, yy, c)


def outline_rect(px, w, h, x, y, rw, rh, c):
    for xx in range(x, x + rw):
        pset(px, w, h, xx, y, c)
        pset(px, w, h, xx, y + rh - 1, c)
    for yy in range(y, y + rh):
        pset(px, w, h, x, yy, c)
        pset(px, w, h, x + rw - 1, yy, c)


def fill_ellipse(px, w, h, cx, cy, rx, ry, c):
    rx = max(rx, 0.5)
    ry = max(ry, 0.5)
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                pset(px, w, h, x, y, c)


def ring_ellipse(px, w, h, cx, cy, rx, ry, c, thick=1.0):
    for y in range(int(cy - ry - 2), int(cy + ry + 3)):
        for x in range(int(cx - rx - 2), int(cx + rx + 3)):
            dx = (x + 0.5 - cx) / max(rx, 0.5)
            dy = (y + 0.5 - cy) / max(ry, 0.5)
            d = dx * dx + dy * dy
            inner = ((rx - thick) / max(rx, 0.5)) ** 2
            if inner <= d <= 1.05:
                pset(px, w, h, x, y, c)


def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print("wrote", path.relative_to(ROOT))


# ---------- tiles 16x16 ----------
def tile_floor() -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    for y in range(16):
        for x in range(16):
            c = FLOOR_A if ((x // 8) + (y // 8)) % 2 == 0 else FLOOR_B
            px[x, y] = c
    # sugar dots
    for x, y in ((2, 3), (11, 4), (7, 12), (13, 13)):
        pset(px, 16, 16, x, y, WHITE)
    return img


def tile_brick(cracked=False) -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    fill_rect(px, 16, 16, 0, 0, 16, 16, COOKIE_D)
    blocks = [(0, 0, 8, 8), (8, 0, 8, 8), (0, 8, 8, 8), (8, 8, 8, 8)]
    for i, (x, y, w, h) in enumerate(blocks):
        fill_rect(px, 16, 16, x + 1, y + 1, w - 2, h - 2, COOKIE)
        fill_rect(px, 16, 16, x + 1, y + 1, w - 2, 2, COOKIE_L)
        chips = [(x + 3, y + 3), (x + 5, y + 5)]
        for cx, cy in chips:
            pset(px, 16, 16, cx, cy, CHIP)
            pset(px, 16, 16, cx + 1, cy, CHOCO_D)
        if cracked:
            for t in range(2, 6):
                pset(px, 16, 16, x + t, y + t, CHOCO_D)
                pset(px, 16, 16, x + 7 - t, y + t + 1, CHOCO_D)
    return img


def tile_steel() -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    fill_rect(px, 16, 16, 0, 0, 16, 16, STEEL_B)
    fill_rect(px, 16, 16, 1, 1, 14, 14, STEEL_A)
    fill_rect(px, 16, 16, 2, 2, 12, 3, STEEL_L)
    # hard-candy swirl
    for i, (x, y) in enumerate([(4, 6), (7, 8), (10, 6), (8, 11)]):
        fill_ellipse(px, 16, 16, x, y, 2.2, 2.2, WHITE if i % 2 == 0 else PINK_D)
    outline_rect(px, 16, 16, 0, 0, 16, 16, PINK_D)
    # bolts
    for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
        pset(px, 16, 16, x, y, WHITE)
    return img


def tile_water(frame: int) -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    fill_rect(px, 16, 16, 0, 0, 16, 16, JELLY)
    off = frame * 3
    for y in range(16):
        wave = int(2 * math.sin((y + off) * 0.6))
        for x in range(16):
            if (x + wave) % 5 == 0:
                pset(px, 16, 16, x, y, JELLY_D)
            if (x + y + off) % 7 == 0:
                pset(px, 16, 16, x, y, JELLY_L)
    fill_ellipse(px, 16, 16, 5 + frame, 4, 2.5, 1.6, JELLY_L)
    fill_ellipse(px, 16, 16, 11, 11 - frame, 2.2, 1.4, WHITE)
    return img


def tile_bush() -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    fill_ellipse(px, 16, 16, 5, 8, 5.5, 5.5, COTTON)
    fill_ellipse(px, 16, 16, 11, 7, 5.2, 5.8, COTTON_B)
    fill_ellipse(px, 16, 16, 8, 11, 5.0, 4.2, PINK)
    fill_ellipse(px, 16, 16, 4, 5, 2.0, 1.6, WHITE)
    fill_ellipse(px, 16, 16, 11, 5, 1.8, 1.5, WHITE)
    return img


def tile_ice() -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    fill_rect(px, 16, 16, 0, 0, 16, 16, FROST)
    fill_rect(px, 16, 16, 1, 1, 14, 4, FROST_L)
    for x, y in ((3, 8), (9, 6), (12, 12), (5, 13)):
        pset(px, 16, 16, x, y, WHITE)
        pset(px, 16, 16, x + 1, y, BLUE_L)
    outline_rect(px, 16, 16, 0, 0, 16, 16, rgba("#BAE6FD"))
    return img


def tile_empty_spawn() -> Image.Image:
    img = new_img(16, 16)
    px = img.load()
    ring_ellipse(px, 16, 16, 8, 8, 6, 6, PINK_L, 1.2)
    return img


def make_tileset():
    names = []
    tiles = [
        ("floor", tile_floor()),
        ("brick", tile_brick(False)),
        ("brick_crack", tile_brick(True)),
        ("steel", tile_steel()),
        ("water0", tile_water(0)),
        ("water1", tile_water(1)),
        ("bush", tile_bush()),
        ("ice", tile_ice()),
        ("spawn", tile_empty_spawn()),
    ]
    atlas = new_img(16 * len(tiles), 16)
    for i, (name, t) in enumerate(tiles):
        atlas.paste(t, (i * 16, 0))
        save(t, SPR / f"{name}.png")
        names.append(name)
    save(atlas, SPR / "tileset.png")
    return names


# ---------- tanks 32x32 ----------
def draw_tank(body, body_d, body_l, tread, cannon, accent, frame=0) -> Image.Image:
    img = new_img(32, 32)
    px = img.load()
    # drop shadow
    fill_ellipse(px, 32, 32, 16, 28, 11, 3.2, SHADOW)
    # treads (left/right for up-facing)
    ty = frame  # 0/1 offset
    for side in (3, 22):
        fill_rect(px, 32, 32, side, 8, 7, 20, tread)
        fill_rect(px, 32, 32, side + 1, 9, 5, 18, INK)
        fill_rect(px, 32, 32, side + 1, 9, 5, 18, rgba("#2A1528"))
        for k in range(5):
            yy = 10 + ((k * 4 + ty * 2) % 18)
            fill_rect(px, 32, 32, side + 1, yy, 5, 2, body_l)
    # hull
    fill_ellipse(px, 32, 32, 16, 18, 10.5, 9.0, body_d)
    fill_ellipse(px, 32, 32, 16, 17, 10.0, 8.5, body)
    fill_ellipse(px, 32, 32, 16, 14, 8.0, 4.2, body_l)
    # candy wrap stripe
    fill_rect(px, 32, 32, 8, 17, 16, 3, accent)
    fill_rect(px, 32, 32, 8, 18, 16, 1, WHITE)
    # turret
    fill_ellipse(px, 32, 32, 16, 13, 7.2, 6.4, body)
    fill_ellipse(px, 32, 32, 16, 11, 5.5, 3.2, body_l)
    # eyes
    fill_ellipse(px, 32, 32, 13, 13, 2.3, 2.6, WHITE)
    fill_ellipse(px, 32, 32, 19, 13, 2.3, 2.6, WHITE)
    fill_ellipse(px, 32, 32, 13, 13, 1.2, 1.4, INK)
    fill_ellipse(px, 32, 32, 19, 13, 1.2, 1.4, INK)
    pset(px, 32, 32, 13, 12, WHITE)
    pset(px, 32, 32, 19, 12, WHITE)
    # blush
    fill_ellipse(px, 32, 32, 11, 16, 1.6, 1.0, PINK)
    fill_ellipse(px, 32, 32, 21, 16, 1.6, 1.0, PINK)
    # smile
    pset(px, 32, 32, 15, 16, INK)
    pset(px, 32, 32, 16, 17, INK)
    pset(px, 32, 32, 17, 16, INK)
    # cannon (lollipop stick + candy tip)
    fill_rect(px, 32, 32, 14, 2, 4, 8, cannon)
    fill_rect(px, 32, 32, 15, 2, 2, 8, WHITE)
    fill_ellipse(px, 32, 32, 16, 3, 3.4, 3.4, accent)
    fill_ellipse(px, 32, 32, 16, 3, 2.0, 2.0, WHITE)
    # highlight
    pset(px, 32, 32, 12, 10, WHITE)
    return img


def rot(img: Image.Image, k: int) -> Image.Image:
    return img.rotate(-90 * k, resample=Image.Resampling.NEAREST, expand=False)


def make_tanks():
    specs = [
        ("player", PINK, PINK_D, PINK_L, rgba("#5B3358"), GOLD, WHITE),
        ("enemy_basic", CHOCO_L, CHOCO, COOKIE_L, INK, CHOCO_D, COOKIE),
        ("enemy_fast", MINT, MINT_D, MINT_L, INK, rgba("#34D399"), WHITE),
        ("enemy_power", LEMON, LEMON_D, LEMON_L, INK, rgba("#FB7185"), WHITE),
        ("enemy_armor", BLUE, BLUE_D, BLUE_L, INK, BERRY, WHITE),
    ]
    dirs = ["up", "right", "down", "left"]
    atlas = new_img(32 * 8, 32 * len(specs))
    for row, (name, body, bd, bl, tread, cannon, accent) in enumerate(specs):
        for frame in (0, 1):
            base = draw_tank(body, bd, bl, tread, cannon, accent, frame)
            for k, dname in enumerate(dirs):
                im = rot(base, k)
                save(im, SPR / f"{name}_{dname}_{frame}.png")
                atlas.paste(im, ((k + frame * 4) * 32, row * 32), im)
    save(atlas, SPR / "tanks.png")


def make_base():
    img = new_img(32, 32)
    px = img.load()
    fill_ellipse(px, 32, 32, 16, 28, 12, 3, SHADOW)
    # cake layers
    fill_rect(px, 32, 32, 4, 18, 24, 10, CAKE_D)
    fill_rect(px, 32, 32, 5, 19, 22, 8, CAKE)
    fill_rect(px, 32, 32, 6, 12, 20, 8, WHITE)
    fill_rect(px, 32, 32, 7, 13, 18, 6, CAKE)
    fill_rect(px, 32, 32, 8, 7, 16, 7, WHITE)
    fill_rect(px, 32, 32, 9, 8, 14, 5, PINK_L)
    # frosting drip
    for x in (6, 10, 14, 18, 22):
        fill_rect(px, 32, 32, x, 18, 3, 4, WHITE)
    # cherry
    fill_ellipse(px, 32, 32, 16, 6, 3.5, 3.5, CHERRY)
    fill_ellipse(px, 32, 32, 15, 5, 1.2, 1.0, WHITE)
    pset(px, 32, 32, 16, 2, rgba("#166534"))
    pset(px, 32, 32, 17, 3, rgba("#166534"))
    # door
    fill_rect(px, 32, 32, 13, 22, 6, 6, CHOCO)
    fill_rect(px, 32, 32, 14, 23, 4, 4, CHOCO_D)
    save(img, SPR / "base.png")

    dead = new_img(32, 32)
    px = dead.load()
    fill_ellipse(px, 32, 32, 16, 24, 11, 4, SHADOW)
    fill_ellipse(px, 32, 32, 16, 18, 10, 7, rgba("#6B7280"))
    fill_ellipse(px, 32, 32, 16, 16, 8, 5, rgba("#9CA3AF"))
    # X eyes crumbs
    for x, y in ((11, 14), (20, 14), (12, 15), (19, 15), (16, 20)):
        pset(px, 32, 32, x, y, INK)
    save(dead, SPR / "base_dead.png")


def make_bullet():
    atlas = new_img(16 * 4, 16)
    colors = [GOLD, WHITE, PINK, MINT]
    for i, (name, col) in enumerate(
        [("bullet_player", GOLD), ("bullet_enemy", rgba("#FB7185")), ("bullet_super", WHITE)]
    ):
        img = new_img(8, 8)
        px = img.load()
        fill_ellipse(px, 8, 8, 4, 4, 3.2, 3.2, col)
        fill_ellipse(px, 8, 8, 3, 3, 1.4, 1.4, WHITE)
        save(img, SPR / f"{name}.png")
    # 4-dir spark
    for k, d in enumerate(["up", "right", "down", "left"]):
        img = new_img(16, 16)
        px = img.load()
        fill_ellipse(px, 16, 16, 8, 8, 3, 3, GOLD)
        save(img, SPR / f"spark_{d}.png")
        atlas.paste(img, (k * 16, 0), img)
    save(atlas, SPR / "fx_small.png")


def make_explosion():
    atlas = new_img(32 * 5, 32)
    colors_sets = [
        [PINK_L, PINK, GOLD],
        [GOLD, PINK, WHITE],
        [WHITE, LEMON, PINK],
        [LEMON_L, WHITE, rgba("#F97316")],
        [rgba("#F97316", 180), rgba("#FBBF24", 120), TRANSPARENT],
    ]
    radii = [5, 9, 12, 10, 6]
    for i, (cols, r) in enumerate(zip(colors_sets, radii)):
        img = new_img(32, 32)
        px = img.load()
        fill_ellipse(px, 32, 32, 16, 16, r, r, cols[0])
        fill_ellipse(px, 32, 32, 16, 16, r * 0.65, r * 0.65, cols[1])
        fill_ellipse(px, 32, 32, 16, 16, r * 0.35, r * 0.35, cols[2] if cols[2][3] else WHITE)
        # star spikes
        if i < 4:
            for ang in range(0, 360, 45):
                rad = math.radians(ang)
                x = int(16 + math.cos(rad) * (r + 3))
                y = int(16 + math.sin(rad) * (r + 3))
                fill_ellipse(px, 32, 32, x, y, 2, 2, cols[1])
        save(img, SPR / f"boom_{i}.png")
        atlas.paste(img, (i * 32, 0), img)
    save(atlas, SPR / "explosion.png")


def make_spawn():
    atlas = new_img(32 * 4, 32)
    for i in range(4):
        img = new_img(32, 32)
        px = img.load()
        s = 4 + i * 3
        col = [PINK_L, PINK, GOLD, WHITE][i]
        ring_ellipse(px, 32, 32, 16, 16, s, s, col, 2)
        ring_ellipse(px, 32, 32, 16, 16, s - 3, s - 3, WHITE, 1)
        save(img, SPR / f"spawn_{i}.png")
        atlas.paste(img, (i * 32, 0), img)
    save(atlas, SPR / "spawn_fx.png")


def make_shield():
    for i in range(2):
        img = new_img(36, 36)
        px = img.load()
        col = GOLD if i == 0 else WHITE
        ring_ellipse(px, 36, 36, 18, 18, 16, 16, col, 1.6)
        ring_ellipse(px, 36, 36, 18, 18, 14, 14, PINK_L, 1.0)
        save(img, SPR / f"shield_{i}.png")


def make_powerups():
    # 16x16 candy items
    def wrap(draw_fn, name):
        img = new_img(16, 16)
        px = img.load()
        fill_ellipse(px, 16, 16, 8, 8, 7.4, 7.4, WHITE)
        fill_ellipse(px, 16, 16, 8, 8, 6.4, 6.4, PINK_L)
        draw_fn(px)
        save(img, SPR / f"power_{name}.png")
        return img

    def helmet(px):
        fill_ellipse(px, 16, 16, 8, 8, 4, 3.5, GOLD)
        fill_rect(px, 16, 16, 5, 8, 6, 3, GOLD)
        fill_ellipse(px, 16, 16, 8, 7, 2, 1.4, WHITE)

    def clock(px):
        fill_ellipse(px, 16, 16, 8, 8, 4, 4, WHITE)
        ring_ellipse(px, 16, 16, 8, 8, 4, 4, BLUE_D, 1)
        fill_rect(px, 16, 16, 8, 6, 1, 3, INK)
        fill_rect(px, 16, 16, 8, 8, 3, 1, INK)

    def shovel(px):
        fill_rect(px, 16, 16, 8, 4, 2, 6, CHOCO)
        fill_rect(px, 16, 16, 6, 9, 6, 4, STEEL_A)
        fill_rect(px, 16, 16, 7, 10, 4, 2, WHITE)

    def star(px):
        fill_ellipse(px, 16, 16, 8, 8, 4.5, 4.5, GOLD)
        fill_ellipse(px, 16, 16, 8, 7, 2, 2, WHITE)

    def grenade(px):
        fill_ellipse(px, 16, 16, 8, 9, 4, 4, rgba("#F43F5E"))
        fill_rect(px, 16, 16, 7, 4, 2, 3, INK)
        pset(px, 16, 16, 9, 4, GOLD)

    def extra(px):
        fill_ellipse(px, 16, 16, 8, 9, 4.2, 3.2, PINK)
        fill_rect(px, 16, 16, 7, 5, 2, 4, PINK_D)
        fill_ellipse(px, 16, 16, 7, 8, 1.4, 1.4, WHITE)

    atlas = new_img(16 * 6, 16)
    for i, (n, fn) in enumerate(
        [
            ("helmet", helmet),
            ("clock", clock),
            ("shovel", shovel),
            ("star", star),
            ("grenade", grenade),
            ("life", extra),
        ]
    ):
        im = wrap(fn, n)
        atlas.paste(im, (i * 16, 0), im)
    save(atlas, SPR / "powerups.png")


def make_ui_art():
    # side panel candy wood
    panel = new_img(160, 416)
    d = ImageDraw.Draw(panel)
    d.rectangle([0, 0, 159, 415], fill=(255, 214, 232, 255))
    d.rectangle([6, 6, 153, 409], fill=(255, 236, 245, 255), outline=(232, 74, 136, 255))
    for y in range(16, 400, 28):
        d.line([(18, y), (142, y)], fill=(255, 182, 213, 180), width=1)
    save(panel, SPR / "hud_panel.png")

    # enemy icon mini
    ico = draw_tank(CHOCO_L, CHOCO, COOKIE_L, INK, CHOCO_D, COOKIE, 0)
    ico = ico.resize((16, 16), Image.Resampling.NEAREST)
    save(ico, SPR / "enemy_icon.png")
    pico = draw_tank(PINK, PINK_D, PINK_L, rgba("#5B3358"), GOLD, WHITE, 0)
    pico = pico.resize((16, 16), Image.Resampling.NEAREST)
    save(pico, SPR / "player_icon.png")

    # title banner
    title = new_img(480, 96)
    td = ImageDraw.Draw(title)
    td.rounded_rectangle([4, 8, 476, 88], radius=20, fill=(255, 126, 179, 255))
    td.rounded_rectangle([10, 14, 470, 82], radius=16, fill=(255, 240, 246, 255))
    font_path = "/System/Library/Fonts/STHeiti Medium.ttc"
    try:
        font_big = ImageFont.truetype(font_path, 42)
        font_btn = ImageFont.truetype(font_path, 28)
        font_sm = ImageFont.truetype(font_path, 18)
    except Exception:
        font_big = ImageFont.load_default()
        font_btn = font_big
        font_sm = font_big

    def center_text(im, text, font, fill, y=None):
        dr = ImageDraw.Draw(im)
        bbox = dr.textbbox((0, 0), text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        x = (im.width - tw) // 2 - bbox[0]
        yy = ((im.height - th) // 2 - bbox[1]) if y is None else y
        dr.text((x + 2, yy + 2), text, font=font, fill=(59, 33, 66, 80))
        dr.text((x, yy), text, font=font, fill=fill)

    center_text(title, "糖果坦克大战", font_big, (232, 74, 136, 255), 22)
    save(title, UI / "title.png")

    def button(text, w=280, h=56, fill=(255, 126, 179, 255)):
        im = new_img(w, h)
        dr = ImageDraw.Draw(im)
        dr.rounded_rectangle([0, 0, w - 1, h - 1], radius=16, fill=(91, 51, 88, 60))
        dr.rounded_rectangle([0, 0, w - 3, h - 4], radius=16, fill=fill)
        dr.rounded_rectangle([4, 4, w - 7, h - 8], radius=12, fill=(255, 246, 233, 255))
        center_text(im, text, font_btn, (232, 74, 136, 255))
        return im

    save(button("开始游戏"), UI / "btn_start.png")
    save(button("再来一局"), UI / "btn_retry.png")
    save(button("返回菜单"), UI / "btn_menu.png")
    save(button("继续游戏", fill=(126, 211, 196, 255)), UI / "btn_resume.png")

    help_im = new_img(420, 140)
    hd = ImageDraw.Draw(help_im)
    hd.rounded_rectangle([0, 0, 419, 139], radius=16, fill=(255, 246, 233, 230))
    lines = [
        "方向键 / WASD  移动小坦克",
        "空格 / J  发射糖果炮弹",
        "P  暂停    保护蛋糕基地！",
    ]
    for i, line in enumerate(lines):
        hd.text((24, 18 + i * 36), line, font=font_sm, fill=(91, 51, 88, 255))
    save(help_im, UI / "help.png")

    for text, name, col in [
        ("第  关", "stage_label", (232, 74, 136, 255)),
        ("游戏结束", "gameover", (180, 40, 90, 255)),
        ("关卡完成", "stageclear", (15, 118, 110, 255)),
        ("暂停", "paused", (91, 51, 88, 255)),
        ("你赢啦！", "youwin", (194, 120, 3, 255)),
    ]:
        im = new_img(360, 72)
        dr = ImageDraw.Draw(im)
        dr.rounded_rectangle([0, 0, 359, 71], radius=18, fill=(255, 246, 233, 240))
        center_text(im, text, font_big, col)
        save(im, UI / f"{name}.png")


def make_icon():
    img = new_img(128, 128)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, 124, 124], radius=28, fill=(255, 126, 179, 255))
    d.rounded_rectangle([12, 12, 116, 116], radius=22, fill=(255, 240, 246, 255))
    tank = draw_tank(PINK, PINK_D, PINK_L, rgba("#5B3358"), GOLD, WHITE, 0)
    tank = tank.resize((96, 96), Image.Resampling.NEAREST)
    img.paste(tank, (16, 18), tank)
    save(img, ROOT / "icon.png")


# ---------- audio ----------
def write_wav(path: Path, samples, sr=22050):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        w.writeframes(data)
    print("wrote", path.relative_to(ROOT))


def env(i, n, a=0.01, r=0.2):
    t = i / max(n - 1, 1)
    if t < a:
        return t / a
    if t > 1 - r:
        return max(0.0, (1 - t) / r)
    return 1.0


def tone(freq, dur, sr=22050, vol=0.3, wave_type="square", decay=0.3):
    n = int(sr * dur)
    out = []
    for i in range(n):
        t = i / sr
        ph = t * freq
        if wave_type == "square":
            v = 1.0 if (ph % 1.0) < 0.5 else -1.0
        elif wave_type == "tri":
            v = 4 * abs((ph % 1.0) - 0.5) - 1
        else:
            v = math.sin(2 * math.pi * ph)
        e = math.exp(-t / max(decay, 0.01)) * env(i, n, 0.01, 0.15)
        out.append(v * vol * e)
    return out


def noise(dur, sr=22050, vol=0.25, decay=0.15):
    n = int(sr * dur)
    x = 1
    out = []
    for i in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        v = (x / 0x7FFFFFFF) * 2 - 1
        t = i / sr
        out.append(v * vol * math.exp(-t / decay))
    return out


def mix(*seqs):
    n = max(len(s) for s in seqs)
    out = [0.0] * n
    for s in seqs:
        for i, v in enumerate(s):
            out[i] += v
    m = max(1.0, max(abs(v) for v in out))
    if m > 1:
        out = [v / m * 0.95 for v in out]
    return out


def concat(*seqs):
    out = []
    for s in seqs:
        out.extend(s)
    return out


def silence(dur, sr=22050):
    return [0.0] * int(sr * dur)


def make_sfx():
    write_wav(SFX / "shoot.wav", tone(880, 0.09, vol=0.22, wave_type="square", decay=0.05))
    write_wav(
        SFX / "shoot_super.wav",
        mix(tone(660, 0.12, vol=0.2), tone(990, 0.12, vol=0.12, wave_type="tri")),
    )
    write_wav(SFX / "hit_brick.wav", mix(noise(0.08, vol=0.2, decay=0.04), tone(180, 0.06, vol=0.15)))
    write_wav(SFX / "hit_steel.wav", tone(220, 0.07, vol=0.18, wave_type="tri", decay=0.04))
    write_wav(
        SFX / "explode.wav",
        mix(noise(0.35, vol=0.32, decay=0.12), tone(90, 0.28, vol=0.25, decay=0.1)),
    )
    write_wav(
        SFX / "powerup.wav",
        concat(
            tone(523, 0.08, vol=0.22),
            tone(659, 0.08, vol=0.22),
            tone(784, 0.12, vol=0.24),
            tone(1046, 0.16, vol=0.2, decay=0.12),
        ),
    )
    write_wav(
        SFX / "bonus.wav",
        concat(tone(784, 0.1, vol=0.2), tone(1046, 0.18, vol=0.22, decay=0.15)),
    )
    write_wav(
        SFX / "gameover.wav",
        concat(
            tone(392, 0.18, vol=0.22),
            tone(349, 0.18, vol=0.22),
            tone(311, 0.18, vol=0.22),
            tone(262, 0.4, vol=0.24, decay=0.25),
        ),
    )
    write_wav(
        SFX / "stage.wav",
        concat(tone(523, 0.12, vol=0.2), tone(659, 0.12, vol=0.2), tone(784, 0.22, vol=0.22)),
    )
    write_wav(SFX / "life.wav", concat(tone(659, 0.1, vol=0.2), tone(880, 0.18, vol=0.22)))
    write_wav(SFX / "pause.wav", tone(440, 0.08, vol=0.16, wave_type="tri"))
    write_wav(SFX / "ice.wav", tone(1200, 0.04, vol=0.08, wave_type="tri", decay=0.03))

    # bgm loop ~ 8s candy march
    sr = 22050
    melody = [
        (523, 0.2), (659, 0.2), (784, 0.2), (659, 0.2),
        (587, 0.2), (659, 0.2), (523, 0.4),
        (523, 0.2), (698, 0.2), (784, 0.2), (880, 0.2),
        (784, 0.2), (698, 0.2), (659, 0.4),
        (659, 0.2), (698, 0.2), (784, 0.2), (880, 0.2),
        (1046, 0.4), (880, 0.2), (784, 0.2),
        (698, 0.2), (659, 0.2), (587, 0.2), (523, 0.2),
        (587, 0.2), (659, 0.2), (523, 0.4),
    ]
    bass = [
        (131, 0.4), (196, 0.4), (165, 0.4), (196, 0.4),
        (175, 0.4), (196, 0.4), (131, 0.8),
        (131, 0.4), (220, 0.4), (196, 0.4), (175, 0.4),
        (165, 0.4), (147, 0.4), (131, 0.8),
        (165, 0.4), (175, 0.4), (196, 0.4), (220, 0.4),
        (262, 0.8), (220, 0.4), (196, 0.4),
        (175, 0.4), (165, 0.4), (147, 0.4), (131, 0.4),
        (147, 0.4), (165, 0.4), (131, 0.8),
    ]
    song = []
    tcur = 0.0
    seqs = []
    pos = 0
    for f, d in melody:
        seqs.append(silence(pos) + tone(f, d, sr, vol=0.11, wave_type="square", decay=0.18))
        pos += d
    pos = 0
    for f, d in bass:
        seqs.append(silence(pos) + tone(f, d, sr, vol=0.08, wave_type="tri", decay=0.25))
        pos += d
    # kick-ish on beats
    beat = 0.0
    while beat < pos:
        seqs.append(silence(beat) + tone(90, 0.08, sr, vol=0.07, decay=0.05))
        beat += 0.4
    bgm = mix(*seqs)
    write_wav(SFX / "bgm.wav", bgm, sr)


def make_logo_svg_icon_note():
    pass


def main():
    make_tileset()
    make_tanks()
    make_base()
    make_bullet()
    make_explosion()
    make_spawn()
    make_shield()
    make_powerups()
    make_ui_art()
    make_icon()
    make_sfx()
    print("assets ready")


if __name__ == "__main__":
    main()
