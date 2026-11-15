"""Genera el ícono de Recordame a partir del logo que eligió el usuario
(lapicera + almanaque + tilde, `tool/logo/original.jpg`).

Uso: python3 tool/generar_iconos.py
Escribe res/mipmap-*/ic_launcher[_<color>].png (las 8 combinaciones de
Configuración → Colores, mismas que `appIcons` en lib/core/palette.dart),
assets/iconos/<id>.png (la vista previa dentro de la app) y los de web/.

"Clásico" es el logo tal cual. Los demás se pintan de nuevo: el fondo azul
pasa al color de fondo y lo dorado/plateado al color del dibujo, conservando
las luces y sombras del original.
"""

import os

import numpy as np
from PIL import Image, ImageDraw

RES = 'android/app/src/main/res'
SIZES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ORIGINAL = 'tool/logo/original.jpg'
# Recorte del cuadrado azul (sin el borde plateado de afuera).
CROP = (18, 20, 478, 480)

# (id, fondo, dibujo). Mismos colores que `appIcons`; None = el original.
VARIANTS = [
    ('clasico', None, None),
    ('rojo', '#C62828', '#FFFFFF'),
    ('naranja', '#E8A33D', '#2B3A67'),
    ('verde', '#2E6B4F', '#F5D76E'),
    ('violeta', '#5B3F8C', '#F6B7D2'),
    ('negro', '#1C1C1E', '#E0B84F'),
    ('blanco', '#FFFFFF', '#2B3A67'),
    ('celeste', '#3FA7D6', '#FFFFFF'),
]

NAVY = np.array([28, 45, 75], float)


def rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def base():
    im = Image.open(ORIGINAL).convert('RGB').crop(CROP)
    return np.asarray(im).astype(float)


def recolor(a, bg, fg):
    r, b = a[..., 0], a[..., 2]
    l = lum(a)
    # Cuánto de cada pixel es dibujo (dorado o plateado) y cuánto fondo azul.
    m = np.clip((r - b + 25) / 40, 0, 1)
    m = np.maximum(m, np.clip((l - 95) / 45, 0, 1))
    m = m[..., None]
    # Fondo: el color elegido con las mismas sombras del azul original.
    shade = np.clip(l / lum(NAVY), 0.55, 1.35)[..., None]
    if lum(bg) > 200:  # fondo muy claro: las sombras van más suaves
        shade = 1 - (1 - shade) * 0.35
    back = bg * shade
    # Dibujo: el color elegido, más oscuro en las sombras del metal y con
    # brillos hacia el blanco.
    v = (l / 185)[..., None]
    dark = fg * np.clip(v, 0.35, 1)
    bright = fg + (255 - fg) * np.clip(v - 1, 0, 0.6)
    front = np.where(v > 1, bright, dark)
    out = back * (1 - m) + front * m
    return np.clip(out, 0, 255)


def rounded(im, radius=0.22):
    s = im.size[0]
    k = 4
    mask = Image.new('L', (s * k, s * k), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s * k - 1, s * k - 1], radius=s * k * radius, fill=255)
    out = im.convert('RGBA')
    out.putalpha(mask.resize((s, s), Image.LANCZOS))
    return out


def image(bg, fg):
    a = base()
    if bg is not None:
        a = recolor(a, rgb(bg), rgb(fg))
    return Image.fromarray(a.astype('uint8'), 'RGB')


def main():
    os.makedirs('assets/iconos', exist_ok=True)
    for vid, bg, fg in VARIANTS:
        big = image(bg, fg)
        name = 'ic_launcher' if vid == 'clasico' else f'ic_launcher_{vid}'
        for density, px in SIZES.items():
            rounded(big.resize((px, px), Image.LANCZOS)).save(os.path.join(RES, f'mipmap-{density}', f'{name}.png'))
        rounded(big.resize((144, 144), Image.LANCZOS)).save(f'assets/iconos/{vid}.png')
    big = image(None, None)
    for px in (192, 512):
        rounded(big.resize((px, px), Image.LANCZOS)).save(f'web/icons/Icon-{px}.png')
        big.resize((px, px), Image.LANCZOS).save(f'web/icons/Icon-maskable-{px}.png')
    rounded(big.resize((32, 32), Image.LANCZOS)).save('web/favicon.png')


if __name__ == '__main__':
    main()
