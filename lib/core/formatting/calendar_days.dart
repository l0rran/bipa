import 'dart:math' as math;

/// Quantos dias do calendário vão de [then] a [now]: o preço de ontem à
/// noite é "de ontem", mesmo que tenham passado poucas horas. Uma data no
/// futuro (relógio do aparelho errado, ou outro fuso na sincronização)
/// conta como hoje, nunca como "há -1 dias".
int calendarDaysSince(DateTime then, DateTime now) {
  // Em UTC, só com a data: a mudança de horário de verão não tira um dia.
  final from = DateTime.utc(then.year, then.month, then.day);
  final to = DateTime.utc(now.year, now.month, now.day);
  return math.max(0, to.difference(from).inDays);
}
