"""Roda o parser sobre as etiquetas sintéticas em quatro cenários e compara com o gabarito.

  ideal_frag   OCR perfeito, cada elemento impresso vira uma linha (centavos separados)
  ideal_linha  OCR perfeito, elementos lado a lado agrupados em linha, como o ML Kit faz
  tess_limpa   Tesseract (por) na etiqueta limpa
  tess_foto    Tesseract (por) na foto simulada + leitor de código de barras do OpenCV

Uso: python3 run_ocr.py <pasta_tags> [módulo_parser] [saida.json]

O Tesseract precisa do modelo de português (por.traineddata). Por padrão ele é
procurado em tool/ocr_bench/tessdata; troque com a variável BIPA_TESSDATA.
"""
from __future__ import annotations

import difflib
import importlib
import json
import os
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

import cv2
import pytesseract

TAGS = Path(sys.argv[1])
P = importlib.import_module(sys.argv[2] if len(sys.argv) > 2 else "price_tag_parser")
OUTF = sys.argv[3] if len(sys.argv) > 3 else None
TESSDATA = os.environ.get("BIPA_TESSDATA", str(Path(__file__).parent / "tessdata"))
CACHE = TAGS / "tesseract_cache.json"


def group_lines(boxes):
    """Agrupa caixas de palavras em linhas: sobreposição vertical e proximidade horizontal.

    É uma aproximação do que o ML Kit faz com elementos (palavras) dentro de um bloco.
    """
    boxes = sorted(boxes, key=lambda b: b["left"])
    lines = []
    for b in boxes:
        best = None
        for ln in lines:
            last = ln[-1]
            top = min(x["top"] for x in ln)
            bottom = max(x["top"] + x["height"] for x in ln)
            overlap = min(bottom, b["top"] + b["height"]) - max(top, b["top"])
            small = min(bottom - top, b["height"])
            gap = b["left"] - (last["left"] + last["width"])
            if overlap > 0.3 * small and -5 < gap < 1.0 * max(last["height"], b["height"]):
                best = ln
                break
        if best is None:
            lines.append([b])
        else:
            best.append(b)
    out = []
    for ln in lines:
        top = min(x["top"] for x in ln)
        bottom = max(x["top"] + x["height"] for x in ln)
        left = min(x["left"] for x in ln)
        right = max(x["left"] + x["width"] for x in ln)
        out.append(dict(text=" ".join(x["text"] for x in ln), top=top, height=bottom - top, left=left,
                        width=right - left))
    return out


def tesseract_words(path):
    img = cv2.imread(str(path))
    data = pytesseract.image_to_data(img, lang="por", config=f"--tessdata-dir {TESSDATA} --psm 11",
                                     output_type=pytesseract.Output.DICT)
    words = []
    for i, t in enumerate(data["text"]):
        if t.strip() and float(data["conf"][i]) > 0:
            words.append(dict(text=t, left=data["left"][i], top=data["top"][i], width=data["width"][i],
                              height=data["height"][i]))
    return words


def scan_barcodes(path):
    img = cv2.imread(str(path))
    det = cv2.barcode.BarcodeDetector()
    try:
        res = det.detectAndDecode(img)
        texts = res[0] if isinstance(res[0], (list, tuple)) else [res[0]]
        if len(res) == 4:  # versões antigas: ok, infos, tipos, pontos
            texts = res[1]
    except cv2.error:
        texts = []
    return [t for t in texts if t]


def fold(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().upper()
    return " ".join(s.split())


def to_lines(dicts):
    return [P.OcrLine(d["text"], d["top"], d["height"], d.get("left"), d.get("width")) for d in dicts]


def main():
    truth = json.loads((TAGS / "gabarito.json").read_text())
    cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
    results = []
    for tid, t in truth.items():
        items = t["items"]
        scenarios = {
            "ideal_frag": (items, []),
            "ideal_linha": (group_lines(items), []),
        }
        for kind, fname in (("tess_limpa", f"{tid}_limpa.png"), ("tess_foto", f"{tid}_foto.jpg")):
            if fname not in cache:
                cache[fname] = dict(words=tesseract_words(TAGS / fname), barcodes=scan_barcodes(TAGS / fname))
            c = cache[fname]
            scenarios[kind] = (group_lines(c["words"]), c["barcodes"])
        for sc, (lines, codes) in scenarios.items():
            r = P.parse(to_lines(lines), barcodes=codes)
            offers_ok = True
            if "offers" in t:
                got = sorted([o.condition.kind, o.condition.min_quantity, o.price] for o in getattr(r, "offers", []))
                offers_ok = got == sorted(t["offers"])
            name_ok = bool(r.name) and difflib.SequenceMatcher(None, fold(r.name), fold(t["name"])).ratio() >= 0.8
            results.append(dict(
                id=tid, layout=t["layout"], level=t["level"], scenario=sc,
                price_ok=r.price == t["price"], got_price=r.price, want_price=t["price"],
                regular_ok=r.regular_price == t["regular"] and offers_ok, got_regular=r.regular_price,
                ean_ok=(t["ean"] is None) or r.barcode == t["ean"], got_ean=r.barcode, want_ean=t["ean"],
                name_ok=name_ok, got_name=r.name,
                lines=[l["text"] for l in sorted(lines, key=lambda l: l["top"])],
            ))
    CACHE.write_text(json.dumps(cache, ensure_ascii=False))
    if OUTF:
        Path(OUTF).write_text(json.dumps(results, ensure_ascii=False, indent=1))

    scen = ["ideal_frag", "ideal_linha", "tess_limpa", "tess_foto"]
    by = defaultdict(lambda: defaultdict(list))
    for r in results:
        by[r["layout"]][r["scenario"]].append(r["price_ok"] and r["regular_ok"])
    print(f"{'layout':26}" + "".join(f"{s:>13}" for s in scen))
    tot = defaultdict(list)
    for lay, d in by.items():
        row = f"{lay:26}"
        for s in scen:
            v = d[s]
            tot[s] += v
            row += f"{sum(v):>9}/{len(v):<3}"
        print(row)
    print(f"{'TOTAL preço':26}" + "".join(f"{100*sum(tot[s])/len(tot[s]):>12.0f}%" for s in scen))
    for key, label in (("ean_ok", "EAN"), ("name_ok", "nome")):
        line = f"{'TOTAL ' + label:26}"
        for s in scen:
            v = [r[key] for r in results if r["scenario"] == s]
            line += f"{100*sum(v)/len(v):>12.0f}%"
        print(line)


if __name__ == "__main__":
    main()
