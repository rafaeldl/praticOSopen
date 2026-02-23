#!/usr/bin/env python3
"""
Generate Meta Ads creatives using Gemini image generation API.

Produces AI-generated ad images for the PraticOS campaign:
  - Creative 1: WhatsApp OS creation flow
  - Creative 2: App overview with phone mockup
  - Creative 3: Financial dashboard / business control

Usage:
    python3 business/campaigns/meta-ads/creatives/generate_gemini_creatives.py
"""

import os
import yaml
import requests
import json
import base64
import io
import time
from PIL import Image

# --- Config ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CREDS = yaml.safe_load(open(os.path.expanduser("~/.gemini.yaml")))
API_KEY = CREDS["api_key"]
MODEL = "gemini-3-pro-image-preview"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"

OUTPUT_DIR = SCRIPT_DIR
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "..", ".."))
LOGO_PATH = os.path.join(
    PROJECT_ROOT, "firebase", "hosting", "src", "assets", "images", "logo.png"
)
HOME_PATH = os.path.join(
    PROJECT_ROOT, "firebase", "hosting", "src", "assets", "screenshots", "pt", "light", "home.png"
)
DASHBOARD_PATH = os.path.join(
    PROJECT_ROOT, "firebase", "hosting", "src", "assets", "screenshots", "pt", "light", "dashboard.png"
)


def load_image_base64(path):
    """Load an image as base64 for Gemini API."""
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


LOGO_B64 = load_image_base64(LOGO_PATH)
HOME_B64 = load_image_base64(HOME_PATH)
DASHBOARD_B64 = load_image_base64(DASHBOARD_PATH)


def generate_image(prompt, output_name, extra_images=None, retries=2):
    """Generate an image using Gemini API with the real logo as reference.

    Args:
        extra_images: List of base64-encoded images to include as additional references.
    """
    parts = [
        {
            "inlineData": {
                "mimeType": "image/png",
                "data": LOGO_B64,
            }
        },
    ]
    for img_b64 in (extra_images or []):
        parts.append({
            "inlineData": {
                "mimeType": "image/png",
                "data": img_b64,
            }
        })
    parts.append({"text": prompt})

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"],
        },
    }

    for attempt in range(retries + 1):
        print(f"  Generating {output_name} (attempt {attempt + 1})...")
        resp = requests.post(URL, json=payload, timeout=180)

        if resp.status_code == 200:
            data = resp.json()
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                for part in parts:
                    if "inlineData" in part:
                        img_data = base64.b64decode(part["inlineData"]["data"])
                        img = Image.open(io.BytesIO(img_data))
                        native_w, native_h = img.size
                        print(f"  Native size: {native_w}x{native_h}")

                        # Place on 1080x1080 canvas (center the native image)
                        canvas = Image.new("RGB", (1080, 1080), (10, 30, 80))
                        # Scale up to fill 1080x1080 using high-quality resampling
                        img_resized = img.resize((1080, 1080), Image.LANCZOS)
                        canvas.paste(img_resized, (0, 0))

                        output = os.path.join(OUTPUT_DIR, output_name)
                        # Save as high-quality JPEG (Meta prefers JPEG, avoids PNG metadata issues)
                        output_jpg = output.replace('.png', '.jpg')
                        canvas.save(output_jpg, "JPEG", quality=98, subsampling=0)
                        # Also save PNG version
                        canvas.save(output, "PNG", quality=95)
                        size_kb = os.path.getsize(output_jpg) / 1024
                        print(f"  Saved: {output_jpg} (1080x1080, {size_kb:.0f}KB)")
                        return output_jpg

            print(f"  No image in response")
        elif resp.status_code == 429:
            print(f"  Rate limited, waiting 30s...")
            time.sleep(30)
            continue
        else:
            print(f"  Error {resp.status_code}: {resp.text[:300]}")

        if attempt < retries:
            time.sleep(5)

    print(f"  FAILED to generate {output_name}")
    return None


# --- Creative Prompts ---

LOGO_INSTRUCTION = """IMPORTANT - LOGO: The attached image is the official PraticOS logo. You MUST use this EXACT logo in the top-left corner of the ad. Do NOT generate or invent a different logo. Reproduce the attached logo faithfully — it shows "PRATIC" in white and "OS" in yellow on a blue background with an orange accent."""

CREATIVE_WHATSAPP = f"""Generate a professional mobile app advertisement image.

{LOGO_INSTRUCTION}

This is a premium ad for "PraticOS" - an app that lets you create work orders (service orders) via WhatsApp using AI.

LAYOUT:
- Square format (1:1 ratio), 1080x1080 pixels
- Dark navy blue gradient background (#0A1E50 to #143C8C)
- LEFT SIDE: Bold white text and the attached PraticOS logo (top-left)
- RIGHT SIDE: A large WhatsApp chat screenshot showing a conversation with a bot

TEXT CONTENT (in Portuguese):
- Top-left: The attached PraticOS logo (use it exactly as provided)
- Main headline (large, bold, white): "Crie OS pelo WhatsApp"
- Subtitle (smaller, white 80% opacity): "Mande uma foto, um áudio ou texto. A IA cria a OS pra você."
- Bottom badge (pill shape, semi-transparent): "4.8★ · +10.000 OS criadas"

WHATSAPP CHAT (right side):
- Show a realistic WhatsApp conversation between a user and "PraticOS" bot
- The bot identifies a vehicle from a photo (Hyundai HB20)
- User says "Vamos fazer um polimento. 300 reais"
- Bot responds with "OS #175 criada!" with a summary

STYLE: Clean, premium, professional SaaS ad. Apple-quality aesthetic. Modern typography. No people.
"""

