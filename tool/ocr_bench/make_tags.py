"""Gera etiquetas de gôndola sintéticas nos formatos brasileiros, com gabarito.

Para cada etiqueta salva:
  tags/<id>_limpa.png  a etiqueta renderizada
  tags/<id>_foto.jpg   a mesma etiqueta "fotografada" (perspectiva, desfoque, reflexo...)
  tags/gabarito.json   preço esperado, preço normal, EAN, nome e as linhas ideais
                       (texto + caixa de cada elemento), para simular um OCR perfeito.
"""
from __future__ import annotations

import json
import math
import random
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "tags")
OUT.mkdir(exist_ok=True)
rng = random.Random(42)

TG = "/usr/share/texmf/fonts/opentype/public/tex-gyre/"
FONTS = {
    "heros_cn": TG + "texgyreheroscn-bold.otf",
    "arial": "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "dejavu_cn": "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf",
    "inter": "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf",
    "mono": "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf",
    "script": TG + "texgyrechorus-mediumitalic.otf",
}
BODY_FONTS = ["heros_cn", "arial", "dejavu_cn", "inter"]


def font(name, size):
    return ImageFont.truetype(FONTS[name], size)


# --- EAN-13 -----------------------------------------------------------------
L = ["0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"]
G = ["0100111", "0110011", "0011011", "0100001", "0011101", "0111001", "0000101", "0010001", "0001001", "0010111"]
R = ["1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100"]
PARITY = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"]


def ean_check(d12: str) -> str:
    s = sum(int(c) * (3 if i % 2 else 1) for i, c in enumerate(d12))
    return d12 + str((10 - s % 10) % 10)


def ean_bits(code: str) -> str:
    first, left, right = int(code[0]), code[1:7], code[7:]
    bits = "101"
    for p, c in zip(PARITY[first], left):
        bits += (L if p == "L" else G)[int(c)]
    bits += "01010"
    for c in right:
        bits += R[int(c)]
    return bits + "101"


# --- catálogo ---------------------------------------------------------------
PRODUCTS = [
    ("LEITE UHT INTEGRAL ITALAC 1L", "789811", 4.79, "L", 1.0),
    ("ARROZ BRANCO TIO JOAO 5KG", "789603", 27.90, "KG", 5.0),
    ("FEIJAO CARIOCA KICALDO 1KG", "789608", 8.49, "KG", 1.0),
    ("CAFE PILAO TRADICIONAL 500G", "789108", 18.99, "KG", 0.5),
    ("OLEO DE SOJA LIZA 900ML", "789103", 7.69, "L", 0.9),
    ("ACUCAR REFINADO UNIAO 1KG", "789104", 4.99, "KG", 1.0),
    ("SABAO EM PO OMO 1,6KG", "789109", 32.90, "KG", 1.6),
    ("BISCOITO RECHEADO OREO 90G", "762230", 3.49, "KG", 0.09),
    ("PAPEL HIGIENICO NEVE 12 ROLOS", "789110", 21.90, "UN", 12),
    ("MACARRAO ESPAGUETE RENATA 500G", "789605", 5.29, "KG", 0.5),
    ("REFRIGERANTE COCA-COLA 2L", "789489", 10.99, "L", 2.0),
    ("DETERGENTE YPE NEUTRO 500ML", "789102", 2.79, "L", 0.5),
    ("MOLHO DE TOMATE POMAROLA 300G", "789103", 3.19, "KG", 0.3),
    ("CERVEJA HEINEKEN LATA 350ML", "789686", 5.99, "L", 0.35),
]
BULK = [("TOMATE ITALIANO", 8.99), ("BANANA PRATA", 5.49), ("ALCATRA BOVINA", 39.90),
        ("BATATA INGLESA", 6.49), ("PATINHO MOIDO", 42.90), ("MACA GALA", 9.98)]


def money(v: float) -> str:
    return f"{v:.2f}".replace(".", ",")


def int_cents(v: float):
    s = f"{v:.2f}"
    a, b = s.split(".")
    return a, b


def new_ean(prefix: str) -> str:
    return ean_check(prefix + "".join(str(rng.randint(0, 9)) for _ in range(12 - len(prefix))))


