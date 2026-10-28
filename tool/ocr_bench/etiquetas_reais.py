"""Etiquetas reais (fotos do Assaí enviadas pelo mantenedor), transcritas linha a linha.

Cada linha: (texto, left, top, width, height), nas coordenadas do recorte ampliado.
Espera: ofertas [(condição, mínimo, centavos)], com a principal primeiro.
Os casos "mlkit_*" são a saída real do ML Kit (emulador) para recortes de vídeo:
os rótulos pequenos não são lidos, e o nome sai errado ou não sai.
"""

FIXTURES = {
    "assai_feijao_3_precos": dict(
        lines=[
            ("FEIJAO CARIOCA KICALDO T1 1KG", 35, 170, 340, 22),
            ("FEIJAO CARIOCA KICALDO T1 1KG", 40, 200, 230, 12),
            ("VAREJO R$", 360, 205, 70, 12),
            ("8.05", 370, 216, 66, 32),
            ("PASSAI CRED R$", 222, 240, 100, 14),
            ("7.85", 235, 254, 72, 36),
            ("ATACADO R$", 70, 278, 95, 14),
            ("À UNIDADE", 365, 285, 70, 10),
            ("7.85", 88, 297, 76, 34),
            ("À UNIDADE", 238, 320, 70, 12),
            ("A PARTIR DE", 90, 345, 70, 10),
            ("10", 113, 357, 28, 22),
            ("UNIDADES", 95, 381, 62, 10),
        ],
        offers=[("any", None, 805), ("loyalty", None, 785), ("wholesale", 10, 785)],
        name="Feijao Carioca Kicaldo T1 1kg",
    ),
    "assai_minuano_sem_varejo": dict(
        lines=[
            ("DET LIQ MINUANO 500ml COCO", 80, 85, 670, 40),
            ("DET LIQ MINUANO 500ml COCO", 85, 145, 470, 16),
            ("ATACADO R$", 130, 183, 185, 16),
            ("PASSAI CRED R$", 400, 192, 285, 18),
            ("1,79", 175, 210, 135, 52),
            ("1,79", 475, 222, 160, 58),
            ("A PARTIR DE", 165, 296, 130, 10),
            ("06", 195, 315, 60, 34),
            ("A UNIDADE", 430, 335, 220, 24),
            ("UNIDADES", 165, 357, 110, 10),
            ("CXA 10,74", 70, 400, 120, 12),
            ("Preço por L", 70, 450, 80, 12),
            ("Atacado 3,58", 70, 470, 120, 12),
            ("Varejo 3,58", 70, 490, 120, 12),
        ],
        offers=[("loyalty", None, 179), ("wholesale", 6, 179)],
        name="Det Liq Minuano 500ml Coco",
    ),
    "assai_veja_sem_quantidade": dict(
        # A quantidade mínima é um ícone, não um número.
        lines=[
            ("LIMP VEJA PERF 2L LAVANDA DA FRANCA", 125, 60, 520, 40),
            ("ATACADO R$", 135, 175, 110, 16),
            ("13.89", 135, 215, 110, 50),
            ("PASSAI CRED R$", 285, 255, 140, 16),
            ("13.89", 300, 300, 115, 55),
            ("A PARTIR DE", 140, 300, 90, 10),
            ("VAREJO R$", 490, 375, 90, 14),
            ("15.35", 485, 400, 115, 52),
            ("À UNIDADE", 300, 420, 100, 14),
            ("À UNIDADE", 470, 530, 100, 12),
        ],
        offers=[("any", None, 1535), ("loyalty", None, 1389), ("wholesale", None, 1389)],
        name="Limp Veja Perf 2l Lavanda Da Franca",
    ),
    "assai_preco_por_unidade": dict(
        lines=[
            ("BATATA PALHA YOKI EXTRA FINA 100g TRAD", 15, 10, 280, 12),
            ("Preço Por Unidade", 30, 35, 120, 14),
            ("R$", 25, 85, 14, 10),
            ("5,99", 75, 70, 75, 30),
        ],
        offers=[("any", None, 599)],
        name="Batata Palha Yoki Extra Fina 100g Trad",
    ),
    "assai_oferta_pendurada": dict(
        lines=[
            ("OFERTA", 250, 30, 90, 18),
            ("LAVA ROUPA LIQ", 240, 75, 110, 12),
            ("ASSAI", 240, 90, 50, 12),
            ("BLOOM 3L", 240, 105, 70, 12),
            ("24,89", 230, 120, 130, 40),
        ],
        offers=[("any", None, 2489)],
        name="Lava Roupa Liq",
    ),
    "assai_oferta_fralda": dict(
        lines=[
            ("OFERTA", 90, 70, 110, 20),
            ("FRALDA HUGGIES MAX PROT", 55, 125, 160, 12),
            ("59,90", 80, 145, 105, 34),
        ],
        offers=[("any", None, 5990)],
        name="Fralda Huggies Max Prot",
    ),
    "mlkit_veja_dois_precos_sem_rotulo": dict(
        lines=[
            ("13,89 1535", 269, 129, 70, 47),
            ("Sarol", 138, 371, 184, 157),
        ],
        offers=[],
        candidates=[1389, 1535],
    ),
    "mlkit_feijao_gemeos_sem_rotulo": dict(
        lines=[
            ("Carioca", 46, 3, 63, 20),
            ("7,85", 101, 170, 29, 18),
            ("7,85", 153, 158, 22, 16),
        ],
        offers=[],
        candidates=[785],
    ),
    "mlkit_minuano_gemeos_sem_rotulo": dict(
        lines=[
            ("1.79", 180, 78, 33, 13),
            ("06", 185, 104, 13, 9),
            ("1,79", 254, 79, 39, 14),
            ("A UNIDADE", 243, 108, 53, 9),
        ],
        offers=[],
        candidates=[179],
    ),
    "mlkit_batata_duas_etiquetas": dict(
        lines=[
            ("LATA PALU YOLL EXTNA FNA I", 16, 33, 190, 19),
            ("Precs Por Unidade", 25, 59, 98, 12),
            ("5.99", 77, 81, 53, 16),
            ("Prece Pur Untsde", 323, 49, 104, 15),
            ("5,99", 365, 70, 59, 19),
        ],
        offers=[("any", None, 599)],
    ),
}