CREATIVE_APP = f"""Generate a professional mobile app advertisement image.

IMPORTANT - LOGO: The FIRST attached image is the official PraticOS logo. You MUST use this EXACT logo in the top-left corner of the ad. Do NOT generate or invent a different logo. Reproduce the attached logo faithfully — it shows "PRATIC" in white and "OS" in yellow on a blue background with an orange accent.

IMPORTANT - APP SCREEN: The SECOND attached image is the REAL app screenshot showing the work orders list ("Ordens de Serviço"). You MUST reproduce this screen EXACTLY as shown inside the iPhone mockup. Show the real list with work orders, car photos, status badges (#1, #2, #3, #4), customer names, and the bottom tab bar (Início, Clientes, Agenda, Financeiro, Mais). Do NOT invent a different screen.

This is a premium ad for "PraticOS" - a work order management app for service technicians and small businesses.

LAYOUT:
- Square format (1:1 ratio), 1080x1080 pixels
- Dark navy blue gradient background (#0A1E50 to #143C8C)
- LEFT SIDE: Bold text and feature list
- RIGHT SIDE: A large iPhone mockup showing the REAL app screenshot (second attached image)

TEXT CONTENT (in Portuguese):
- Top-left: The attached PraticOS logo (use it exactly as provided)
- Main headline (large, bold, white): "Chega de papel. Controle suas OS no app."
- Three green checkmarks with text:
  ✓ OS com fotos e valores
  ✓ Controle financeiro
  ✓ Agenda com lembretes
- Bottom badge (pill shape): "Grátis para começar · Sem cartão"

APP SCREEN (right side, large iPhone mockup):
- Use the REAL screenshot from the second attached image
- Show it inside a modern iPhone frame with rounded corners
- The phone should be large, prominent, and slightly angled
- The real screen shows: "Ordens de Serviço" title, search bar, list of work orders with car photo thumbnails, colored status badges, customer names, service types, dates

STYLE: Clean, premium, Apple App Store ad quality. The phone should be large and prominent, slightly angled. Modern, professional. No people.
"""

CREATIVE_DASHBOARD = f"""Generate a professional mobile app advertisement image.

IMPORTANT - LOGO: The FIRST attached image is the official PraticOS logo. You MUST use this EXACT logo in the top-left corner of the ad. Do NOT generate or invent a different logo. Reproduce the attached logo faithfully — it shows "PRATIC" in white and "OS" in yellow on a blue background with an orange accent.

IMPORTANT - DASHBOARD SCREEN: The SECOND attached image is the REAL financial dashboard screenshot from the PraticOS app. You MUST reproduce this screen EXACTLY as shown inside the iPhone mockup. It shows "Painel Financeiro" with revenue cards and charts. Do NOT invent a different screen.

This is a premium ad for "PraticOS" - a business management app showing financial control features.

LAYOUT:
- Square format (1:1 ratio), 1080x1080 pixels
- Dark navy blue gradient background (#0A1E50 to #143C8C)
- LEFT SIDE: Bold text and value proposition
- RIGHT SIDE: A large iPhone mockup showing the REAL financial dashboard (second attached image)

TEXT CONTENT (in Portuguese):
- Top-left: The attached PraticOS logo (use it exactly as provided)
- Main headline (large, bold, white): "Saiba quanto você fatura. Sem planilha."
- Subtitle (white 80%%): "Faturamento, recebimentos e agenda na palma da mão."
- Three green checkmarks:
  ✓ Receita por período
  ✓ Serviços mais lucrativos
  ✓ Agenda de atendimentos
- Bottom badge: "+500 empresas · Comece grátis"

DASHBOARD SCREEN (right side, large iPhone):
- Use the REAL screenshot from the second attached image
- Show it inside a modern iPhone frame with rounded corners
- The phone should be large and prominent

STYLE: Clean, premium, professional SaaS ad. Apple-quality aesthetic. The phone should be large. No people.
"""


def main():
    print("=== Generating PraticOS Meta Ads Creatives with Gemini ===\n")

    creatives = [
        ("gemini_whatsapp_1080x1080.png", CREATIVE_WHATSAPP, None),
        ("gemini_app_1080x1080.png", CREATIVE_APP, [HOME_B64]),
        ("gemini_dashboard_1080x1080.png", CREATIVE_DASHBOARD, [DASHBOARD_B64]),
    ]

    results = []
    for filename, prompt, extra_imgs in creatives:
        print(f"\n--- {filename} ---")
        result = generate_image(prompt, filename, extra_images=extra_imgs)
        results.append(result)
        time.sleep(5)  # Rate limit buffer

    print(f"\n=== Summary ===")
    for r in results:
        status = "OK" if r else "FAILED"
        print(f"  [{status}] {r or 'N/A'}")


if __name__ == "__main__":
    main()
