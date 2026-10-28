# 0014. Aprender a ordem das seções em cada mercado

- Status: Aceito
- Data: 2026-10-28

## Contexto

A lista agrupa os itens pelas seções do mercado (hortifrúti, mercearia, laticínios…) numa ordem genérica. Cada mercado tem o seu percurso: num, a limpeza fica na entrada; noutro, no fundo. Com a ordem genérica, a pessoa pula de um lado para o outro da lista enquanto anda pelo mercado.

Outros apps resolvem de dois jeitos. O AnyList deixa montar à mão um conjunto de categorias por loja, o que dá trabalho e quase ninguém faz. O app *Grocery* aprende pela ordem em que os itens são marcados. Já sabemos em que mercado a compra acontece (a localização no "Ir às compras") e quando cada item foi marcado ou bipado. Dá para aprender sem pedir nada.

## Decisão

- **A ordem é aprendida no "Terminei"**, só quando a compra tem mercado. Os sinais são o horário em que cada item da lista foi marcado durante a compra e o horário do bipe do que entrou no carrinho sem estar na lista.
- **Cada seção entra no percurso pelo horário mediano dos seus itens.** A mediana ignora a volta para buscar algo esquecido. "Outros" não ensina nada (pode estar em qualquer lugar) e fica sempre no fim. Com menos de duas seções, não há ordem para aprender.
- **As seções visitadas trocam de lugar só entre si.** Elas ocupam os mesmos lugares que já tinham, redistribuídos na ordem vista; as que não foram visitadas ficam onde estavam. Assim, uma compra só de hortifrúti e limpeza não empurra os laticínios para o fim.
- **Uma compra fora do comum anda só metade do caminho.** Na primeira vez, a seção vai direto para o lugar visto; depois, a posição se move metade da distância. Algumas compras no mesmo mercado bastam para firmar a ordem.
- **A lista usa a ordem do mercado dela.** Durante a compra, é o mercado da compra. Fora dela, é o escolhido no chip do mercado (protótipo "Lista") ou, sem escolha, o da última compra que teve mercado. O "Ir às compras" começa com o mercado escolhido no chip, que vale mais que a localização.
- **O "Desfazer" do "Terminei" volta para a ordem de antes**, para um "Terminei" repetido não aprender duas vezes.
- **Dados (esquema 8).** Uma tabela `market_aisles` com mercado, seção, posição (de 0 a 1) e quantas compras a confirmaram. É privada, como a lista e as compras (ADR 0007): fica no aparelho.

## Consequências

- A lista se arruma sozinha depois de algumas compras no mesmo mercado, sem nenhuma tela nova.
- A seção vem do tipo do produto, deduzido do nome. Um produto mal classificado ensina a seção errada. Melhorar a classificação melhora o percurso.
- A ordem é por seção, não por item: dois itens da mesma seção continuam na ordem em que entraram na lista.
- Quem nunca fez uma compra com mercado vê a ordem genérica até escolher um no chip.
- No futuro, o percurso de cada mercado pode vir da comunidade (a ordem é do mercado, não da pessoa). Isso fica para o ADR de sincronização.
