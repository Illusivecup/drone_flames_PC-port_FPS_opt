#!/usr/bin/env python3
"""
Generate high-resolution Retina background images and ICNS volume icon for macOS DMG installer.
Creates:
  - packaging/macos/background.png (600x400)
  - packaging/macos/background@2x.png (1200x800)
  - packaging/macos/background.tiff (Combined Multi-Resolution HiDPI TIFF)
  - packaging/macos/VolumeIcon.icns (Disk Volume Icon)
"""

import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG_DIR = os.path.join(ROOT_DIR, "packaging", "macos")
os.makedirs(PKG_DIR, exist_ok=True)

def generate_background():
    # 2x Retina Dimensions (Logical: 600x400 -> Physical: 1200x800)
    W, H = 1200, 800
    im = Image.new("RGBA", (W, H), (18, 22, 30, 255))
    draw = ImageDraw.Draw(im)

    # 1. Smooth Dark Gradient
    for y in range(H):
        t = y / H
        r = int(24 * (1 - t * 0.45))
        g = int(30 * (1 - t * 0.45))
        b = int(42 * (1 - t * 0.40))
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

    # 2. Subtle Radial Glow behind central arrow
    cx, cy = 600, 395
    for r in range(360, 0, -4):
        alpha = int(24 * (1 - r / 360))
        draw.ellipse(
            [cx - r, cy - int(r * 0.65), cx + r, cy + int(r * 0.65)],
            fill=(38, 60, 95, alpha),
        )

    # 3. Delicate tactical dot grid (low opacity, sci-fi military vibe)
    for gx in range(48, W, 48):
        for gy in range(48, H, 48):
            draw.point((gx, gy), fill=(255, 255, 255, 8))

    # 4. Subtle Outer Border & Corner Accents
    draw.rounded_rectangle(
        [(14, 14), (W - 14, H - 14)],
        radius=26,
        outline=(56, 75, 105, 100),
        width=2,
    )

    c_len = 38
    accent_color = (56, 189, 248, 170)  # Cyber cyan
    # Top-Left
    draw.line([(26, 26), (26 + c_len, 26)], fill=accent_color, width=3)
    draw.line([(26, 26), (26, 26 + c_len)], fill=accent_color, width=3)
    # Top-Right
    draw.line([(W - 26 - c_len, 26), (W - 26, 26)], fill=accent_color, width=3)
    draw.line([(W - 26, 26), (W - 26, 26 + c_len)], fill=accent_color, width=3)
    # Bottom-Left
    draw.line([(26, H - 26), (26 + c_len, H - 26)], fill=accent_color, width=3)
    draw.line([(26, H - 26 - c_len), (26, H - 26)], fill=accent_color, width=3)
    # Bottom-Right
    draw.line([(W - 26 - c_len, H - 26), (W - 26, H - 26)], fill=accent_color, width=3)
    draw.line([(W - 26, H - 26 - c_len), (W - 26, H - 26)], fill=accent_color, width=3)

    # Fonts
    def get_font(path, size):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            return ImageFont.load_default()

    font_title = get_font("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 44)
    font_sub = get_font("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    font_arrow_en = get_font("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
    font_arrow_ru = get_font("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
    font_foot = get_font("/System/Library/Fonts/SFNSMono.ttf", 17)

    # Header Title
    title_text = "D R O N E   F L A M E S"
    bb = draw.textbbox((0, 0), title_text, font=font_title)
    tw = bb[2] - bb[0]
    draw.text(((W - tw) // 2, 72), title_text, fill=(248, 250, 252, 240), font=font_title)

    # Subtitle
    sub_text = "DRAG AND DROP TO INSTALL"
    bb_sub = draw.textbbox((0, 0), sub_text, font=font_sub)
    sw = bb_sub[2] - bb_sub[0]
    draw.text(((W - sw) // 2, 130), sub_text, fill=(148, 163, 184, 180), font=font_sub)

    # Subtle Drop Target Circles (centers: left=300, right=900, y=390)
    draw.ellipse([300 - 105, 390 - 105, 300 + 105, 390 + 105], outline=(56, 189, 248, 30), width=2)
    draw.ellipse([900 - 105, 390 - 105, 900 + 105, 390 + 105], outline=(56, 189, 248, 30), width=2)

    # Central Arrow Vector (between x=470 and x=730, y=390)
    ay = 390
    for x in range(480, 690):
        t = (x - 480) / 210
        r = int(56 + t * (249 - 56))
        g = int(189 + t * (115 - 189))
        b = int(248 + t * (22 - 248))
        draw.line([(x, ay - 3), (x, ay + 3)], fill=(r, g, b, 230), width=6)

    # Orange Arrow Head
    arrow_head = [(690, ay - 20), (730, ay), (690, ay + 20), (700, ay)]
    draw.polygon(arrow_head, fill=(249, 115, 22, 255))

    # Inner Chevrons along line
    for cx_pos in [535, 590, 645]:
        draw.line([(cx_pos - 12, ay - 14), (cx_pos + 2, ay)], fill=(255, 255, 255, 215), width=4)
        draw.line([(cx_pos + 2, ay), (cx_pos - 12, ay + 14)], fill=(255, 255, 255, 215), width=4)

    # Prompt text above arrow
    prompt_en = "DRAG TO APPLICATIONS"
    bb_en = draw.textbbox((0, 0), prompt_en, font=font_arrow_en)
    ew = bb_en[2] - bb_en[0]
    draw.text(((W - ew) // 2, ay - 55), prompt_en, fill=(241, 245, 249, 230), font=font_arrow_en)

    # Prompt text below arrow
    prompt_ru = "Перетащите в Программы"
    bb_ru = draw.textbbox((0, 0), prompt_ru, font=font_arrow_ru)
    rw = bb_ru[2] - bb_ru[0]
    draw.text(((W - rw) // 2, ay + 42), prompt_ru, fill=(148, 163, 184, 200), font=font_arrow_ru)

    # Bottom status / telemetry line
    foot_text = "TARGET: /Applications  •  MACOS UNIVERSAL  •  Reborn Team"
    bb_f = draw.textbbox((0, 0), foot_text, font=font_foot)
    fw = bb_f[2] - bb_f[0]
    draw.text(((W - fw) // 2, H - 54), foot_text, fill=(100, 116, 139, 170), font=font_foot)

    # Save 2x and 1x
    bg_2x = os.path.join(PKG_DIR, "background@2x.png")
    bg_1x = os.path.join(PKG_DIR, "background.png")
    bg_tiff = os.path.join(PKG_DIR, "background.tiff")

    im.save(bg_2x)
    im.resize((600, 400), Image.LANCZOS).save(bg_1x)

    # Merge into multi-resolution HiDPI TIFF
    subprocess.check_call([
        "/usr/bin/tiffutil", "-cathidpicheck",
        bg_1x, bg_2x,
        "-out", bg_tiff
    ])
    print(f"Generated HiDPI background: {bg_tiff}")

def generate_icns():
    src_icon = os.path.join(ROOT_DIR, "icon.png")
    if not os.path.isfile(src_icon):
        print(f"Warning: {src_icon} not found, skipping ICNS generation.")
        return

    im = Image.open(src_icon)
    iconset_dir = os.path.join(PKG_DIR, "VolumeIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [16, 32, 64, 128, 256, 512]
    for s in sizes:
        im.resize((s, s), Image.LANCZOS).save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
        im.resize((s * 2, s * 2), Image.LANCZOS).save(os.path.join(iconset_dir, f"icon_{s}x{s}@2x.png"))

    out_icns = os.path.join(PKG_DIR, "VolumeIcon.icns")
    subprocess.check_call(["/usr/bin/iconutil", "-c", "icns", iconset_dir, "-o", out_icns])
    shutil.rmtree(iconset_dir, ignore_errors=True)
    print(f"Generated VolumeIcon.icns: {out_icns}")

if __name__ == "__main__":
    generate_background()
    generate_icns()
