"""Puts a caption over the store screenshots (App Store and Google Play).

Each phone screenshot becomes: brand-blue background, one short sentence
on top and the screenshot below it, with rounded corners. The word "IA"/"AI"
gets the logo yellow, like a highlighter.

Frames in place and marks the PNG, so running it twice does nothing; the
screenshot lanes write raw screenshots again. Tablets stay raw.

    python3 scripts/store_screenshots/frame.py

Font: Archivo (SIL Open Font License, github.com/google/fonts), the site's
title font.
"""

import glob
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont, PngImagePlugin

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONT = os.path.join(os.path.dirname(__file__), 'Archivo.ttf')
MARK = 'PraticOSFrame'

BLUE = (17, 107, 181)
WHITE = (255, 255, 255)
YELLOW = (255, 214, 64)

# Shot name (without number) → caption per locale. Keep each under ~30
# characters so it fits in two lines.
CAPTIONS = {
    'ai_order': {
        'pt-BR': 'Fale e a IA preenche a OS',
        'en-US': 'Say it and AI fills in the job',
        'es-ES': 'Dilo y la IA rellena la orden',
    },
    'home': {
        'pt-BR': 'Suas OS e o próximo passo',
        'en-US': "Your jobs and what's next",
        'es-ES': 'Tus órdenes y el siguiente paso',
    },
    'order': {
        'pt-BR': 'A OS inteira numa tela só',
        'en-US': 'The whole job on one screen',
        'es-ES': 'Toda la orden en una pantalla',
    },
    'agenda': {
        'pt-BR': 'Sua agenda de atendimentos',
        'en-US': 'Your appointments at a glance',
        'es-ES': 'Tu agenda de visitas',
    },
    'financial': {
        'pt-BR': 'Veja quanto falta receber',
        'en-US': "See what's left to collect",
        'es-ES': 'Mira cuánto te falta cobrar',
    },
    'checklist': {
        'pt-BR': 'Checklists com fotos',
        'en-US': 'Checklists with photos',
        'es-ES': 'Checklists con fotos',
    },
    'customer': {
        'pt-BR': 'O histórico de cada cliente',
        'en-US': "Every customer's history",
        'es-ES': 'El historial de cada cliente',
    },
}

HIGHLIGHT = {'IA', 'AI'}


def font(size):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name('Bold')
    return f


def wrap(draw, text, f, width):
    """One line if it fits, else two lines of similar length."""
    if draw.textlength(text, font=f) <= width:
        return [text]
    words = text.split()
    best = None
    for i in range(1, len(words)):
        a, b = ' '.join(words[:i]), ' '.join(words[i:])
        longest = max(draw.textlength(a, font=f), draw.textlength(b, font=f))
        if best is None or longest < best[0]:
            best = (longest, [a, b])
    return best[1]


def draw_line(draw, line, f, cx, y):
    """Centered line; highlighted words in yellow."""
    space = draw.textlength(' ', font=f)
    words = line.split()
    total = sum(draw.textlength(w, font=f) for w in words) + space * (len(words) - 1)
    x = cx - total / 2
    for w in words:
        color = YELLOW if w.strip('.,!') in HIGHLIGHT else WHITE
        draw.text((x, y), w, font=f, fill=color)
        x += draw.textlength(w, font=f) + space


def frame(shot, caption, size):
    W, H = size
    canvas = Image.new('RGB', size, BLUE)
    draw = ImageDraw.Draw(canvas)

    f = font(int(W * 0.082))
    lines = wrap(draw, caption, f, W * 0.86)
    line_h = int(f.size * 1.18)
    top = int(H * 0.055)
    for i, line in enumerate(lines):
        draw_line(draw, line, f, W / 2, top + i * line_h)
    text_bottom = top + len(lines) * line_h

    # Screenshot: 84% of the width, starts under the text, runs off the
    # bottom edge.
    # Drop the status bar (and the dark band behind sheets).
    shot = shot.crop((0, int(shot.height * 0.072), shot.width, shot.height))
    sw = int(W * 0.84)
    sh = int(shot.height * sw / shot.width)
    shot = shot.convert('RGB').resize((sw, sh), Image.LANCZOS)
    radius = int(sw * 0.07)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), radius, fill=255)
    x = (W - sw) // 2
    y = text_bottom + int(H * 0.035)

    shadow = Image.new('L', size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x, y + 12, x + sw, y + sh + 12), radius, fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(Image.new('RGB', size, (8, 50, 90)), (0, 0), shadow)
    canvas.paste(shot, (x, y), mask)
    return canvas


def caption_for(path, locale):
    name = os.path.splitext(os.path.basename(path))[0]
    key = re.sub(r'^.*?\d\d_', '', name)
    return CAPTIONS.get(key, {}).get(locale)


def process(path, locale, size):
    im = Image.open(path)
    if im.info.get(MARK):
        return False
    if im.size == (1200, 2400):
        # Padded to 2:1 for Play earlier: back to the phone's 1080 width.
        im = im.crop((60, 0, 1140, 2400))
    caption = caption_for(path, locale)
    if not caption:
        print(f'⚠️ no caption: {path}')
        return False
    out = frame(im, caption, size(im))
    meta = PngImagePlugin.PngInfo()
    meta.add_text(MARK, '1')
    out.save(path, pnginfo=meta, optimize=True)
    return True


def main():
    done = 0
    # App Store: same size as the screenshot (6.9" is 1320x2868).
    for path in sorted(glob.glob(f'{ROOT}/ios/fastlane/screenshots/*/*.png')):
        locale = os.path.basename(os.path.dirname(path))
        done += process(path, locale, lambda im: im.size)
    # Google Play phone: 9:16, 1080x1920.
    for path in sorted(glob.glob(
            f'{ROOT}/android/fastlane/metadata/android/*/images/phoneScreenshots/*.png')):
        locale = path.split('/metadata/android/')[1].split('/')[0]
        done += process(path, locale, lambda im: (1080, 1920))
    print(f'✅ Framed {done} screenshots')


if __name__ == '__main__':
    main()
