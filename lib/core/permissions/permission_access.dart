/// Se o app pode usar um recurso do aparelho que pede permissão.
enum PermissionAccess {
  /// Permitido.
  granted,

  /// Ainda não permitido, mas o sistema ainda pergunta: vale explicar o
  /// motivo antes de pedir.
  askable,

  /// Negado de vez: o sistema não pergunta mais, só as configurações liberam.
  blocked,
}
