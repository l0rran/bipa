# 0011. Registrar cada preço da etiqueta com a sua condição

- Status: Aceito
- Data: 2026-10-27

## Contexto

As etiquetas de atacarejo (Assaí, Atacadão, Tenda) trazem até três preços para o mesmo produto: o de **atacado**, que vale a partir de um número mínimo de unidades; o do **cartão da loja** (Passaí Cred, Cartão Atacadão); e o de **varejo**, que vale para qualquer cliente. Supermercados com programa de fidelidade fazem o mesmo com o "preço clube" ou "no app".

O modelo atual guarda um preço e, opcionalmente, o preço sem desconto. Com ele, o parser precisava escolher um dos três preços e descartar os outros, e a escolha estava errada para metade das pessoas. Quem tem o cartão paga um valor, quem não tem paga outro, e quem leva dez unidades paga um terceiro.

## Decisão

- **Cada preço é uma observação, com a sua condição.** `PriceObservation` ganha `condition`, uma classe selada `PriceCondition` com três casos:
  - `AnyCustomer`: qualquer cliente leva uma unidade por esse preço. É o padrão, e corresponde ao varejo e às etiquetas comuns.
  - `LoyaltyMembers`: vale com o cartão, o clube ou o app da loja.
  - `Wholesale(minimumQuantity)`: vale a partir de N unidades. O mínimo pode ser desconhecido quando o OCR não o lê.
- **Promoção continua separada da condição.** O "de/por" segue em `regularPrice`: é o mesmo cliente pagando menos por um tempo, não um público diferente.
- **No banco**, duas colunas em `price_observations`: `condition_kind` (texto, padrão `anyCustomer`) e `minimum_quantity` (inteiro, nulo). A migração para a versão 3 do esquema preenche as observações antigas com `anyCustomer`.
- **A leitura da etiqueta devolve ofertas.** `PriceTagReading.offers` lista um preço por condição, com o preço sem condição primeiro. A tela de captura mostra todos e grava uma observação por oferta marcada, todas com o mesmo horário.
- **A comparação entre mercados usa o preço sem condição.** Um mercado só entra com o preço de cartão ou de atacado quando não há preço sem condição registrado nele.

## Consequências

- O histórico mostra os três preços do Assaí, e a pessoa vê se o cartão ou o atacado compensam.
- A base comunitária (fase 2) recebe a condição junto com o preço, e as comparações não misturam preços com públicos diferentes.
- Para associar os rótulos ("ATACADO", "A PARTIR DE 10 UNIDADES", "PASSAÍ CRED") ao preço da mesma coluna, o parser precisa da posição horizontal das linhas. Por isso `OcrLine` ganha `left` e `width`, que o ML Kit já informa.
- O "preço clube" deixa de ser tratado como promoção: vira uma oferta `LoyaltyMembers`, e o preço comum vira a oferta `AnyCustomer`.
- O protótipo da tela de confirmação precisa de uma versão com mais de um preço.
