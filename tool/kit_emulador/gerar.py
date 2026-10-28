"""Gera as imagens para testar o modo carrinho no emulador do Android.

O emulador não tem câmera de verdade, mas a câmera traseira "VirtualScene"
mostra uma sala 3D com duas imagens trocáveis: uma na parede e uma na mesa.
Este script gera:

  parede.png  uma gôndola com três etiquetas:
              - Arroz, R$ 27,90, sem código de barras;
              - Café, R$ 18,99, com o código do café (etiqueta com código);
              - Biscoito, com dois preços do mesmo tamanho e sem rótulo
                (a leitura ao vivo não deve escolher nenhum).
  mesa.png    as "embalagens": os códigos de barras do arroz e do café, para
              bipar o produto.

Uso: python3 tool/kit_emulador/gerar.py [pasta de saída]
Ver tool/kit_emulador/README.md para configurar o emulador.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ocr_bench"))
from make_tags import Canvas, ean_check, font, price_block  # noqa: E402

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent / "imagens")
OUT.mkdir(parents=True, exist_ok=True)

RICE = ean_check("789600671115")
COFFEE = ean_check("789108920001")
FONT = "arial"


def tag_rice() -> Canvas:
    c = Canvas(900, 420, (250, 250, 247))
    c.text((30, 26), "ARROZ BRANCO TIO JOAO 5KG", font(FONT, 44))
    price_block(c, 120, 120, 27.90, FONT, 190)
    c.text((30, 360), "PREÇO POR KG: R$ 5,58", font(FONT, 30))
    return c


def tag_coffee() -> Canvas:
    c = Canvas(900, 420, (250, 250, 247))
    c.text((30, 26), "CAFE PILAO TRADICIONAL 500G", font(FONT, 44))
    c.barcode(40, 130, 300, 160, COFFEE, font("mono", 24))
    price_block(c, 400, 120, 18.99, FONT, 170)
    c.text((30, 360), "PREÇO POR KG: R$ 37,98", font(FONT, 30))
    return c


def tag_ambiguous() -> Canvas:
    c = Canvas(900, 420, (250, 250, 247))
    c.text((30, 26), "BISCOITO RECHEADO 90G", font(FONT, 44))
    c.text((40, 150), "R$ 3,99", font(FONT, 100))
    c.text((480, 150), "R$ 4,49", font(FONT, 100))
    return c


def package(name: str, code: str) -> Canvas:
    c = Canvas(900, 560, (255, 255, 255))
    c.rect((0, 0, 900, 110), (230, 200, 120))
    c.text((450, 30), name, font(FONT, 52), anchor="ma")
    c.barcode(150, 170, 600, 300, code, font("mono", 34))
    return c


def sheet(parts: list[Canvas], gap: int, bg: tuple[int, int, int]) -> Canvas:
    width = sum(p.img.width for p in parts) + gap * (len(parts) + 1)
    height = max(p.img.height for p in parts) + gap * 2
    out = Canvas(width, height, bg)
    x = gap
    for part in parts:
        out.img.paste(part.img, (x, gap))
        x += part.img.width + gap
    return out


sheet([tag_rice(), tag_coffee(), tag_ambiguous()], 140, (60, 60, 70)).img.save(OUT / "parede.png")
sheet([package("ARROZ TIO JOAO 5 KG", RICE), package("CAFE PILAO 500 G", COFFEE)], 120, (180, 160, 130)).img.save(
    OUT / "mesa.png"
)
print(f"arroz {RICE}, café {COFFEE}; imagens em {OUT}")