# --- desenho com registro das caixas ---------------------------------------
@dataclass
class Item:
    text: str
    left: float
    top: float
    width: float
    height: float


class Canvas:
    def __init__(self, w, h, bg):
        self.img = Image.new("RGB", (w, h), bg)
        self.d = ImageDraw.Draw(self.img)
        self.items: list[Item] = []

    def text(self, xy, s, fnt, fill=(20, 20, 20), anchor="la", record=True, strike=False):
        self.d.text(xy, s, font=fnt, fill=fill, anchor=anchor)
        x0, y0, x1, y1 = self.d.textbbox(xy, s, font=fnt, anchor=anchor)
        if strike:
            ym = (y0 + y1) / 2
            self.d.line([(x0 - 4, ym), (x1 + 4, ym)], fill=fill, width=max(2, (y1 - y0) // 10))
        if record and s.strip():
            self.items.append(Item(s, x0, y0, x1 - x0, y1 - y0))
        return x0, y0, x1, y1

    def rect(self, box, fill, radius=0):
        self.d.rounded_rectangle(box, radius=radius, fill=fill)

    def barcode(self, x, y, w, h, code, fnt):
        bits = ean_bits(code)
        mod = w / len(bits)
        for i, b in enumerate(bits):
            if b == "1":
                self.d.rectangle([x + i * mod, y, x + (i + 1) * mod - 0.5, y + h], fill=(10, 10, 10))
        digits = f"{code[0]} {code[1:7]} {code[7:]}"
        self.text((x + w / 2, y + h + 4), digits, fnt, anchor="ma")


def price_block(c: Canvas, x, y, value, fname, big, *, sup=True, comma=True, rs_size=None, fill=(15, 15, 15),
                unit=None):
    """Preço no estilo brasileiro: R$ pequeno, inteiro grande e centavos sobrescritos."""
    a, b = int_cents(value)
    rs = font(fname, rs_size or int(big * 0.28))
    bigf = font(fname, big)
    if not sup:
        return c.text((x, y), f"R$ {a},{b}", bigf, fill=fill)
    _, ty0, _, _ = c.d.textbbox((0, 0), a, font=bigf)
    rx = c.text((x, y + (ty0 if True else 0)), "R$", rs, fill=fill)
    bx = c.text((rx[2] + big * 0.08, y), a, bigf, fill=fill)
    cf = font(fname, int(big * 0.42))
    cents = ("," if comma else "") + b
    cx = c.text((bx[2] + big * 0.04, bx[1]), cents, cf, fill=fill, anchor="lt")
    if not comma:
        c.d.line([(cx[0], cx[3] + 6), (cx[2], cx[3] + 6)], fill=fill, width=4)
    if unit:
        uf = font(fname, int(big * 0.2))
        c.text((cx[0], cx[3] + 16), unit, uf, fill=fill, anchor="lt")
    return (rx[0], bx[1], max(cx[2], bx[2]), bx[3])


W, H = 1100, 380


def base_desc(c, name, fname, size=40, y=22, x=26):
    return c.text((x, y), name, font(fname, size))


def unit_line(value, qty, unit, style):
    if unit == "UN":
        return f"PREÇO POR UNIDADE: R$ {money(value / qty)}"
    per = value / qty
    u = "kg" if unit == "KG" else "L"
    return {
        "por": f"PREÇO POR {u.upper()}: R$ {money(per)}",
        "barra": f"R$ {money(per)}/{u}",
        "o": f"R$ {money(per)} o {u}",
        "valor": f"VALOR DO {u.upper()} R$ {money(per)}",
        "rskg": f"R$/{u.upper()} {money(per)}",
    }[style]


# --- layouts ---------------------------------------------------------------
def lay_simples(sup=True, comma=True, unit_style="por", un_suffix=False):
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(BODY_FONTS)
    c = Canvas(W, H, (250, 250, 247))
    base_desc(c, name, fname, 38)
    price_block(c, 560, 95, value, fname, 170, sup=sup, comma=comma, unit="UN" if un_suffix and sup else None)
    if un_suffix and not sup:
        c.text((900, 150), "UN", font(fname, 40))
    c.barcode(40, 110, 300, 150, ean, font("mono", 22))
    c.text((26, 330), unit_line(value, qty, unit, unit_style), font(fname, 26))
    c.text((900, 340), "27/10/26", font("mono", 18))
    c.text((380, 120), f"Cód. {rng.randint(10000, 99999)}", font("mono", 20))
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name)


def lay_linear():
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(BODY_FONTS)
    c = Canvas(W, H, (255, 255, 255))
    base_desc(c, name, fname, 40)
    c.text((520, 120), f"R$ {money(value)}", font(fname, 120))
    c.barcode(40, 110, 300, 150, ean, font("mono", 22))
    c.text((26, 330), unit_line(value, qty, unit, rng.choice(["barra", "o", "valor", "rskg"])), font(fname, 26))
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name)


