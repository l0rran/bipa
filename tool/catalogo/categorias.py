"""Tabela de categorias do Open Food Facts para o `ProductKind` do app.

As regras são conferidas em ordem, e a primeira cujo rótulo está nas
`categories_tags` do produto vence. Como o Open Food Facts põe no produto a
categoria e todas as categorias-mãe ("en:uht-milks" vem com "en:milks" e
"en:dairies"), as mais específicas ficam antes, na mesma lógica da lista de
palavras de `lib/core/catalog/product_kind.dart`:

- leite condensado, creme de leite e doce de leite são doces, não laticínio;
- leite longa vida e em pó, conservas, atum e sardinha são de prateleira;
- café e chá vêm antes de bebida (no Open Food Facts eles são "beverages");
- congelado vem antes de massa, carne e doce ("lasanha congelada", sorvete).

Muitos produtos vêm com a categoria em espanhol, fora da taxonomia
("en:Lácteos"); `catalogo.tipo` tira acento e maiúscula antes de comparar, e
as mais comuns estão aqui também.

Os nomes à direita são os do enum `ProductKind` (lib/core/catalog/product_kind.dart).
"""

# Os nomes válidos do enum ProductKind do app, para o teste conferir a tabela.
PRODUCT_KINDS = {
    "sweets", "coffee", "tea", "dairy", "eggs", "bakery", "grains", "pasta",
    "baking", "oils", "meat", "fish", "shelfStable", "produce", "frozen",
    "laundry", "cleaning", "hygiene", "pet", "drinks", "other",
}

