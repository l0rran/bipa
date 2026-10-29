"""Confere as regras do catálogo: código, nome, marca, tamanho e categoria.

Uso, da raiz do repositório: py -3 tool/catalogo/testes.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from catalogo import codigo, eh_brasileiro, gtin_valido, linha, marca, nome, tamanho, tipo  # noqa: E402
from categorias import PADRAO_POR_FONTE, PRODUCT_KINDS, REGRAS  # noqa: E402

falhas = []


def confere(rotulo, obtido, esperado):
    if obtido != esperado:
        falhas.append(f"{rotulo}: {obtido!r} != {esperado!r}")


# Código: os mesmos casos de test/features/products/domain/gtin_test.dart.
confere("EAN-13 válido", gtin_valido("7891000100103"), True)
confere("EAN-13 dígito errado", gtin_valido("7891000100104"), False)
confere("EAN-8 válido", gtin_valido("96385074"), True)
confere("UPC-A válido", gtin_valido("036000291452"), True)
confere("GTIN-14 válido", gtin_valido("17891000100100"), True)
confere("tamanho inválido", gtin_valido("789100010010"), False)
confere("letra", gtin_valido("789100010010A"), False)
confere("vazio", gtin_valido(""), False)
confere("None", gtin_valido(None), False)
confere("código com espaço", codigo(" 7891000100103 "), "7891000100103")
confere("código da balança fica de fora", codigo("2000123004990"), None)
confere("quase só zero fica de fora", codigo("0000000000017"), None)
confere("UPC-A interno (02) fica de fora", codigo("0212345000006"), None)
confere("código inválido", codigo("7891000100104"), None)
confere("GTIN-14 com zero vira EAN-13", codigo("07891000100103"), "7891000100103")
confere("GTIN-14 de caixa fica", codigo("17891000100100"), "17891000100100")

# Recorte: Brasil nos países ou prefixo 789/790.
confere("Brasil nos países", eh_brasileiro("3017620422003", ["en:france", "en:brazil"]), True)
confere("prefixo 789", eh_brasileiro("7891000100103", ["en:france"]), True)
confere("prefixo 790", eh_brasileiro("7900000000000", None), True)
confere("outro país", eh_brasileiro("3017620422003", ["en:france"]), False)

# Nome e marca.
confere("nome em português primeiro", nome("Leite condensado", "Sweetened condensed milk"), "Leite condensado")
confere("nome principal sem português", nome(None, "Nescau 2.0"), "Nescau 2.0")
confere("nome com HTML", nome(None, "Case para HDD 2.5&quot;"), 'Case para HDD 2.5"')
confere("nome com espaços", nome("  Arroz   branco ", None), "Arroz branco")
confere("nome só com número", nome(None, "123"), None)
confere("nome vazio", nome("", ""), None)
confere("primeira marca", marca("Nestlé, Ninho"), "Nestlé")
confere("sem marca", marca(""), None)

# Tamanho, com a unidade do app (g, kg, ml, l, un).
confere("gramas", tamanho("500 g"), (500, "g"))
confere("gramas colado", tamanho("395g"), (395, "g"))
confere("quilo", tamanho("5 kg"), (5, "kg"))
confere("quilo com vírgula", tamanho("1,5 kg"), (1.5, "kg"))
confere("litro maiúsculo", tamanho("1 L"), (1, "l"))
confere("litro com vírgula", tamanho("1,5L"), (1.5, "l"))
confere("litro com ponto", tamanho("2.5 l"), (2.5, "l"))
confere("mililitro", tamanho("350 ml"), (350, "ml"))
confere("centilitro", tamanho("33 cl"), (330, "ml"))
confere("unidades", tamanho("12 un"), (12, "un"))
confere("unidades por extenso", tamanho("30 unidades"), (30, "un"))
confere("rolos", tamanho("4 rolos"), (4, "un"))
confere("u do Open Food Facts", tamanho("48 u"), (48, "un"))
confere("multipack é o total", tamanho("6 x 1 L"), (6, "l"))
confere("multipack de gramas", tamanho("2 x 200g"), (400, "g"))
confere("ponto de milhar", tamanho("1.000 g"), (1000, "g"))
confere("primeiro tamanho do texto", tamanho("400 g (2 x 200 g)"), (400, "g"))
confere("acento", tamanho("10 cápsulas"), (10, "un"))
confere("cc", tamanho("200 cc"), (200, "ml"))
confere("miligrama é dose, não tamanho", tamanho("Xarope 30mg 120ml"), (120, "ml"))
confere("libra fica sem tamanho", tamanho("4,4 lbs"), (None, None))
confere("número solto fica sem tamanho", tamanho("500"), (None, None))
confere("número sem unidade usa o product_quantity", tamanho("20", 20, None), (None, None))
confere("sem texto usa o product_quantity", tamanho(None, "395", "g"), (395, "g"))
confere("texto ilegível usa o product_quantity", tamanho("uma lata", 350.0, "ml"), (350, "ml"))
confere("nada", tamanho(None), (None, None))
confere("zero", tamanho("0 g"), (None, None))
confere("palavra que começa com unidade não é unidade", tamanho("3 litros"), (3, "l"))
confere("g dentro de palavra", tamanho("2 garrafas"), (None, None))

# Categorias: a tabela só usa nomes do enum ProductKind do app.
for rotulos, kind in REGRAS:
    confere(f"tipo {kind} existe no app", kind in PRODUCT_KINDS, True)
    for rotulo in rotulos:
        confere(f"rótulo {rotulo} normalizado", bool(re.fullmatch(r"[a-z]{2}:[a-z0-9-]+", rotulo)), True)
for fonte, kind in PADRAO_POR_FONTE.items():
    confere(f"padrão de {fonte} existe no app", kind in PRODUCT_KINDS, True)
todos = [r for rotulos, _ in REGRAS for r in rotulos]
confere("nenhum rótulo repetido", sorted({r for r in todos if todos.count(r) > 1}), [])

# Categorias de produtos reais (as categories_tags vêm com as categorias-mãe).
casos = [
    (["en:dairies", "en:milks", "en:uht-milks"], "shelfStable"),  # longa vida
    (["en:dairies", "en:milks", "en:condensed-milks", "en:sweetened-condensed-milks"], "sweets"),
    (["en:dairies", "en:creams"], "sweets"),  # creme de leite, como o app
    (["en:dairies", "en:cheeses"], "dairy"),
    (["en:dairies", "en:fermented-milk-products", "en:yogurts"], "dairy"),
    (["en:plant-based-foods", "en:fats", "en:margarines"], "dairy"),
    (["en:beverages", "en:hot-beverages", "en:coffees", "en:ground-coffees"], "coffee"),
    (["en:beverages", "en:hot-beverages", "en:teas"], "tea"),
    (["en:beverages", "en:carbonated-drinks", "en:sodas"], "drinks"),
    (["en:beverages", "en:waters", "en:mineral-waters"], "drinks"),
    (["en:plant-based-foods", "en:cereals-and-their-products", "en:cereal-grains", "en:rices"], "grains"),
    (["en:plant-based-foods", "en:legumes", "en:common-beans"], "grains"),
    (["en:plant-based-foods", "en:cereals-and-their-products", "en:pastas"], "pasta"),
    (["en:plant-based-foods", "en:cereals-and-their-products", "en:flours", "en:wheat-flours"], "baking"),
    (["en:plant-based-foods", "en:cereals-and-their-products", "en:breads", "en:sliced-breads"], "bakery"),
    (["en:sweeteners", "en:sugars"], "baking"),
    (["en:plant-based-foods", "en:fats", "en:vegetable-oils", "en:olive-oils"], "oils"),
    (["en:frozen-foods", "en:meals", "en:lasagna"], "frozen"),
    (["en:desserts", "en:frozen-desserts", "en:ice-creams"], "frozen"),
    (["en:seafood", "en:fishes", "en:canned-foods", "en:canned-fishes", "en:canned-tunas"], "shelfStable"),
    (["en:seafood", "en:fishes"], "fish"),
    (["en:meats", "en:prepared-meats", "en:sausages"], "meat"),
    (["en:snacks", "en:sweet-snacks", "en:biscuits-and-cakes", "en:biscuits"], "sweets"),
    (["en:snacks", "en:sweet-snacks", "en:cocoa-and-its-products", "en:chocolates"], "sweets"),
    (["en:snacks", "en:salty-snacks", "en:chips"], "shelfStable"),
    (["en:farming-products", "en:eggs", "en:chicken-eggs"], "eggs"),
    (["en:plant-based-foods", "en:fruits", "en:fresh-fruits"], "produce"),
    (["en:pet-food", "en:dog-food"], "pet"),
    (["en:laundry-supplies", "en:laundry-detergent"], "laundry"),
    (["en:household-supplies", "en:household-chemicals", "en:detergents"], "cleaning"),
    (["pt:Produto de limpeza"], "cleaning"),  # rótulo fora da taxonomia, sem normalizar
    (["pt:Amaciante de roupas"], "laundry"),
    (["en:toilet-papers"], "hygiene"),
    (["en:Lácteos", "en:Yogures"], "dairy"),  # espanhol fora da taxonomia
    (["en:Bebidas", "en:Bebidas alcohólicas", "en:Cervezas"], "drinks"),
    (["en:snacks", "en:Galletas"], "sweets"),
    (["en:snacks"], "shelfStable"),
    (["en:electronics", "en:batteries"], None),
    ([], None),
    (None, None),
]
for tags, esperado in casos:
    confere(f"tipo de {tags}", tipo(tags, "off"), esperado)
confere("Open Beauty Facts sem categoria é higiene", tipo([], "obf"), "hygiene")
confere("Open Products Facts sem categoria fica sem tipo", tipo([], "opf"), None)
confere("categoria vence o padrão da fonte", tipo(["en:laundry-detergents"], "obf"), "laundry")

# A linha completa.
confere(
    "linha",
    linha("off", "7891000100103", "Leite condensado Moça", "Nestlé, Moça", "395 g", 395, "g",
          ["en:dairies", "en:condensed-milks"]),
    {
        "barcode": "7891000100103", "name": "Leite condensado Moça", "brand": "Nestlé",
        "quantity": "395 g", "size_value": 395, "size_unit": "g", "kind": "sweets", "source": "off",
    },
)
confere(
    "tamanho do nome quando falta a quantidade",
    {k: v for k, v in linha("off", "7891962057620", "Pão de forma Bauducco 400g", None, None, None, None, None).items()
     if k in ("quantity", "size_value", "size_unit")},
    {"quantity": None, "size_value": 400, "size_unit": "g"},
)
confere(
    "a quantidade vence o nome",
    linha("off", "7891962057620", "Pão de forma 400g", None, "500 g", None, None, None)["size_value"],
    500,
)
confere("linha sem nome", linha("off", "7891000100103", None, None, None, None, None, None), None)
confere("linha com código inválido", linha("off", "7891000100104", "Leite", None, None, None, None, None), None)

if falhas:
    print("\n".join(falhas))
    print(f"{len(falhas)} falha(s)")
    sys.exit(1)
print("ok")