def lay_atacarejo():
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(["heros_cn", "arial", "dejavu_cn"])
    n = rng.choice([3, 6, 12])
    atac = round(value * 0.9, 2)
    c = Canvas(W, H, (255, 255, 255))
    base_desc(c, name, fname, 36, y=16)
    c.text((30, 80), "VAREJO", font(fname, 30))
    price_block(c, 30, 120, value, fname, 120)
    c.rect((520, 70, 1080, 300), (255, 205, 0), radius=14)
    c.text((545, 82), "ATACADO", font(fname, 32))
    c.text((545, 120), f"A PARTIR DE {n} UN", font(fname, 26))
    price_block(c, 545, 160, atac, fname, 120)
    c.barcode(40, 300, 260, 50, ean, font("mono", 16))
    c.text((620, 330), unit_line(value, qty, unit, "por"), font(fname, 22))
    # Preço de referência: o de uma unidade. O de atacado é condicional.
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name,
                   offers=[["any", None, round(value * 100)], ["wholesale", n, round(atac * 100)]])


def lay_de_por(same_line=False):
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(BODY_FONTS)
    promo = round(value * rng.choice([0.75, 0.8, 0.85]), 2)
    c = Canvas(W, H, (255, 214, 0))
    c.rect((0, 0, W, 62), (200, 20, 30))
    c.text((W / 2, 8), "OFERTA", font(fname, 46), fill=(255, 255, 255), anchor="ma")
    base_desc(c, name, fname, 36, y=78)
    if same_line:
        c.text((30, 150), f"DE R$ {money(value)} POR R$ {money(promo)}", font(fname, 58))
    else:
        c.text((30, 140), f"DE R$ {money(value)}", font(fname, 40), strike=rng.random() < 0.5)
        c.text((30, 200), "POR", font(fname, 44))
        price_block(c, 140, 160, promo, fname, 150)
    c.text((30, 340), "VÁLIDO ATÉ 03/11/26 OU ENQUANTO DURAREM OS ESTOQUES", font(fname, 20))
    return c, dict(price=round(promo * 100), regular=round(value * 100), ean=None, name=name)


def lay_clube(label):
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(BODY_FONTS)
    club = round(value * 0.85, 2)
    c = Canvas(W, H, (255, 255, 255))
    base_desc(c, name, fname, 36)
    c.text((30, 90), f"R$ {money(value)}", font(fname, 64))
    c.rect((470, 80, 1080, 310), (0, 120, 70), radius=16)
    c.text((500, 92), label, font(fname, 34), fill=(255, 255, 255))
    price_block(c, 500, 140, club, fname, 140, fill=(255, 255, 255))
    c.barcode(40, 190, 280, 110, ean, font("mono", 20))
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name,
                   offers=[["any", None, round(value * 100)], ["loyalty", None, round(club * 100)]])


def lay_leve_pague():
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(BODY_FONTS)
    c = Canvas(W, H, (255, 255, 255))
    c.rect((0, 0, W, 70), (230, 40, 40))
    c.text((W / 2, 10), "LEVE 3 PAGUE 2", font(fname, 48), fill=(255, 255, 255), anchor="ma")
    base_desc(c, name, fname, 36, y=86)
    price_block(c, 520, 150, value, fname, 150)
    c.text((520, 330), "CADA UNIDADE", font(fname, 24))
    c.barcode(40, 160, 300, 120, ean, font("mono", 20))
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name)


