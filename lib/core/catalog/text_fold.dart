/// Texto para comparar nomes: minúsculo e sem acento ("Café" vira "cafe").
/// Etiquetas e cadastros escrevem o mesmo produto de jeitos diferentes.
String foldText(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}