REGRAS = [
    # Pet antes de tudo: "ração de frango" não é carne.
    (["en:pet-food", "en:dog-food", "en:cat-food", "en:pet-foods", "en:dogs-food", "en:cats-food"], "pet"),
    # Limpeza e roupa (Open Products Facts e alguns no Open Food Facts).
    (
        [
            "en:laundry-detergents", "en:laundry-detergent", "en:laundry-supplies", "en:fabric-softeners",
            "en:laundry-powders", "en:stain-removers", "pt:amaciante-de-roupas", "pt:sabao-em-po",
        ],
        "laundry",
    ),
    (
        [
            "en:household-cleaning-products", "en:household-cleaning-supplies", "en:household-chemicals",
            "en:dishwashing-liquids", "en:dishwashing-detergents", "en:dishwashing-products",
            "en:all-purpose-cleaners", "en:muti-surface-cleaners", "en:multi-surface-cleaners",
            "en:glass-surface-cleaners", "en:bleaches", "en:disinfectants", "en:detergents",
            "en:cleaning-and-disinfecting-solutions", "en:cleaning-equipment-and-supplies", "en:sponges",
            "en:cleaning-products", "en:limpeza", "pt:limpeza", "pt:produto-de-limpeza", "pt:detergente",
            "pt:agua-sanitaria", "pt:desinfetante",
        ],
        "cleaning",
    ),
    # Higiene (Open Beauty Facts e fraldas, papel higiênico do Open Products Facts).
    (
        [
            "en:toilet-papers", "en:toilet-paper", "en:infant-diapers", "en:diapers", "en:toothpastes",
            "en:toothbrushes", "en:mouthwashes", "en:shampoos", "en:conditioners", "en:hair-conditioners",
            "en:soaps", "en:bar-soaps", "en:liquid-soaps", "en:shower-gels", "en:deodorants",
            "en:antiperspirants", "en:body-lotions", "en:moisturizers", "en:sunscreens", "en:razors",
            "en:sanitary-pads", "en:feminine-hygiene", "en:personal-care-products", "en:hair-products",
            "en:hygiene", "en:cosmetics", "en:body-care", "en:hair-care", "en:oral-care", "en:skin-care",
            "pt:produtos-para-cabelos", "pt:higiene", "pt:higiene-pessoal",
        ],
        "hygiene",
    ),
    # Congelados antes de massa, carne e doce.
    (
        [
            "en:frozen-foods", "en:frozen-desserts", "en:ice-creams-and-sorbets", "en:ice-creams",
            "en:frozen-ready-made-meals", "en:frozen-pizzas", "en:frozen-vegetables", "en:frozen-fruits",
            "en:frozen-meats", "en:frozen-fishes", "en:frozen-french-fries", "en:chicken-nuggets",
            "en:frozen-chicken",
            "en:helados",
        ],
        "frozen",
    ),
    # Doces, com o leite condensado, o creme de leite e o doce de leite (como o app).
    (
        [
            "en:sweetened-condensed-milks", "en:condensed-milks", "en:dulce-de-leche", "en:creams",
            "en:cooking-creams", "en:chocolates", "en:cocoa-and-chocolate-powders", "en:cocoa-powders",
            "en:chocolate-powders", "en:instant-chocolate-drinks", "en:biscuits", "en:biscuits-and-cakes",
            "en:cookies", "en:wafers", "en:cakes", "en:candies", "en:confectioneries", "en:chewing-gum",
            "en:sweet-spreads", "en:hazelnut-spreads", "en:jams", "en:desserts", "en:dessert-mixes",
            "en:gelatin-desserts", "en:sweet-snacks",
            "en:galletas", "en:galletas-de-chocolate", "en:dulces", "en:postres", "en:dulces-untables",
        ],
        "sweets",
    ),
    (["en:coffees", "en:coffee-capsules", "en:ground-coffees", "en:instant-coffees", "en:coffee-drinks"], "coffee"),
    (["en:teas", "en:herbal-teas", "en:green-teas", "en:yerba-mate", "en:mate", "en:tea-bags", "en:iced-teas"], "tea"),
    # De prateleira antes de laticínio, peixe e bebida.
    (
        [
            "en:uht-milks", "en:long-life-milks", "en:milk-powders", "en:powdered-milks", "en:coconut-milks",
            "en:canned-foods", "en:canned-fishes", "en:canned-tunas", "en:tunas-in-oil", "en:canned-sardines",
            "en:sardines-in-oil", "en:canned-vegetables", "en:canned-fruits", "en:canned-meats",
            "en:canned-legumes", "en:pickles", "en:tomato-sauces", "en:tomato-pastes", "en:tomato-purees",
            "en:sauces", "en:condiments", "en:mayonnaises", "en:ketchup", "en:mustards", "en:soups",
            "en:broths", "en:bouillon-cubes", "en:spices", "en:seasonings", "en:salty-snacks", "en:chips",
            "en:crisps", "en:appetizers", "en:nuts", "en:peanuts",
            "en:snacks", "en:peanut-butters", "en:legume-butters", "en:atun", "en:papas-fritas", "en:salsas",
            "en:frutos-secos",
        ],
        "shelfStable",
    ),
    (
        [
            "en:dairies", "en:milks", "en:yogurts", "en:cheeses", "en:butters", "en:margarines",
            "en:fermented-milk-products", "en:cream-cheeses", "en:requeijao", "en:dairy-desserts",
            "en:lacteos", "en:yogures", "en:yogures-batidos", "en:yogures-de-frutas", "en:quesos", "en:leches",
            "en:leches-saborizadas",
        ],
        "dairy",
    ),
    (["en:eggs", "en:chicken-eggs"], "eggs"),
    (["en:breads", "en:sliced-breads", "en:toasts", "en:rusks", "en:viennoiseries", "en:pastries", "en:pan", "en:panes"], "bakery"),
    (["en:pastas", "en:noodles", "en:instant-noodles", "en:lasagna", "en:spaghetti", "en:dry-pastas"], "pasta"),
    (
        [
            "en:flours", "en:wheat-flours", "en:corn-flours", "en:cornmeals", "en:cassava-flours",
            "en:starches", "en:sugars", "en:salts", "en:baking-aids", "en:baking-powders", "en:yeasts",
            "en:cake-mixes", "en:baking-mixes", "en:sweeteners",
        ],
        "baking",
    ),
    # Grãos depois de massa e farinha: "en:cereals-and-their-products" também as inclui.
    (
        [
            "en:rices", "en:legumes", "en:common-beans", "en:beans", "en:lentils", "en:chickpeas",
            "en:cereal-grains", "en:cereals-and-their-products", "en:breakfast-cereals", "en:oat-flakes",
            "en:oats", "en:corn", "en:popcorn", "en:quinoa", "en:granolas", "en:seeds",
            "en:cereales", "en:cereales-para-desayuno",
        ],
        "grains",
    ),
    (["en:vegetable-oils", "en:olive-oils", "en:oils", "en:vinegars", "en:fats", "en:vegetable-fats"], "oils"),
    (["en:fishes", "en:seafood", "en:fishes-and-their-products", "en:pescados"], "fish"),
    (
        [
            "en:meats", "en:poultries", "en:prepared-meats", "en:sausages", "en:hams", "en:bacon",
            "en:meats-and-their-products", "en:chickens", "en:carnes",
        ],
        "meat",
    ),
    (
        [
            "en:fresh-fruits", "en:fresh-vegetables", "en:fruits", "en:vegetables", "en:dried-fruits",
            "en:fresh-plant-based-foods",
        ],
        "produce",
    ),
    # Bebidas por último: muitas categorias acima também são "beverages".
    (
        [
            "en:beverages", "en:waters", "en:mineral-waters", "en:sodas", "en:juices", "en:fruit-juices",
            "en:nectars", "en:alcoholic-beverages", "en:beers", "en:wines", "en:energy-drinks",
            "en:plant-based-beverages", "en:plant-based-milks", "en:soy-milks",
            "en:bebidas", "en:bebidas-alcoholicas", "en:bebidas-gaseosas", "en:jugos-de-fruta", "en:cervezas",
        ],
        "drinks",
    ),
]

# Sem categoria reconhecida, o tipo padrão de cada fonte: tudo o que está no
# Open Beauty Facts é higiene. No Open Products Facts há de tudo (pilha,
# eletrônico, cigarro), então não há padrão.
PADRAO_POR_FONTE = {"obf": "hygiene"}
