/// Fonte de tempo injetável, para que regras que dependem da data atual
/// possam ser testadas de forma determinística.
typedef Clock = DateTime Function();

/// Relógio padrão, baseado no horário do aparelho.
DateTime systemClock() => DateTime.now();
