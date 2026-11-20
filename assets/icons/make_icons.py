"""Génère les icônes provisoires (512 x 512) des game passes, developer products et badges.
Fond en dégradé, symbole emoji centré, libellé court facultatif. Tout reste dans le cercle
que Roblox garde au recadrage. Les badges ont un anneau doré."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))  # icônes rangées à côté du script
EMOJI_FONT = r"C:\Windows\Fonts\seguiemj.ttf"
LABEL_FONT = r"C:\Windows\Fonts\seguibl.ttf"  # Segoe UI Black
SIZE = 512

# (dossier, nom de fichier, emoji, libellé ou None, couleur de fond)
ICONS = [
    # Game passes
    ("passes", "bigger_chest", "🧰", "60", (150, 95, 50)),
    ("passes", "luck_x2", "🍀", "x2", (40, 150, 75)),
    ("passes", "auto_dig", "🪏", "AUTO", (225, 120, 40)),
    ("passes", "vip", "👑", "VIP", (215, 165, 30)),
    ("passes", "bodyguard", "💂", None, (45, 70, 140)),
    # Developer products
    ("products", "luck_potion", "🧪", "x3", (125, 60, 185)),
    ("products", "anti_theft_shield", "🛡️", None, (40, 120, 200)),
    ("products", "coin_pouch", "🪙", "5K", (200, 150, 40)),
    ("products", "coin_bag", "💰", "15K", (205, 140, 35)),
    ("products", "coin_chest", "💎", "35K", (215, 125, 30)),
    ("products", "coin_vault", "🏦", "80K", (220, 105, 25)),
    ("products", "server_luck_event", "🌟", "x2", (210, 60, 140)),
    ("products", "revenge", "⚔️", None, (190, 40, 45)),
    # Badges
    ("badges", "first_dig", "⛏️", None, (125, 85, 55)),
    ("badges", "first_secret", "🌈", None, (55, 35, 95)),
    ("badges", "shadow_thief", "🥷", None, (35, 35, 55)),
    ("badges", "chest_guardian", "🔒", None, (35, 110, 95)),
    ("badges", "clay_explorer", "🦴", None, (190, 95, 55)),
    ("badges", "rock_explorer", "🪨", None, (110, 115, 130)),
    ("badges", "dirt_archaeologist", "🔍", None, (160, 115, 70)),
]

GOLD = (245, 200, 70)


def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color)


def background(color):
    """Dégradé vertical, plus clair en haut, et halo doux au centre."""
    img = Image.new("RGB", (SIZE, SIZE))
    top, bottom = shade(color, 1.25), shade(color, 0.7)
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line([(0, y), (SIZE, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    halo = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(halo).ellipse((96, 76, 416, 396), fill=60)
    img.paste(Image.new("RGB", (SIZE, SIZE), (255, 255, 255)), (0, 0), halo.point(lambda v: v // 2))
    return img


def draw_centered_emoji(img, emoji, size, center_y):
    emoji = emoji.replace("️", "")  # le sélecteur de variante fausse la mesure
    font = ImageFont.truetype(EMOJI_FONT, size)
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    left, top, right, bottom = d.textbbox((0, 0), emoji, font=font, embedded_color=True)
    x = (SIZE - (right - left)) / 2 - left
    y = center_y - (bottom - top) / 2 - top
    # ombre portée douce
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + 6, y + 10), emoji, font=font, embedded_color=True)
    alpha = shadow.split()[3].point(lambda v: v * 0.35)
    black = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    img.paste(black, (0, 0), alpha)
    d.text((x, y), emoji, font=font, embedded_color=True)
    img.paste(layer, (0, 0), layer)


def draw_label(img, text, center_y):
    size = 92 if len(text) <= 3 else 76
    font = ImageFont.truetype(LABEL_FONT, size)
    d = ImageDraw.Draw(img)
    left, top, right, bottom = d.textbbox((0, 0), text, font=font)
    x = (SIZE - (right - left)) / 2 - left
    y = center_y - (bottom - top) / 2 - top
    d.text((x, y), text, font=font, fill=(255, 255, 255), stroke_width=8, stroke_fill=(30, 25, 35))


def badge_ring(img):
    d = ImageDraw.Draw(img)
    d.ellipse((22, 22, SIZE - 22, SIZE - 22), outline=shade(GOLD, 0.75), width=18)
    d.ellipse((30, 30, SIZE - 30, SIZE - 30), outline=GOLD, width=8)


def main():
    for folder, name, emoji, label, color in ICONS:
        img = background(color)
        if folder == "badges":
            badge_ring(img)
        if label:
            draw_centered_emoji(img, emoji, 190, 215)
            draw_label(img, label, 375)
        else:
            draw_centered_emoji(img, emoji, 230, 256)
        os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
        path = os.path.join(ROOT, folder, name + ".png")
        img.save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    main()
