# Skeleton

Placeholder de carregamento com o formato do conteúdo que vai aparecer e um brilho que atravessa da direita para a esquerda.

## Regras

- Use o formato real da linha (nome, metadado, stepper), nunca um spinner no meio da tela.
- Gradiente de `surface-sunken` para `surface`, ciclo de 1,4s.
- Some com fade (`duration-base`) quando o conteúdo chega; o conteúdo entra com `fade-up` de 8px.
- Como o app é offline, quase tudo carrega na hora: só mostre o esqueleto se a espera passar de 200ms.
- Com "reduzir movimento", o brilho para e fica só o bloco cinza.