def lay_granel(style):
    name, value = rng.choice(BULK)
    fname = rng.choice(BODY_FONTS)
    c = Canvas(W, H, (255, 255, 255))
    c.text((30, 24), name, font(fname, 52))
    a, b = int_cents(value)
    if style == "kg_depois":
        c.text((60, 140), f"R$ {money(value)} KG", font(fname, 130))
    elif style == "kg_barra":
        c.text((60, 140), f"R$ {money(value)} /kg", font(fname, 130))
    else:  # "kg_antes": KG grande à esquerda
        c.text((40, 170), "KG", font(fname, 80))
        price_block(c, 220, 130, value, fname, 170)
    return c, dict(price=round(value * 100), regular=None, ean=None, name=name)


def lay_un():
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    fname = rng.choice(BODY_FONTS)
    c = Canvas(W, H, (255, 255, 255))
    base_desc(c, name, fname, 40)
    c.text((440, 130), f"R$ {money(value)} UN", font(fname, 120))
    c.barcode(40, 130, 300, 130, ean, font("mono", 22))
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name)


def lay_cartaz():
    name, value = rng.choice(BULK)
    c = Canvas(W, 700, (255, 222, 0))
    c.text((W / 2, 20), "OFERTA", font("arial", 110), fill=(210, 20, 20), anchor="ma")
    c.text((W / 2, 170), name.title(), font("script", 110), fill=(20, 20, 120), anchor="ma")
    c.text((W / 2, 330), f"R$ {money(value)}", font("script", 230), fill=(20, 20, 120), anchor="ma")
    c.text((W - 120, 600), "kg", font("script", 80), fill=(20, 20, 120), anchor="ma")
    return c, dict(price=round(value * 100), regular=None, ean=None, name=name)


def lay_termica_fraca():
    name, pre, value, unit, qty = rng.choice(PRODUCTS)
    ean = new_ean(pre)
    c = Canvas(W, H, (238, 236, 228))
    fill = (120, 120, 115)
    c.text((26, 22), name, font("mono", 36), fill=fill)
    c.text((520, 120), f"R$ {money(value)}", font("mono", 110), fill=fill)
    c.barcode(40, 110, 300, 150, ean, font("mono", 22))
    c.text((26, 330), unit_line(value, qty, unit, "por"), font("mono", 24), fill=fill)
    return c, dict(price=round(value * 100), regular=None, ean=ean, name=name)


def lay_milhar():
    c = Canvas(W, H, (255, 255, 255))
    name = rng.choice(["SMART TV 50 4K SAMSUNG", "GELADEIRA FROST FREE 375L", "AIR FRYER MONDIAL 4L"])
    value = rng.choice([1299.90, 2349.00, 1049.99])
    fname = rng.choice(BODY_FONTS)
    base_desc(c, name, fname, 40)
    a, b = int_cents(value)
    a_fmt = f"{int(a):,}".replace(",", ".")
    c.text((300, 130), f"R$ {a_fmt},{b}", font(fname, 130))
    c.text((300, 300), f"OU 10X DE R$ {money(value / 10)} SEM JUROS", font(fname, 30))
    return c, dict(price=round(value * 100), regular=None, ean=None, name=name)


LAYOUTS = {
    "simples_sobrescrito": lambda: lay_simples(),
    "sobrescrito_sem_virgula": lambda: lay_simples(comma=False),
    "sobrescrito_un": lambda: lay_simples(un_suffix=True, unit_style="barra"),
    "linear": lay_linear,
    "atacarejo": lay_atacarejo,
    "de_por": lambda: lay_de_por(),
    "de_por_mesma_linha": lambda: lay_de_por(same_line=True),
    "clube": lambda: lay_clube("PREÇO CLUBE"),
    "app": lambda: lay_clube("NO APP"),
    "leve_pague": lay_leve_pague,
    "granel_kg_depois": lambda: lay_granel("kg_depois"),
    "granel_kg_barra": lambda: lay_granel("kg_barra"),
    "granel_kg_antes": lambda: lay_granel("kg_antes"),
    "preco_un": lay_un,
    "cartaz": lay_cartaz,
    "termica_fraca": lay_termica_fraca,
    "milhar": lay_milhar,
}


