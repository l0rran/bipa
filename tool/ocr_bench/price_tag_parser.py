r"""Port em Python de lib/features/prices/domain/price_tag_parser.dart.

Serve para medir o parser contra etiquetas sintéticas e transcrições de fotos
reais sem precisar do Flutter. Mantenha em sincronia com o Dart: as regex do
Dart seguem a semântica do JavaScript (\b, \d e \w ASCII), por isso tudo
aqui usa re.ASCII.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field


@dataclass(frozen=True)
class OcrLine:
    text: str
    top: float
    height: float
    left: float | None = None
    width: float | None = None


def gtin_valid(code: str) -> bool:
    if len(code) not in (8, 12, 13, 14) or not code.isdigit():
        return False
    digits = [int(c) for c in code]
    check = digits.pop()
    total = sum(d * (3 if (len(digits) - i) % 2 == 1 else 1) for i, d in enumerate(digits))
    return (10 - total % 10) % 10 == check


def gtin_normalize(raw: str) -> str | None:
    code = re.sub(r"\s", "", raw)
    return code if gtin_valid(code) else None


def title_case(text):
    return " ".join(w[:1].upper() + w[1:].lower() if w else w for w in text.split(" "))


A = re.ASCII
AI = re.ASCII | re.IGNORECASE

DECIMAL = re.compile(r"(?<![\d.,])(\d{1,3}(?:\.\d{3})+|\d{1,4})\s?[,.]\s?(\d{2})(?!\d)", A)
SPLIT_CENTS = re.compile(r"R\$\s*(\d{1,4})\s+(\d{2})(?!\d)", A)
DATE = re.compile(r"\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}", A)
QTY_SUFFIX = re.compile(r"^\s?(kg|g|gr|ml|l|lt|un|und)\b", AI)
MEASURE_SUFFIX = re.compile(r"^\s?(kg|g|gr|ml|l|lt)\b", AI)
CURRENCY_BEFORE = re.compile(r"R\$\s*$", A)
UNIT_PRICE = re.compile(
    r"/\s?(kg|g|l|lt|ml|un|100\s?(g|ml))\b"
    r"|pre[cçÇ]o\s+(por|p/)\s"
    r"|\bp/\s?(kg|l|lt)\b"
    r"|\bpor\s+(kg|litro|quilo)\b",
    AI,
)
# "kg" logo depois do valor ("8,99 KG", "39,90 /kg") e a linha do preço por quilo.
PER_KILO_AFTER = re.compile(r"^\s?(o\s+)?/?\s?(kg|quilo)\b", AI)
PER_KILO_MARKER = re.compile(r"/\s?kg\b|\bp/\s?kg\b|\bpor\s+(kg|quilo)\b", AI)
REGULAR = re.compile(r"\b(de|normal|antes|era)\b[\s:]*(r\$)?\s*$", AI)
PROMO = re.compile(r"\b(por|oferta|promo[cçÇ][aãÃ]o)\b[\s:]*(r\$)?\s*$", AI)
INSTALLMENT = re.compile(r"\b\d{1,2}\s?x\s?(de\s+)?(r\$)?\s*$", AI)
WHOLESALE = re.compile(r"\batacado\b|\ba\s?partir\s+de\b|\bacima\s+de\b", AI)
LOYALTY = re.compile(r"\bcart[aãÃ]o\b|\bcred\b|\bclube\b|\bapp\b|\baplicativo\b|\bcliente\b|\bfidelidade\b", AI)
PROMO_LABEL = re.compile(r"^(por|oferta|promo[cçÇ][aãÃ]o)[\s:]*(r\$)?$", AI)
REGULAR_LABEL = re.compile(r"^(de|normal|antes|era|pre[cçÇ]o normal)[\s:]*(r\$)?$", AI)
QUANTITY_ONLY = re.compile(r"^(\d{1,3})\s*(un|und|unid\w*)?\.?$", AI)
NUMBER = re.compile(r"(?<![\d,.])(\d{1,3})(?![\d,.])", A)
NON_NAME = re.compile(
    r"R\$|oferta|promo|pre[cçÇ]o|validade|v[aáÁ]lido|\bleve\s+\d+|\bpague\s+\d+|\bvarejo\b|\bunidades?\b|\bcada\b",
    AI,
)
LETTER = re.compile("[A-Za-zÀ-ÿ]")
DIGIT_RUN = re.compile(r"(?<!\d)\d[\d ]{6,18}\d(?!\d)", A)
INT_END = re.compile(r"(?<![\d,.])\d{1,4}$", A)
CENTS_FRAGMENT = re.compile(r"^[,.]?\s?(\d{2})$", A)
MISSING_SEPARATOR = re.compile(r"^\s+(\d{1,2})(\d{2})(?![\d.,])", A)
SPACED_DIGITS = re.compile(r"(R\$\s?)(\d(?:\s\d){1,3})(?=\s?[,.]\s?\d{2}(?!\d))", A)

# Preços impressos bem menores que o maior (bloco de informações, preço por litro)
# continuam como candidatos, mas não viram ofertas.
OFFER_MIN_HEIGHT = 0.35
# Preços com pelo menos esta fração da altura do maior disputam o posto de principal.
SAME_SIZE = 0.8
# Distância máxima, em alturas, entre dois preços iguais lado a lado na mesma etiqueta.
TWIN_MAX_GAP = 6


@dataclass(frozen=True)
class Condition:
    kind: str  # "any" | "wholesale" | "loyalty"
    min_quantity: int | None = None


ANY = Condition("any")


@dataclass
class Offer:
    price: int
    condition: Condition
    regular_price: int | None = None


@dataclass
class Reading:
    price: int | None = None
    regular_price: int | None = None
    barcode: str | None = None
    name: str | None = None
    candidates: list[int] = field(default_factory=list)
    offers: list[Offer] = field(default_factory=list)
    per_kilo: bool = False


@dataclass
class Line:
    text: str
    top: float
    height: float
    left: float | None
    width: float | None

    @property
    def bottom(self):
        return self.top + self.height

    @property
    def right(self):
        return None if self.left is None else self.left + self.width

    @property
    def has_geometry(self):
        return self.left is not None and self.width is not None


@dataclass
class Cand:
    cents: int
    height: float
    role: str  # neutral | promo | regular
    line: int
    wholesale: bool = False
    loyalty: bool = False
    min_quantity: int | None = None
    source: "Line | None" = None
    per_kilo: bool = False


def normalize(text: str) -> str:
    text = text.replace(" ", " ")
    text = re.sub(r"R\s*\$", "R$", text)
    text = re.sub(r"\bR[S5]\s*(?=\d)", "R$ ", text, flags=A)
    text = re.sub(r"\s+", " ", text).strip()
    # "R$ 1 0,99": o OCR separou os dígitos de um número com letras espaçadas.
    return SPACED_DIGITS.sub(lambda m: m.group(1) + m.group(2).replace(" ", ""), text)


def merge_cents(lines: list[Line]) -> list[Line]:
    """Junta "R$ 18" + ",99" quando os centavos sobrescritos vêm como linha à parte."""
    used = set()
    out = []
    for i, a in enumerate(lines):
        if i in used:
            continue
        if a.has_geometry and INT_END.search(a.text) and not DECIMAL.search(a.text):
            for j, b in enumerate(lines):
                if j == i or j in used or not b.has_geometry:
                    continue
                m = CENTS_FRAGMENT.match(b.text)
                if not m or b.height >= 0.8 * a.height:
                    continue
                gap = b.left - a.right
                if -0.1 * a.height <= gap <= 0.6 * a.height and a.top - 0.25 * a.height <= b.top <= a.top + 0.5 * a.height:
                    a = Line(f"{a.text},{m.group(1)}", a.top, a.height, a.left, b.right - a.left)
                    used.add(j)
                    break
        out.append(a)
    return out


def find_prices(text: str, height: float, index: int, source: Line | None = None) -> list[Cand]:
    out = []
    for m in DECIMAL.finditer(text):
        prefix, suffix = text[: m.start()], text[m.end():]
        if QTY_SUFFIX.search(suffix) and not CURRENCY_BEFORE.search(prefix):
            continue
        if INSTALLMENT.search(prefix):
            continue
        c = _to_cand(prefix, int(m.group(1).replace(".", "")), int(m.group(2)), height, index)
        if c:
            c.source = source
            c.per_kilo = bool(PER_KILO_AFTER.search(suffix))
            out.append(c)
            n = _neighbor_without_separator(text, m.end(), c, height, index)
            if n:
                n.source = source
                out.append(n)
    if out:
        return out
    for m in SPLIT_CENTS.finditer(text):
        c = _to_cand(text[: m.start()], int(m.group(1)), int(m.group(2)), height, index)
        if c:
            out.append(c)
    return out


def _neighbor_without_separator(text, end, previous, height, index):
    """Preço vizinho lido sem a vírgula: "13,89 1535" é 13,89 e 15,35."""
    m = MISSING_SEPARATOR.match(text[end:])
    if not m or QTY_SUFFIX.search(text[end + m.end():]):
        return None
    c = _to_cand(text[: end + m.start()], int(m.group(1)), int(m.group(2)), height, index)
    if c and 0.5 <= c.cents / previous.cents <= 2:
        return c
    return None


def _to_cand(prefix, whole, cents, height, index):
    value = whole * 100 + cents
    if value <= 0:
        return None
    role = "promo" if PROMO.search(prefix) else "regular" if REGULAR.search(prefix) else "neutral"
    c = Cand(value, height, role, index)
    if WHOLESALE.search(prefix):
        c.wholesale = True
        c.min_quantity = _quantity_in(prefix)
    if LOYALTY.search(prefix):
        c.loyalty = True
    return c


def _quantity_in(text):
    m = WHOLESALE.search(text)
    if not m:
        return None
    n = NUMBER.search(text, m.end())
    return (int(n.group(1)) or None) if n else None


def _h_overlap(a: Line, b: Line):
    return min(a.right, b.right) - max(a.left, b.left)


def _v_gap(a: Line, b: Line):
    return max(0.0, max(a.top, b.top) - min(a.bottom, b.bottom))


def _nearest_price_line(label_idx, lines, price_lines):
    """Linha de preço a que um rótulo se refere: mesma coluna (acima ou abaixo) ou mesma linha, à direita."""
    label = lines[label_idx]
    if not label.has_geometry:
        after = [i for i in price_lines if i > label_idx]
        return after[0] if after else None
    best, best_gap = None, None
    for i in price_lines:
        p = lines[i]
        if not p.has_geometry:
            continue
        same_column = _h_overlap(label, p) > 0
        same_row = _v_gap(label, p) == 0 and 0 <= p.left - label.right < p.height
        if not (same_column or same_row):
            continue
        gap = 0.0 if same_row else _v_gap(label, p)
        if gap <= 1.5 * p.height and (best_gap is None or gap < best_gap):
            best, best_gap = i, gap
    return best


def _quantity_near(label_idx, lines):
    """Quantidade mínima impressa na linha seguinte da mesma coluna ("A PARTIR DE" / "10" / "UNIDADES")."""
    label = lines[label_idx]
    for j, other in enumerate(lines):
        if j == label_idx or not QUANTITY_ONLY.match(other.text):
            continue
        if label.has_geometry and other.has_geometry:
            if _h_overlap(label, other) > 0 and _v_gap(label, other) < 2 * label.height:
                return int(QUANTITY_ONLY.match(other.text).group(1)) or None
        elif j == label_idx + 1:
            return int(QUANTITY_ONLY.match(other.text).group(1)) or None
    return None


def choose(pool):
    if not pool:
        return None
    for role_ok in (lambda c: c.role == "promo", lambda c: c.role != "regular", lambda c: True):
        eligible = [c for c in pool if role_ok(c)]
        if eligible:
            best = eligible[0]
            for c in eligible[1:]:
                if c.height > best.height:
                    best = c
            return best


def condition_of(c: Cand) -> Condition:
    if c.wholesale:
        return Condition("wholesale", c.min_quantity)
    if c.loyalty:
        return Condition("loyalty")
    return ANY


def _labels_of(text):
    """O que uma linha sem preço diz sobre o preço a que se refere (ou None)."""
    labels = dict(
        wholesale=bool(WHOLESALE.search(text)),
        loyalty=bool(LOYALTY.search(text)),
        promo=bool(PROMO_LABEL.match(text)),
        regular=bool(REGULAR_LABEL.match(text)),
        min_quantity=None,
    )
    return labels if any(v for k, v in labels.items() if k != "min_quantity") else None


def _merge_labels(a, b):
    if a is None:
        return b
    return dict(
        wholesale=a["wholesale"] or b["wholesale"],
        loyalty=a["loyalty"] or b["loyalty"],
        promo=a["promo"] or b["promo"],
        regular=a["regular"] or b["regular"],
        min_quantity=a["min_quantity"] if a["min_quantity"] is not None else b["min_quantity"],
    )


def parse(lines, barcodes=()):
    # Mesma ordem do Dart: normaliza, junta os centavos, ordena e só então tira as datas.
    normalized = [Line(normalize(l.text), l.top, l.height, l.left, l.width) for l in lines]
    ordered = sorted(merge_cents(normalized), key=lambda l: l.top)
    texts = [DATE.sub(" ", l.text).strip() for l in ordered]

    price_lines = [i for i, t in enumerate(texts) if t and find_prices(t, 0, i)]

    labels_by_line = {}
    for i, text in enumerate(texts):
        if not text or i in price_lines:
            continue
        found = _labels_of(text)
        if found is None:
            continue
        if found["wholesale"]:
            found["min_quantity"] = _quantity_in(text) or _quantity_near(i, ordered)
        target = _nearest_price_line(i, ordered, price_lines)
        if target is not None:
            labels_by_line[target] = _merge_labels(labels_by_line.get(target), found)

    cands, unit = [], []
    for i in price_lines:
        found = find_prices(texts[i], ordered[i].height, i, ordered[i])
        lab = labels_by_line.get(i)
        if lab:
            for c in found:
                if c.role == "neutral":
                    c.role = "promo" if lab["promo"] else "regular" if lab["regular"] else "neutral"
                if lab["wholesale"]:
                    c.wholesale = True
                    c.min_quantity = c.min_quantity or lab["min_quantity"]
                if lab["loyalty"]:
                    c.loyalty = True
        is_unit = bool(UNIT_PRICE.search(texts[i]))
        if is_unit and PER_KILO_MARKER.search(texts[i]):
            # Na linha do preço por quilo, todo valor é por quilo.
            for c in found:
                c.per_kilo = True
        (unit if is_unit else cands).extend(found)

    pool = cands or unit
    offers = [] if _unlabeled_multi_price(pool) else _offers(pool)
    main = offers[0] if offers else None
    per_kilo = main is not None and any(
        c.per_kilo and c.cents == main.price and condition_of(c) == main.condition for c in pool
    )
    seen = []
    for c in pool:
        if c.cents not in seen:
            seen.append(c.cents)
    return Reading(
        price=main.price if main else None,
        regular_price=main.regular_price if main else None,
        barcode=_barcode(barcodes, ordered),
        name=_name(ordered),  # como no Dart, com as datas
        candidates=seen,
        offers=offers,
        per_kilo=per_kilo,
    )


def _unlabeled_multi_price(pool):
    """Mais de um preço do mesmo tamanho e nenhum rótulo lido: nenhum é escolhido."""
    if not pool:
        return False
    tallest = max(c.height for c in pool)
    same = [c for c in pool if c.height >= SAME_SIZE * tallest]
    if any(c.role != "neutral" or condition_of(c) != ANY for c in same):
        return False
    if len({c.cents for c in same}) > 1:
        return True
    return any(_side_by_side(a.source, b.source) for i, a in enumerate(same) for b in same[i + 1:])


def _side_by_side(a, b):
    if a is None or b is None or a is b or not a.has_geometry or not b.has_geometry:
        return False
    gap = max(a.left, b.left) - min(a.right, b.right)
    return _v_gap(a, b) == 0 and gap <= TWIN_MAX_GAP * max(a.height, b.height)


def _offers(pool):
    if not pool:
        return []
    tallest = max(c.height for c in pool)
    big = [c for c in pool if c.height >= OFFER_MIN_HEIGHT * tallest or c.role == "regular"]
    groups: dict[Condition, list[Cand]] = {}
    for c in big:
        groups.setdefault(condition_of(c), []).append(c)
    offers, orphans = [], None
    for cond, group in groups.items():
        if cond == ANY and len(groups) > 1 and all(c.role == "regular" for c in group):
            orphans = group  # "de R$" solto: é o preço normal da oferta principal
            continue
        best = choose(group)
        regular = None
        for c in group:
            if c.role == "regular" and c.cents > best.cents and (regular is None or c.cents > regular):
                regular = c.cents
        offers.append(Offer(best.cents, cond, regular))
    rank = {"any": 0, "loyalty": 1, "wholesale": 2}
    offers.sort(key=lambda o: rank[o.condition.kind])  # sort do Python é estável
    if orphans and offers[0].regular_price is None:
        regular = max(c.cents for c in orphans)
        if regular > offers[0].price:
            offers[0].regular_price = regular
    return offers


def _barcode(barcodes, lines):
    for b in barcodes:
        n = gtin_normalize(b)
        if n:
            return n
    for line in lines:
        for m in DIGIT_RUN.finditer(line.text):
            code = gtin_normalize(m.group(0))
            if code and len(code) >= 12:
                return code
    return None


NOISE = re.compile(r"([A-Za-z])\1{3,}", A)


def _looks_like_noise(text):
    """Lixo típico de OCR: a mesma letra repetida ("oooooo", "iiiii")."""
    return bool(NOISE.search(text))


def _name(lines):
    for line in lines:
        text = line.text
        if NON_NAME.search(text) or WHOLESALE.search(text) or LOYALTY.search(text) or find_prices(text, 0, 0):
            continue
        letters = len(LETTER.findall(text))
        visible = len(text.replace(" ", ""))
        if letters >= 4 and letters / visible >= 0.5 and not _looks_like_noise(text):
            return title_case(text)
    return None
