# 0010. Mostrar foto do produto, com o ícone da categoria como reserva

- Status: Aceito
- Data: 2026-10-27

## Contexto

A interface do Bipa mostra cada produto por imagem em vez de só pelo nome (regra "todo texto precisa se justificar"), como o iFood faz com os produtos. Mas o app é offline e começa sem base de produtos: muitos itens não vão ter foto, e uma imagem genérica de "produto" daria a entender que é a foto real.

## Decisão

A imagem de um produto vem, nesta ordem:

1. **Foto da pessoa:** tirada no aparelho (ao bipar ou na tela do produto) e guardada na pasta de documentos do app, em `fotos/`. O produto guarda só o caminho relativo (`Product.photoPath`, esquema v2 do banco), para não quebrar se o caminho absoluto mudar.
2. **Open Food Facts:** quando houver internet, a foto da frente da embalagem pelo código de barras (API v2, campo `selected_images`, na resolução de 200 px), baixada uma vez e guardada como foto do produto. Entra junto com a fase de sincronização.
3. **Ícone da categoria:** deduzido do nome (`productCategoryIcon`), num quadro neutro. Nunca uma foto genérica.

Na interface, `ProductThumb` (lista) e a arte do `ProductCard` (prateleira) tentam a foto e caem no ícone se ela não existir ou falhar ao abrir.

## Consequências

- O app funciona do mesmo jeito sem nenhuma foto; elas só melhoram a leitura.
- As fotos ficam no aparelho e entram no backup local. Compartilhar fotos na base comunitária exige revisão de privacidade (fotos tiradas em casa podem mostrar mais que o produto).
- Usar imagens do Open Food Facts exige respeitar a licença delas (Creative Commons BY-SA) e citar a fonte na tela do produto.
