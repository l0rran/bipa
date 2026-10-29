"""Regras puras do catálogo: código, nome, marca, tamanho e categoria.

Não acessa rede nem arquivo; `gerar.py` usa estas funções, e `testes.py`
as confere.
"""
import html
import re
import unicodedata

from categorias import PADRAO_POR_FONTE, REGRAS

VALID_LENGTHS = {8, 12, 13, 14}


def gtin_valido(code):
    """Igual a `Gtin.isValid` do app (ADR 0005): tamanho 8, 12, 13 ou 14,
    só dígitos e dígito verificador de módulo 10."""
    if not isinstance(code, str) or len(code) not in VALID_LENGTHS or not code.isdigit():
        return False
    digits = [int(c) for c in code]
    check = digits.pop()
    total = 0
    for i, d in enumerate(digits):
        # Pesos 3 e 1 alternados, começando por 3 no dígito mais à direita.
        position_from_right = len(digits) - i
        total += d * (3 if position_from_right % 2 == 1 else 1)
    return (10 - total % 10) % 10 == check


def codigo(raw):
    """O código como o catálogo guarda, ou None se não serve.

    Fica de fora o código interno de loja (prefixo GS1 2, como a etiqueta da
    balança, ADR 0018) e o que é quase só zero, que o Open Food Facts às vezes
    guarda para produto sem código.
    """
    code = re.sub(r"\s", "", raw or "")
    if not gtin_valido(code):
        return None
    # GTIN-14 com zero na frente é o EAN-13 com o mesmo dígito verificador, e
    # é o EAN-13 que a câmera lê na embalagem.
    if len(code) == 14 and code[0] == "0":
        code = code[1:]
    significant = code.lstrip("0")
    if len(significant) < 7:
        return None
    # EAN-13 de circulação restrita (20 a 29) e o UPC-A equivalente (02, 04).
    if len(code) == 13 and code[0] == "2":
        return None
    if len(code) == 13 and code[:2] in ("02", "04"):
        return None
    return code


def eh_brasileiro(code, countries_tags):
    """Brasil nos países do produto ou prefixo GS1 brasileiro (789 e 790)."""
    if countries_tags and "en:brazil" in countries_tags:
        return True
    return (code or "").startswith(("789", "790"))


def limpar(texto):
    """Tira HTML escapado ("&quot;"), espaços repetidos e as pontas."""
    if texto is None:
        return None
    texto = html.unescape(str(texto))
    texto = re.sub(r"\s+", " ", texto).strip(" ,;-_")
    return texto or None


def nome(product_name_pt, product_name):
    """O nome em português, senão o nome principal. Precisa ter uma letra."""
    for candidato in (product_name_pt, product_name):
        texto = limpar(candidato)
        if texto and re.search(r"[^\W\d_]", texto) and len(texto) >= 2:
            return texto[:120]
    return None


def marca(brands):
    """A primeira marca de "Nestlé, Ninho"."""
    if not brands:
        return None
    primeira = limpar(str(brands).split(",")[0])
    return primeira[:60] if primeira else None


def quantidade(texto):
    """O texto da quantidade como veio, limpo ("500 g", "6 x 1 L")."""
    texto = limpar(texto)
    if not texto:
        return None
    return texto[:40]


# Unidades do texto para (unidade do app, fator). O app usa g, kg, ml, l e un
# (MeasureUnit). Unidades que o app não tem viram a mais próxima: cl, dl e cc
# em ml. Miligrama fica de fora: é a dose ("30 mg"), não o tamanho.
_UNIDADES = {
    "kg": ("kg", 1), "kgs": ("kg", 1), "quilo": ("kg", 1), "quilos": ("kg", 1),
    "g": ("g", 1), "gr": ("g", 1), "grs": ("g", 1), "gramas": ("g", 1), "grama": ("g", 1),
    "l": ("l", 1), "lt": ("l", 1), "lts": ("l", 1), "litro": ("l", 1), "litros": ("l", 1),
    "ml": ("ml", 1), "cl": ("ml", 10), "dl": ("ml", 100), "cc": ("ml", 1),
    "un": ("un", 1), "u": ("un", 1), "und": ("un", 1), "unid": ("un", 1), "unidade": ("un", 1),
    "unidades": ("un", 1), "pcs": ("un", 1), "pc": ("un", 1), "rolos": ("un", 1), "rolo": ("un", 1),
    "saches": ("un", 1), "sache": ("un", 1), "capsulas": ("un", 1), "capsula": ("un", 1),
    "folhas": ("un", 1), "fraldas": ("un", 1), "tabletes": ("un", 1), "sachets": ("un", 1),
}

