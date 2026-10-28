# 0019. Casa e lista no mesmo gesto, com um só "Desfazer"

- Status: Aceito
- Data: 2026-10-28

## Contexto

Bipar em casa mudava só o estoque. O leite registrado no modo "Comprei" continuava na lista. Dar baixa na última embalagem não punha nada nela, e a pessoa tinha que lembrar de abrir a lista. O roadmap pede as duas coisas ("fechar o ciclo"), e também pede "Desfazer" em toda ação que muda o estoque.

Nem toda mudança no estoque é igual. Um bipe ou um gesto acontece de passagem, e a pessoa nem sempre olha a tela. Já um stepper aberto mostra o número mudando, e o botão do outro lado volta o passo. Um aviso com "Desfazer" a cada toque no stepper seria ruído ("calma por padrão").

## Decisão

- O caso de uso `RecordAtHome` (domínio da lista) muda estoque e lista juntos, numa transação (`UnitOfWork`):
  - **Comprei** soma uma embalagem e tira o produto da lista. Quando faltava mais de uma, só diminui a quantidade. Um item já marcado como comprado (durante uma compra) fica como está.
  - **Usei** tira uma embalagem. Se o produto fica abaixo do "ter sempre" (ou acaba) e não está na lista, entra nela com o que falta (`PutProductOnList`).
  - Ele devolve um `HomeChange`, com o `StockChange` (ADR 0013) e o que mudou na lista. O `undo` volta os dois. Quando o produto já estava na lista, o desfazer não o tira de lá.
- Passam pelo `RecordAtHome` as ações de passagem: os modos "Comprei" e "Usei" da câmera, o deslizar "Usei um" do Início e o "Também comprei" da folha de conferir preço. Todas mostram o mesmo aviso (`showHomeChangeSnackBar`), que diz o que mudou na lista, com "Desfazer".
- No "Usei", um item já marcado como comprado (durante uma compra) conta como "na lista" e não volta a faltar: o "Terminei" ainda vai levar para casa o que foi comprado.
- Os steppers (linha aberta do Início, folha do item e tela do produto) são correções. Eles mudam só o estoque, sem aviso: o botão oposto é o desfazer.
- Os steppers se anunciam como correção ("Uma embalagem a menos" / "a mais"). "Usei um" e "Comprei um" ficam só para o que passa pelo `RecordAtHome`, para o mesmo nome ter sempre o mesmo efeito.
- A compra segue a mesma ideia: o "Terminei" só leva para casa, e só tira da lista, o que foi marcado depois do começo dela (`ShoppingListItem.isCheckedSince`), e cancelar desmarca isso. Um item marcado em casa dias antes não vira compra de hoje.
- "Tirar de casa" continua com confirmação (ADR 0016), porque apaga os lotes.
- O "Terminei" do modo compra já fazia o mesmo com o que foi marcado e tem o próprio desfazer.

## Consequências

- A lista acompanha a casa sem passo extra, e o aviso deixa claro quando isso acontece.
- Corrigir o estoque pelo stepper não põe nada na lista. Quem corrige vê o nível na hora e tem "Pôr na lista" ao lado.
- O aviso fala da lista, não do estoque. Na câmera, o número em casa já aparece no aviso do visor.
