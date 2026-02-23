#!/usr/bin/env python3
"""
Generate optimized Meta Ads creatives for PraticOS campaign.

Produces 4 images:
  - whatsapp_feed_1080x1080.png   (Creative 2 - WhatsApp static, Feed)
  - whatsapp_stories_1080x1920.png (Creative 2 - WhatsApp static, Stories)
  - app_feed_1080x1080.png        (Creative 3 - App, Feed)
  - app_stories_1080x1920.png     (Creative 3 - App, Stories)

Usage:
    python3 business/campaigns/meta-ads/creatives/generate_creatives.py
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# --- Paths ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "..", ".."))

WHATSAPP_SCREENSHOT = os.path.join(
    PROJECT_ROOT, "docs", "images",
    "Captura de Tela 2026-02-09 à(s) 18.28.51.png"
)
APP_SCREENSHOT = os.path.join(
    PROJECT_ROOT, "firebase", "hosting", "src", "assets",
    "screenshots", "pt", "light", "home.png"
)
LOGO_PATH = os.path.join(
    PROJECT_ROOT, "firebase", "hosting", "src", "assets",
    "images", "logo.png"
)

OUTPUT_DIR = SCRIPT_DIR

# --- Fonts ---
FONT_PATH = "/System/Library/Fonts/HelveticaNeue.ttc"
FONT_BOLD_INDEX = 1
FONT_MEDIUM_INDEX = 10
FONT_REGULAR_INDEX = 0

# SF NS has checkmarks and stars
SFNS_PATH = "/System/Library/Fonts/SFNS.ttf"

# --- Colors ---
GRADIENT_TOP = (10, 30, 80)       # Deep navy blue
GRADIENT_BOTTOM = (20, 60, 140)   # Medium blue
ACCENT_BLUE = (59, 130, 246)      # Bright blue
ACCENT_GREEN = (34, 197, 94)      # Green for checkmarks
WHITE = (255, 255, 255)
WHITE_80 = (255, 255, 255, 204)   # 80% opacity
WHITE_60 = (255, 255, 255, 153)   # 60% opacity
BADGE_BG = (255, 255, 255, 30)    # Semi-transparent white


def create_gradient(width, height, top_color, bottom_color):
    """Create a vertical gradient background."""
    img = Image.new("RGB", (width, height))
    for y in range(height):
        ratio = y / height
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        for x in range(width):
            img.putpixel((x, y), (r, g, b))
    return img


def create_gradient_fast(width, height, top_color, bottom_color):
    """Create a vertical gradient background (fast version using lines)."""
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        ratio = y / height
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    return img


def add_rounded_corners(img, radius):
    """Add rounded corners to an image."""
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    result = Image.new("RGBA", img.size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def add_shadow(img, offset=(8, 8), blur_radius=20, shadow_color=(0, 0, 0, 100)):
    """Add drop shadow to an RGBA image."""
    shadow_size = (
        img.width + abs(offset[0]) + blur_radius * 2,
        img.height + abs(offset[1]) + blur_radius * 2,
    )
    shadow = Image.new("RGBA", shadow_size, (0, 0, 0, 0))

    # Create shadow from alpha channel
    alpha = img.split()[3]
    shadow_layer = Image.new("RGBA", img.size, shadow_color)
    shadow_layer.putalpha(alpha)

    shadow.paste(
        shadow_layer,
        (blur_radius + max(offset[0], 0), blur_radius + max(offset[1], 0)),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))

    # Paste original on top
    shadow.paste(
        img,
        (blur_radius + max(-offset[0], 0), blur_radius + max(-offset[1], 0)),
        img,
    )
    return shadow


def draw_text_with_shadow(draw, position, text, font, fill=WHITE, shadow_offset=2):
    """Draw text with a subtle shadow for readability."""
    x, y = position
    # Shadow
    draw.text((x + shadow_offset, y + shadow_offset), text, font=font, fill=(0, 0, 0, 120))
    # Main text
    draw.text((x, y), text, font=font, fill=fill)


def draw_badge(draw, position, text, font, bg_color=(255, 255, 255, 25), text_color=WHITE, padding=(16, 8)):
    """Draw a pill-shaped badge with text."""
    x, y = position
    bbox = font.getbbox(text)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    pill_w = text_w + padding[0] * 2
    pill_h = text_h + padding[1] * 2

    # Draw pill background
    draw.rounded_rectangle(
        [(x, y), (x + pill_w, y + pill_h)],
        radius=pill_h // 2,
        fill=bg_color,
    )

    # Draw text centered
    text_x = x + (pill_w - text_w) // 2
    text_y = y + (pill_h - text_h) // 2
    draw.text((text_x, text_y), text, font=font, fill=text_color)

    return pill_w, pill_h


def draw_badge_with_star(draw, position, text, font, font_size, bg_color=(255, 255, 255, 25), text_color=WHITE, star_color=(255, 200, 50), padding=(16, 8)):
    """Draw a badge with a proper star glyph using SFNS font."""
    x, y = position
    # Use SFNS for star
    sfns_font = ImageFont.truetype(SFNS_PATH, font_size)

    # Split text around the star placeholder
    # Expected format: "4.8 STAR  ·  +10.000 OS criadas"
    star_char = "\u2605"
    parts = text.split(star_char)

    bbox = font.getbbox(text)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    pill_w = text_w + padding[0] * 2
    pill_h = text_h + padding[1] * 2

    draw.rounded_rectangle(
        [(x, y), (x + pill_w, y + pill_h)],
        radius=pill_h // 2,
        fill=bg_color,
    )

    if len(parts) == 2:
        text_y = y + (pill_h - text_h) // 2
        # Draw first part
        cx = x + padding[0]
        draw.text((cx, text_y), parts[0], font=font, fill=text_color)
        cx += font.getbbox(parts[0])[2] - font.getbbox(parts[0])[0]
        # Draw star with SFNS
        draw.text((cx, text_y), star_char, font=sfns_font, fill=star_color)
        cx += sfns_font.getbbox(star_char)[2] - sfns_font.getbbox(star_char)[0]
        # Draw rest
        draw.text((cx, text_y), parts[1], font=font, fill=text_color)
    else:
        text_x = x + (pill_w - text_w) // 2
        text_y = y + (pill_h - text_h) // 2
        draw.text((text_x, text_y), text, font=font, fill=text_color)

    return pill_w, pill_h


def draw_check_item(draw, x, y, text, font, font_size, check_color=ACCENT_GREEN, text_color=WHITE_80):
    """Draw a checkmark + text item using SFNS for the checkmark."""
    sfns_font = ImageFont.truetype(SFNS_PATH, font_size)
    draw.text((x, y), "\u2713", font=sfns_font, fill=check_color)
    check_w = sfns_font.getbbox("\u2713")[2] - sfns_font.getbbox("\u2713")[0]
    draw.text((x + check_w + 10, y), text, font=font, fill=text_color)


def load_logo(target_height):
    """Load and resize the PraticOS logo."""
    logo = Image.open(LOGO_PATH).convert("RGBA")
    ratio = target_height / logo.height
    new_w = int(logo.width * ratio)
    return logo.resize((new_w, target_height), Image.LANCZOS)


def create_phone_mockup(screenshot_path, target_height, corner_radius=30):
    """Create a phone-like frame around a screenshot."""
    screenshot = Image.open(screenshot_path).convert("RGBA")

    # Scale screenshot to fit target height (with some padding for frame)
    inner_height = target_height - 20  # padding for frame
    ratio = inner_height / screenshot.height
    inner_width = int(screenshot.width * ratio)
    screenshot = screenshot.resize((inner_width, inner_height), Image.LANCZOS)

    # Add rounded corners
    screenshot = add_rounded_corners(screenshot, corner_radius)

    # Add thin white border (phone frame effect)
    frame = Image.new("RGBA", (inner_width + 8, inner_height + 8), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle(
        [(0, 0), (frame.width - 1, frame.height - 1)],
        radius=corner_radius + 4,
        fill=(255, 255, 255, 40),
    )
    frame.paste(screenshot, (4, 4), screenshot)

    return frame


# ===== CREATIVE 2: WhatsApp Static =====

def generate_whatsapp_feed():
    """Generate WhatsApp creative for Feed (1080x1080)."""
    W, H = 1080, 1080

    # Background gradient
    bg = create_gradient_fast(W, H, GRADIENT_TOP, GRADIENT_BOTTOM)
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Fonts — bigger for impact
    font_headline = ImageFont.truetype(FONT_PATH, 68, index=FONT_BOLD_INDEX)
    font_sub = ImageFont.truetype(FONT_PATH, 30, index=FONT_MEDIUM_INDEX)
    font_badge = ImageFont.truetype(FONT_PATH, 24, index=FONT_MEDIUM_INDEX)

    # Logo (top left)
    logo = load_logo(65)
    overlay.paste(logo, (40, 35), logo)

    # Headline text
    headline = "Crie OS pelo\nWhatsApp"
    draw_text_with_shadow(draw, (40, 115), headline, font_headline, WHITE)

    # Subtitle
    subtitle = "Mande uma foto, um audio ou texto.\nA IA cria a OS pra voce."
    draw.text((40, 280), subtitle, font=font_sub, fill=WHITE_80)

    # WhatsApp screenshot — larger, bleeds off bottom-right
    wa_img = Image.open(WHATSAPP_SCREENSHOT).convert("RGBA")
    crop_top, crop_bottom = 88, 88
    wa_cropped = wa_img.crop((0, crop_top, wa_img.width, wa_img.height - crop_bottom))

    target_h = 850  # much taller, will bleed off bottom
    ratio = target_h / wa_cropped.height
    target_w = int(wa_cropped.width * ratio)
    wa_resized = wa_cropped.resize((target_w, target_h), Image.LANCZOS)
    wa_rounded = add_rounded_corners(wa_resized, 28)

    # Position: right side, bleeds off bottom
    wa_x = W - target_w + 20  # slightly off right edge
    wa_y = 360

    wa_with_shadow = add_shadow(wa_rounded, offset=(6, 6), blur_radius=15, shadow_color=(0, 0, 0, 80))
    overlay.paste(wa_with_shadow, (wa_x - 15, wa_y - 15), wa_with_shadow)

    # Badge bottom left
    draw_badge_with_star(draw, (40, H - 75), "4.8 \u2605  \u00b7  +10.000 OS criadas", font_badge,
                         font_size=24, bg_color=(255, 255, 255, 35))

    # Compose & crop to canvas
    bg = bg.convert("RGBA")
    result = Image.alpha_composite(bg, overlay)
    result = result.crop((0, 0, W, H))

    output = os.path.join(OUTPUT_DIR, "whatsapp_feed_1080x1080.png")
    result.convert("RGB").save(output, quality=95)
    print(f"Saved: {output} ({os.path.getsize(output) / 1024:.0f} KB)")
    return output


def generate_whatsapp_stories():
    """Generate WhatsApp creative for Stories (1080x1920)."""
    W, H = 1080, 1920

    bg = create_gradient_fast(W, H, GRADIENT_TOP, GRADIENT_BOTTOM)
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Fonts — bigger
    font_headline = ImageFont.truetype(FONT_PATH, 72, index=FONT_BOLD_INDEX)
    font_sub = ImageFont.truetype(FONT_PATH, 34, index=FONT_MEDIUM_INDEX)
    font_badge = ImageFont.truetype(FONT_PATH, 26, index=FONT_MEDIUM_INDEX)

    # Logo (top center)
    logo = load_logo(75)
    logo_x = (W - logo.width) // 2
    overlay.paste(logo, (logo_x, 60), logo)

    # Headline (centered)
    headline = "Crie OS pelo\nWhatsApp"
    bbox = draw.textbbox((0, 0), headline, font=font_headline)
    text_w = bbox[2] - bbox[0]
    draw_text_with_shadow(draw, ((W - text_w) // 2, 160), headline, font_headline, WHITE)

    # Subtitle (centered)
    subtitle = "Mande uma foto, um audio\nou texto. A IA cria a OS."
    bbox_sub = draw.textbbox((0, 0), subtitle, font=font_sub)
    sub_w = bbox_sub[2] - bbox_sub[0]
    draw.text(((W - sub_w) // 2, 340), subtitle, font=font_sub, fill=WHITE_80)

    # WhatsApp screenshot — much larger, bleeds off bottom
    wa_img = Image.open(WHATSAPP_SCREENSHOT).convert("RGBA")
    crop_top, crop_bottom = 88, 88
    wa_cropped = wa_img.crop((0, crop_top, wa_img.width, wa_img.height - crop_bottom))

    target_h = 1400  # fills most of the remaining space
    ratio = target_h / wa_cropped.height
    target_w = int(wa_cropped.width * ratio)
    # Cap width
    if target_w > W - 40:
        target_w = W - 40
        ratio = target_w / wa_cropped.width
        target_h = int(wa_cropped.height * ratio)

    wa_resized = wa_cropped.resize((target_w, target_h), Image.LANCZOS)
    wa_rounded = add_rounded_corners(wa_resized, 32)

    wa_x = (W - target_w) // 2
    wa_y = 440

    wa_with_shadow = add_shadow(wa_rounded, offset=(6, 8), blur_radius=18, shadow_color=(0, 0, 0, 80))
    overlay.paste(wa_with_shadow, (wa_x - 18, wa_y - 18), wa_with_shadow)

    # Badge (centered, near bottom but above the bleed area)
    badge_text = "4.8 \u2605  \u00b7  +10.000 OS criadas"
    bbox_badge = font_badge.getbbox(badge_text)
    badge_w = bbox_badge[2] - bbox_badge[0] + 32
    badge_x = (W - badge_w) // 2
    draw_badge_with_star(draw, (badge_x, H - 90), badge_text, font_badge,
                         font_size=26, bg_color=(255, 255, 255, 35))

    # Compose & crop to canvas
    bg = bg.convert("RGBA")
    result = Image.alpha_composite(bg, overlay)
    result = result.crop((0, 0, W, H))

    output = os.path.join(OUTPUT_DIR, "whatsapp_stories_1080x1920.png")
    result.convert("RGB").save(output, quality=95)
    print(f"Saved: {output} ({os.path.getsize(output) / 1024:.0f} KB)")
    return output


# ===== CREATIVE 3: App =====

def generate_app_feed():
    """Generate App creative for Feed (1080x1080)."""
    W, H = 1080, 1080

    bg = create_gradient_fast(W, H, GRADIENT_TOP, GRADIENT_BOTTOM)
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Fonts — significantly bigger
    font_headline = ImageFont.truetype(FONT_PATH, 64, index=FONT_BOLD_INDEX)
    font_badge = ImageFont.truetype(FONT_PATH, 24, index=FONT_MEDIUM_INDEX)
    font_check = ImageFont.truetype(FONT_PATH, 28, index=FONT_MEDIUM_INDEX)

    # Logo (top left)
    logo = load_logo(65)
    overlay.paste(logo, (40, 30), logo)

    # Headline — tighter to logo
    headline = "Chega de papel.\nControle suas OS\nno app."
    draw_text_with_shadow(draw, (40, 110), headline, font_headline, WHITE)

    # Checkmarks — bigger text
    checks = [
        "OS com fotos e valores",
        "Controle financeiro",
        "Agenda com lembretes",
    ]
    y_check = 330
    for check in checks:
        draw_check_item(draw, 40, y_check, check, font_check, font_size=28)
        y_check += 42

    # App screenshot — much larger phone, bleeds off bottom-right
    phone = create_phone_mockup(APP_SCREENSHOT, 950)
    phone_x = W - phone.width + 60  # bleeds off right edge
    phone_y = 280  # starts higher, bleeds off bottom

    phone_with_shadow = add_shadow(phone, offset=(6, 6), blur_radius=18, shadow_color=(0, 0, 0, 80))
    overlay.paste(phone_with_shadow, (phone_x - 18, phone_y - 18), phone_with_shadow)

    # Badge
    draw_badge(draw, (40, H - 75), "Gratis para comecar  \u00b7  Sem cartao", font_badge,
               bg_color=(255, 255, 255, 35))

    # Compose & crop to canvas
    bg = bg.convert("RGBA")
    result = Image.alpha_composite(bg, overlay)
    result = result.crop((0, 0, W, H))

    output = os.path.join(OUTPUT_DIR, "app_feed_1080x1080.png")
    result.convert("RGB").save(output, quality=95)
    print(f"Saved: {output} ({os.path.getsize(output) / 1024:.0f} KB)")
    return output


def generate_app_stories():
    """Generate App creative for Stories (1080x1920)."""
    W, H = 1080, 1920

    bg = create_gradient_fast(W, H, GRADIENT_TOP, GRADIENT_BOTTOM)
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Fonts — bigger
    font_headline = ImageFont.truetype(FONT_PATH, 70, index=FONT_BOLD_INDEX)
    font_badge = ImageFont.truetype(FONT_PATH, 26, index=FONT_MEDIUM_INDEX)
    font_check = ImageFont.truetype(FONT_PATH, 32, index=FONT_MEDIUM_INDEX)

    # Logo (top center)
    logo = load_logo(75)
    logo_x = (W - logo.width) // 2
    overlay.paste(logo, (logo_x, 55), logo)

    # Headline (centered)
    headline = "Chega de papel.\nControle suas OS\nno app."
    bbox = draw.textbbox((0, 0), headline, font=font_headline)
    text_w = bbox[2] - bbox[0]
    draw_text_with_shadow(draw, ((W - text_w) // 2, 155), headline, font_headline, WHITE)

    # Checkmarks (centered) — bigger
    checks = [
        "OS com fotos e valores",
        "Controle financeiro",
        "Agenda com lembretes",
    ]
    sfns_check = ImageFont.truetype(SFNS_PATH, 32)
    check_w_char = sfns_check.getbbox("\u2713")[2] - sfns_check.getbbox("\u2713")[0]
    y_check = 405
    for check in checks:
        text_w_item = font_check.getbbox(check)[2] - font_check.getbbox(check)[0]
        total_w = check_w_char + 12 + text_w_item
        start_x = (W - total_w) // 2
        draw.text((start_x, y_check), "\u2713", font=sfns_check, fill=ACCENT_GREEN)
        draw.text((start_x + check_w_char + 12, y_check), check, font=font_check, fill=WHITE_80)
        y_check += 48

    # App screenshot — much larger phone, bleeds off bottom
    phone = create_phone_mockup(APP_SCREENSHOT, 1350)
    phone_x = (W - phone.width) // 2
    phone_y = 560

    phone_with_shadow = add_shadow(phone, offset=(6, 8), blur_radius=18, shadow_color=(0, 0, 0, 80))
    overlay.paste(phone_with_shadow, (phone_x - 18, phone_y - 18), phone_with_shadow)

    # Badge (centered, near bottom)
    badge_text = "Gratis para comecar  \u00b7  Sem cartao"
    bbox_badge = font_badge.getbbox(badge_text)
    badge_w = bbox_badge[2] - bbox_badge[0] + 32
    badge_x = (W - badge_w) // 2
    draw_badge(draw, (badge_x, H - 90), badge_text, font_badge,
               bg_color=(255, 255, 255, 35))

    # Compose & crop to canvas
    bg = bg.convert("RGBA")
    result = Image.alpha_composite(bg, overlay)
    result = result.crop((0, 0, W, H))

    output = os.path.join(OUTPUT_DIR, "app_stories_1080x1920.png")
    result.convert("RGB").save(output, quality=95)
    print(f"Saved: {output} ({os.path.getsize(output) / 1024:.0f} KB)")
    return output


def main():
    print("=== Generating PraticOS Meta Ads Creatives ===\n")

    print("--- Creative 2: WhatsApp Static ---")
    generate_whatsapp_feed()
    generate_whatsapp_stories()

    print("\n--- Creative 3: App ---")
    generate_app_feed()
    generate_app_stories()

    print(f"\nDone! All creatives saved to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
