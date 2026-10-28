# 0015. Notificação ao vivo da compra com código nativo

- Status: Aceito
- Data: 2026-10-28

## Contexto

Durante a compra, o celular passa a maior parte do tempo no bolso ou com a tela apagada. O protótipo "Notificação ao vivo" mostra o progresso na tela de bloqueio e como chip na barra de status: quantos itens já foram, o total, a próxima seção do percurso e os botões Bipar, Lista e Terminei.

O Android 16 tem isso pronto nos Live Updates: uma notificação fixa que pede promoção (`setRequestPromotedOngoing`), com `ProgressStyle` em segmentos e um texto curto no chip (`setShortCriticalText`). Os pacotes de notificação do Flutter ainda não expõem essas APIs de forma estável. O `flutter_local_notifications` só ganhou suporte num pull request que exige androidx.core 1.19 e compileSdk 37.

## Decisão

- **A notificação é montada em Kotlin**, em `LiveShoppingNotification.kt`, com `NotificationCompat` do androidx.core 1.17 (compileSdk 36). O Dart fala com ela por um `MethodChannel` (`dev.l0rran.bipa/live_shopping`), atrás da interface `LiveNotifications`.
- **Os textos vêm prontos do Dart**, do ARB, como todos os textos do app. O lado nativo só monta a notificação. A cor dos segmentos também vai do Dart, da paleta (ADR 0009).
- **O que ela mostra:** "4 de 7 itens · R$ 54,88" no título, "Próximo · Laticínios: leite, ovos" no texto (a próxima seção na ordem aprendida, ADR 0014), o mercado no cabeçalho, "4/7" no chip e um segmento por item (até 12; acima disso, uma barra só). Antes do Android 16, é uma notificação fixa com barra de progresso.
- **Os botões abrem o app:** Bipar abre o modo carrinho, Lista abre a lista (é também o toque na notificação) e Terminei termina a compra com o mesmo Desfazer da tela. O app aberto recebe o botão pelo canal; o app fechado o lê ao abrir.
- **A notificação segue o estado da compra.** Um widget na estrutura das abas observa a compra e atualiza a notificação só quando o conteúdo muda, e a tira quando a compra termina.
- **Dispensada, não volta** na mesma compra, como pedem as diretrizes dos Live Updates.
- **A permissão de notificações** (Android 13+) é pedida no "Ir às compras", depois da localização, para os dois pedidos não se atropelarem. Sem ela, a compra segue normal, sem notificação.

## Consequências

- Primeiro código nativo do app: muda o Kotlin, o manifesto (`POST_NOTIFICATIONS`, `POST_PROMOTED_NOTIFICATIONS` e o receptor da dispensa) e o Gradle (androidx.core e compileSdk 36).
- O código nativo não tem teste automático. A conferência é manual, num emulador com Android 16 (API 36), onde a notificação aparece como Live Update. Num Android mais antigo, ela aparece como notificação fixa.
- O sistema decide a promoção: a pessoa pode desligar os Live Updates do app nas configurações, e fabricantes podem ter critérios próprios. A notificação continua aparecendo, só que sem o chip.
- Quando o `flutter_local_notifications` tiver os Live Updates numa versão estável, dá para trocar o canal próprio por ele sem mudar a interface `LiveNotifications`.
