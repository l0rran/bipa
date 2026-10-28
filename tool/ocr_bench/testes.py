"""Confere o port em Python com os mesmos casos dos testes em Dart.

Uso: python3 testes.py
"""
from etiquetas_reais import FIXTURES
from price_tag_parser import OcrLine, parse


def tag(items):
    return [OcrLine(t, i * 40.0, h) for i, (t, h) in enumerate(items)]


falhas = []


def confere(nome, obtido, esperado):
    if obtido != esperado:
        falhas.append(f"{nome}: {obtido!r} != {esperado!r}")


def ofertas(r):
    return [(o.condition.kind, o.condition.min_quantity, o.price) for o in r.offers]


r = parse(tag([("LEITE COND MOCA 395G", 20), ("R$ 7,99", 80), ("7891000100103", 12)]))
confere("simples", (r.price, r.regular_price, r.name, r.barcode), (799, None, "Leite Cond Moca 395g", "7891000100103"))
r = parse(tag([("ARROZ TIO JOAO 5KG", 20), ("R$ 27,90", 60), ("PREÇO POR KG R$ 5,58", 12)]))
confere("ignora preço por kg", (r.price, r.candidates), (2790, [2790]))
confere("granel", parse(tag([("ALCATRA BOVINA", 20), ("R$ 39,90 /KG", 60)])).price, 3990)
r = parse(tag([("SABAO EM PO OMO 1,6KG", 20), ("DE R$ 32,90", 16), ("POR R$ 24,90", 50)]))
confere("de/por", (r.price, r.regular_price, r.name), (2490, 3290, "Sabao Em Po Omo 1,6kg"))
confere("centavos separados", parse(tag([("CAFE PILAO 500G", 20), ("R$ 18 99", 70)])).price, 1899)
r = parse(tag([("BISCOITO RECHEADO", 18), ("3,99", 20), ("4,49", 70)]))
confere("maior fonte", (r.price, r.candidates), (449, [399, 449]))
r = parse(tag([("BANANA PRATA", 20), ("VALIDO ATE 31.10.26", 12), ("R$ 5,49", 60)]))
confere("datas", (r.candidates, r.name), ([549], "Banana Prata"))
r = parse(tag([("AGUA MINERAL 1,50L", 20), ("R$ 2,79", 60)]))
confere("volume", (r.candidates, r.name), ([279], "Agua Mineral 1,50l"))
confere("RS", parse(tag([("RS 18 99", 70)])).price, 1899)
confere("scanner", parse(tag([("R$ 2,00", 50), ("7891000100103", 12)]), barcodes=["123", "7891910000197"]).barcode,
        "7891910000197")
confere("KG depois do preço", parse(tag([("TOMATE ITALIANO", 20), ("R$ 8,99 KG", 70)])).price, 899)
confere("UN depois do preço", parse(tag([("ACUCAR UNIAO 1KG", 20), ("R$ 4,99 UN", 70)])).price, 499)
r = parse(tag([("GELADEIRA FROST FREE 375L", 20), ("R$ 1.299,90", 70), ("OU 10X DE R$ 129,99 SEM JUROS", 16)]))
confere("milhar e parcela", (r.price, r.regular_price, r.candidates), (129990, None, [129990]))
confere("dígitos espaçados", parse(tag([("R$ 1 0,99", 70)])).price, 1099)
confere("centavos à parte", parse([OcrLine("R$ 18", 100, 120, 300, 200), OcrLine(",99", 104, 50, 506, 80)]).price, 1899)
confere("centavos sem vírgula", parse([OcrLine("18", 100, 120, 300, 150), OcrLine("99", 100, 50, 455, 70)]).price, 1899)
confere("centavos longe", parse([OcrLine("R$ 18", 100, 120, 300, 200), OcrLine("99", 300, 50, 506, 80)]).price, None)
r = parse(tag([("LEVE 3 PAGUE 2", 30), ("oooooooooooo", 20), ("CAFE PILAO 500G", 20), ("R$ 18,99", 70)]))
confere("nome sem rótulos", r.name, "Cafe Pilao 500g")
r = parse(tag([("CAFE PILAO 500G", 20), ("R$ 5,49", 60), ("ATACADO A PARTIR DE 6 UN R$ 4,99", 50)]))
confere("atacado na linha", ofertas(r), [("any", None, 549), ("wholesale", 6, 499)])
r = parse(tag([("FEIJAO KICALDO 1KG", 20), ("R$ 8,49", 40), ("PREÇO CLUBE", 20), ("R$ 7,22", 80)]))
confere("clube", (r.price, r.regular_price, ofertas(r)), (849, None, [("any", None, 849), ("loyalty", None, 722)]))
r = parse(tag([("DET LIQ MINUANO 500ML", 20), ("R$ 1,79", 60), ("Atacado 3,58", 10)]))
confere("bloco de informações", (ofertas(r), r.candidates), ([("any", None, 179)], [179, 358]))

for nome, f in FIXTURES.items():
    r = parse([OcrLine(t, top, h, left, w) for (t, left, top, w, h) in f["lines"]])
    confere(nome, (ofertas(r), r.name), (f["offers"], f["name"]))

print("\n".join(falhas) if falhas else "todos os casos passaram")
raise SystemExit(1 if falhas else 0)