# --- "fotografia" ----------------------------------------------------------
def photograph(img: Image.Image, level: float) -> np.ndarray:
    """Simula uma foto de celular: fundo de prateleira, perspectiva, luz, reflexo, desfoque."""
    src = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
    h, w = src.shape[:2]
    FW, FH = 1280, 960
    scale = rng.uniform(0.75, 0.95) * FW / w
    tw, th = w * scale, h * scale
    cx, cy = FW / 2 + rng.uniform(-40, 40), FH / 2 + rng.uniform(-40, 40)
    j = level * 0.09
    def jit(v):
        return v + rng.uniform(-j, j) * tw
    dst = np.float32([
        [jit(cx - tw / 2), jit(cy - th / 2)], [jit(cx + tw / 2), jit(cy - th / 2)],
        [jit(cx + tw / 2), jit(cy + th / 2)], [jit(cx - tw / 2), jit(cy + th / 2)],
    ])
    ang = math.radians(rng.uniform(-6, 6) * level)
    rot = np.array([[math.cos(ang), -math.sin(ang)], [math.sin(ang), math.cos(ang)]])
    dst = ((dst - [cx, cy]) @ rot.T + [cx, cy]).astype(np.float32)
    M = cv2.getPerspectiveTransform(np.float32([[0, 0], [w, 0], [w, h], [0, h]]), dst)
    shelf = np.full((FH, FW, 3), rng.choice([(70, 70, 75), (150, 110, 40), (200, 200, 200), (40, 60, 160)]),
                    np.uint8)
    shelf = cv2.add(shelf, np.random.default_rng(rng.randint(0, 99999)).integers(0, 25, shelf.shape, np.uint8))
    out = cv2.warpPerspective(src, M, (FW, FH), dst=shelf, borderMode=cv2.BORDER_TRANSPARENT)
    f = out.astype(np.float32)
    # Luz irregular.
    yy, xx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    gx, gy = rng.uniform(-1, 1), rng.uniform(-1, 1)
    light = 1 + level * 0.35 * ((xx / FW - 0.5) * gx + (yy / FH - 0.5) * gy)
    f *= light[..., None]
    # Reflexo da capa de plástico do trilho.
    if rng.random() < 0.6 * level:
        gxc, gyc = rng.uniform(0.2, 0.8) * FW, rng.uniform(0.3, 0.7) * FH
        rx, ry = rng.uniform(80, 260), rng.uniform(30, 110)
        g = np.exp(-(((xx - gxc) / rx) ** 2 + ((yy - gyc) / ry) ** 2))
        f += (g * rng.uniform(90, 170) * level)[..., None]
    f = np.clip(f, 0, 255).astype(np.uint8)
    # Desfoque de foco ou de movimento.
    if level > 0:
        if rng.random() < 0.5:
            k = rng.choice([3, 5, 7]) if level > 0.5 else 3
            f = cv2.GaussianBlur(f, (k, k), level * 1.4)
        else:
            k = int(3 + level * 8)
            kern = np.zeros((k, k), np.float32)
            kern[k // 2, :] = 1 / k
            Mr = cv2.getRotationMatrix2D((k / 2, k / 2), rng.uniform(0, 180), 1)
            kern = cv2.warpAffine(kern, Mr, (k, k))
            kern /= kern.sum()
            f = cv2.filter2D(f, -1, kern)
    noise = np.random.default_rng(rng.randint(0, 99999)).normal(0, 6 * level, f.shape)
    f = np.clip(f.astype(np.float32) + noise, 0, 255).astype(np.uint8)
    q = int(85 - 35 * level)
    ok, enc = cv2.imencode(".jpg", f, [cv2.IMWRITE_JPEG_QUALITY, q])
    return cv2.imdecode(enc, cv2.IMREAD_COLOR)


def main(per_layout=4):
    truth = {}
    for lname, fn in LAYOUTS.items():
        for k in range(per_layout):
            c, t = fn()
            tid = f"{lname}_{k}"
            c.img.save(OUT / f"{tid}_limpa.png")
            level = [0.25, 0.5, 0.75, 1.0][k % 4]
            cv2.imwrite(str(OUT / f"{tid}_foto.jpg"), photograph(c.img, level))
            truth[tid] = dict(layout=lname, level=level, **t, items=[asdict(i) for i in c.items])
    (OUT / "gabarito.json").write_text(json.dumps(truth, ensure_ascii=False, indent=1))
    print(len(truth), "etiquetas")


if __name__ == "__main__":
    main()