_NUMERO = r"\d+(?:[.,]\d+)?"
_UNIDADE = "|".join(sorted(_UNIDADES, key=len, reverse=True))
_PADRAO_TAMANHO = re.compile(
    rf"(?:(\d+)\s*[x×]\s*)?({_NUMERO})\s*({_UNIDADE})(?![a-z])"
)


def _sem_acento(texto):
    return "".join(
        c for c in unicodedata.normalize("NFD", texto) if unicodedata.category(c) != "Mn"
    )


def _numero(texto, unidade):
    """ "1,5" é 1.5; "1.000 g" é 1000 (ponto de milhar em g, ml e un)."""
    if re.fullmatch(r"\d+\.\d{3}", texto) and unidade in ("g", "ml", "un"):
        return float(texto.replace(".", ""))
    return float(texto.replace(",", "."))


def tamanho(texto, product_quantity=None, product_quantity_unit=None):
    """O tamanho e a unidade do app a partir da quantidade do Open Food Facts.

    "500 g" é (500, "g"); "1,5 L" é (1.5, "l"); "6 x 1 L" é (6, "l"), o total
    da embalagem, como o preço dela; "12 un" é (12, "un"). Mantém a unidade
    escrita (1 kg fica 1 kg, como na etiqueta). Sem tamanho legível no texto,
    usa o `product_quantity` (sempre em g ou ml). Devolve (None, None) se nada
    servir.
    """
    if texto:
        dobrado = _sem_acento(str(texto).lower())
        match = _PADRAO_TAMANHO.search(dobrado)
        if match:
            vezes, numero, unidade_texto = match.groups()
            unidade, fator = _UNIDADES[unidade_texto]
            valor = _numero(numero, unidade) * fator
            if vezes:
                valor *= int(vezes)
            valor = _arredonda(valor)
            if 0 < valor < 100000:
                return (valor, unidade)
    if product_quantity and product_quantity_unit in ("g", "ml"):
        try:
            valor = float(product_quantity)
        except (TypeError, ValueError):
            valor = 0
        if 0 < valor < 100000:
            return (_arredonda(valor), product_quantity_unit)
    return (None, None)


def _arredonda(valor):
    return round(valor, 3)


def _tag(tag):
    """ "pt:Produto de limpeza" vira "pt:produto-de-limpeza", como o Open Food
    Facts normaliza as categorias que não estão na taxonomia."""
    tag = _sem_acento(str(tag).strip().lower())
    return re.sub(r"[\s_]+", "-", tag)


def tipo(categories_tags, fonte):
    """O `ProductKind` do app para as categorias, ou None (o app deduz pelo
    nome, com `ProductKind.of`)."""
    tags = {_tag(t) for t in categories_tags or []}
    for rotulos, kind in REGRAS:
        if any(r in tags for r in rotulos):
            return kind
    return PADRAO_POR_FONTE.get(fonte)


def linha(fonte, code, nome_produto, brands, quantity, product_quantity, product_quantity_unit,
          categories_tags):
    """A linha da tabela `catalog_packages`, ou None se o produto não entra."""
    code = codigo(code)
    if not code or not nome_produto:
        return None
    size_value, size_unit = tamanho(quantity, product_quantity, product_quantity_unit)
    if size_value is None:
        # Muito produto não tem a quantidade preenchida, mas tem o tamanho no
        # nome ("Pão de forma Bauducco 400g"), como a etiqueta (ADR 0013).
        size_value, size_unit = tamanho(nome_produto)
    return {
        "barcode": code,
        "name": nome_produto,
        "brand": marca(brands),
        "quantity": quantidade(quantity),
        "size_value": size_value,
        "size_unit": size_unit,
        "kind": tipo(categories_tags, fonte),
        "source": fonte,
    }
