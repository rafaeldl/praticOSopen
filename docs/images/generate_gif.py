#!/usr/bin/env python3
"""
Generate animated GIF and WebP from WhatsApp OS creation flow screenshots.

Produces:
  - Original GIF (360px) in docs/images/
  - Optimized GIF (280px, 128 colors) for website
  - Animated WebP (280px, quality=75) for website

Usage:
    python3 docs/images/generate_gif.py
"""

import glob
import os
from PIL import Image

# --- Parameters ---
INPUT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(INPUT_DIR, "..", ".."))
WEBSITE_ASSETS = os.path.join(PROJECT_ROOT, "firebase", "hosting", "src", "assets", "images")

# Original output (docs)
OUTPUT_PATH = os.path.join(INPUT_DIR, "whatsapp-criar-os.gif")
OUTPUT_WIDTH = 360

# Website outputs (optimized)
WEB_OUTPUT_GIF = os.path.join(WEBSITE_ASSETS, "whatsapp-bot-demo.gif")
WEB_OUTPUT_WEBP = os.path.join(WEBSITE_ASSETS, "whatsapp-bot-demo.webp")
WEB_WIDTH = 240
WEB_COLORS = 32

CROP_TOP = 88
CROP_BOTTOM = 88
FRAME_DELAY_MS = 2500
LAST_FRAME_DELAY_MS = 4000


def load_frames(target_width):
    """Load and process screenshot frames at a given width."""
    pattern = os.path.join(INPUT_DIR, "Captura de Tela *.png")
    files = sorted(glob.glob(pattern))

    if not files:
        print("No screenshots found!")
        return []

    print(f"Found {len(files)} screenshots")

    frames = []
    for f in files:
        img = Image.open(f)
        w, h = img.size

        cropped = img.crop((0, CROP_TOP, w, h - CROP_BOTTOM))

        crop_w, crop_h = cropped.size
        new_h = int(crop_h * target_width / crop_w)
        resized = cropped.resize((target_width, new_h), Image.LANCZOS)

        rgb = Image.new("RGB", resized.size, (255, 255, 255))
        rgb.paste(resized, mask=resized.split()[3])

        frames.append(rgb)
        print(f"  Processed: {os.path.basename(f)} -> {target_width}x{new_h}")

    return frames


def save_gif(frames, output_path, quantize_colors=None):
    """Save frames as animated GIF, optionally with reduced color palette."""
    durations = [FRAME_DELAY_MS] * len(frames)
    durations[-1] = LAST_FRAME_DELAY_MS

    if quantize_colors:
        quantized = [f.quantize(colors=quantize_colors) for f in frames]
        quantized[0].save(
            output_path,
            save_all=True,
            append_images=quantized[1:],
            duration=durations,
            loop=0,
            optimize=True,
        )
    else:
        frames[0].save(
            output_path,
            save_all=True,
            append_images=frames[1:],
            duration=durations,
            loop=0,
            optimize=True,
        )

    size_kb = os.path.getsize(output_path) / 1024
    print(f"  GIF saved: {output_path}")
    print(f"  Size: {size_kb:.0f} KB")


def save_webp(frames, output_path, quality=75):
    """Save frames as animated WebP."""
    durations = [FRAME_DELAY_MS] * len(frames)
    durations[-1] = LAST_FRAME_DELAY_MS

    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        quality=quality,
    )

    size_kb = os.path.getsize(output_path) / 1024
    print(f"  WebP saved: {output_path}")
    print(f"  Size: {size_kb:.0f} KB")


def main():
    # 1. Original GIF (360px, full colors) for docs
    print("\n=== Original GIF (360px) ===")
    frames_original = load_frames(OUTPUT_WIDTH)
    if not frames_original:
        return
    save_gif(frames_original, OUTPUT_PATH)

    # 2. Optimized versions for website (280px)
    print(f"\n=== Website GIF ({WEB_WIDTH}px, {WEB_COLORS} colors) ===")
    frames_web = load_frames(WEB_WIDTH)

    os.makedirs(WEBSITE_ASSETS, exist_ok=True)

    save_gif(frames_web, WEB_OUTPUT_GIF, quantize_colors=WEB_COLORS)

    # 3. Animated WebP for website
    print(f"\n=== Website WebP ({WEB_WIDTH}px, q=75) ===")
    save_webp(frames_web, WEB_OUTPUT_WEBP, quality=75)

    print(f"\nDone! {len(frames_original)} frames processed.")


if __name__ == "__main__":
    main()
