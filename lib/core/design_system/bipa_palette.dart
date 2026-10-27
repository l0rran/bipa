// GERADO por tool/generate_tokens.dart a partir de design/tokens.json.
// Não edite à mão: mude o tokens.json e rode `dart run tool/generate_tokens.dart`.
import 'package:flutter/material.dart';

/// Cores do Bipa com nomes de função (ADR 0009). Leia sempre pelo tema:
/// `context.colors.brand`. Os valores ficam só em [BipaPalette].
@immutable
final class BipaColors extends ThemeExtension<BipaColors> {
  const BipaColors({
    required this.ground,
    required this.surface,
    required this.surfaceSunken,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.brand,
    required this.onBrand,
    required this.brandText,
    required this.brandSoft,
    required this.price,
    required this.onPrice,
    required this.alert,
    required this.onAlert,
    required this.alertText,
    required this.alertSoft,
    required this.place,
    required this.onPlace,
    required this.placeSoft,
    required this.positiveText,
    required this.positiveSoft,
    required this.surfaceGlass,
    required this.scrim,
    required this.camera,
    required this.onCamera,
  });

  /// Fundo das telas. Cinza quente quase branco, neutro para o amarelo e o preço se destacarem.
  final Color ground;

  /// Cartões, folhas inferiores (bottom sheets) e barra de navegação.
  final Color surface;

  /// Campos, miniaturas, chips não selecionados, stepper e trilhos.
  final Color surfaceSunken;

  /// Divisórias e contornos. Também o anel do medidor quando o item está em dia.
  final Color line;

  /// Texto principal, ícones e botões neutros. É a cor das ações comuns.
  final Color ink;

  /// Texto secundário. Passa 4.5:1 sobre ground e surface nos dois temas.
  final Color inkMuted;

  /// Amarelo Bipa, o mesmo da etiqueta: o preço é a marca. Botão de bipar, botão principal, barra da compra e aba ativa. Sempre com on-brand por cima.
  final Color brand;

  /// Texto e ícones sobre brand. Escuro nos dois temas.
  final Color onBrand;

  /// A cor da marca para texto e ícones sobre ground/surface, quando for preciso (o amarelo puro não tem contraste no claro).
  final Color brandText;

  /// Fundo da aba ativa e de destaques leves da marca.
  final Color brandSoft;

  /// A etiqueta de preço. Igual à marca, de propósito.
  final Color price;

  /// Texto sobre a etiqueta.
  final Color onPrice;

  /// Coral de alerta: o que está abaixo do "ter sempre" (arco do medidor, selo de Acabando). Única cor de alerta.
  final Color alert;

  /// Texto sobre alert. Escuro, porque o branco sobre o coral não passa 4.5:1.
  final Color onAlert;

  /// Coral para texto e números pequenos: quantidade baixa, erros de formulário.
  final Color alertText;

  /// Fundo de selos e avisos de alerta.
  final Color alertSoft;

  /// Cor de lugar, só na tela de mercados (mapa, distância).
  final Color place;

  /// Texto sobre place.
  final Color onPlace;

  /// Fundo de destaques de lugar.
  final Color placeSoft;

  /// Verde de economia e confirmação: quanto você economizou, variação positiva.
  final Color positiveText;

  /// Fundo de selos de economia.
  final Color positiveSoft;

  /// Camadas translúcidas sobre conteúdo: barra de navegação e controles sobre a câmera. Sempre com desfoque de fundo.
  final Color surfaceGlass;

  /// Véu atrás de menus e folhas modais.
  final Color scrim;

  /// Fundo das telas de câmera, igual nos dois temas.
  final Color camera;

  /// Texto e ícones sobre a câmera.
  final Color onCamera;

  @override
  BipaColors copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceSunken,
    Color? line,
    Color? ink,
    Color? inkMuted,
    Color? brand,
    Color? onBrand,
    Color? brandText,
    Color? brandSoft,
    Color? price,
    Color? onPrice,
    Color? alert,
    Color? onAlert,
    Color? alertText,
    Color? alertSoft,
    Color? place,
    Color? onPlace,
    Color? placeSoft,
    Color? positiveText,
    Color? positiveSoft,
    Color? surfaceGlass,
    Color? scrim,
    Color? camera,
    Color? onCamera,
  }) {
    return BipaColors(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandText: brandText ?? this.brandText,
      brandSoft: brandSoft ?? this.brandSoft,
      price: price ?? this.price,
      onPrice: onPrice ?? this.onPrice,
      alert: alert ?? this.alert,
      onAlert: onAlert ?? this.onAlert,
      alertText: alertText ?? this.alertText,
      alertSoft: alertSoft ?? this.alertSoft,
      place: place ?? this.place,
      onPlace: onPlace ?? this.onPlace,
      placeSoft: placeSoft ?? this.placeSoft,
      positiveText: positiveText ?? this.positiveText,
      positiveSoft: positiveSoft ?? this.positiveSoft,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      scrim: scrim ?? this.scrim,
      camera: camera ?? this.camera,
      onCamera: onCamera ?? this.onCamera,
    );
  }

  @override
  BipaColors lerp(BipaColors? other, double t) {
    if (other == null) return this;
    return BipaColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      price: Color.lerp(price, other.price, t)!,
      onPrice: Color.lerp(onPrice, other.onPrice, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      onAlert: Color.lerp(onAlert, other.onAlert, t)!,
      alertText: Color.lerp(alertText, other.alertText, t)!,
      alertSoft: Color.lerp(alertSoft, other.alertSoft, t)!,
      place: Color.lerp(place, other.place, t)!,
      onPlace: Color.lerp(onPlace, other.onPlace, t)!,
      placeSoft: Color.lerp(placeSoft, other.placeSoft, t)!,
      positiveText: Color.lerp(positiveText, other.positiveText, t)!,
      positiveSoft: Color.lerp(positiveSoft, other.positiveSoft, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      camera: Color.lerp(camera, other.camera, t)!,
      onCamera: Color.lerp(onCamera, other.onCamera, t)!,
    );
  }
}

/// Os valores da paleta, um por tema. É o único lugar do app com cores escritas.
abstract final class BipaPalette {
  static const light = BipaColors(
    ground: Color(0xFFF5F5F3),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDEDEA),
    line: Color(0xFFDCDCD7),
    ink: Color(0xFF1C1B1F),
    inkMuted: Color(0xFF5F5E66),
    brand: Color(0xFFF6C445),
    onBrand: Color(0xFF1C1B1F),
    brandText: Color(0xFF7A5800),
    brandSoft: Color(0xFFFDF1CF),
    price: Color(0xFFF6C445),
    onPrice: Color(0xFF1C1B1F),
    alert: Color(0xFFE8573A),
    onAlert: Color(0xFF1C1B1F),
    alertText: Color(0xFFB8402A),
    alertSoft: Color(0xFFFCE4DD),
    place: Color(0xFF34507A),
    onPlace: Color(0xFFFFFFFF),
    placeSoft: Color(0xFFE6ECF5),
    positiveText: Color(0xFF1A7A4A),
    positiveSoft: Color(0xFFDFF3E8),
    surfaceGlass: Color(0xC7FFFFFF),
    scrim: Color(0x6B1C1B22),
    camera: Color(0xFF0E0E12),
    onCamera: Color(0xFFF3F2F6),
  );

  static const dark = BipaColors(
    ground: Color(0xFF0D0E11),
    surface: Color(0xFF17191D),
    surfaceSunken: Color(0xFF22252B),
    line: Color(0xFF2D3138),
    ink: Color(0xFFF3F3F5),
    inkMuted: Color(0xFF9EA2AA),
    brand: Color(0xFFF6C445),
    onBrand: Color(0xFF1C1B1F),
    brandText: Color(0xFFF6C445),
    brandSoft: Color(0xFF3A3015),
    price: Color(0xFFF6C445),
    onPrice: Color(0xFF1C1B1F),
    alert: Color(0xFFFF7B66),
    onAlert: Color(0xFF1C1B1F),
    alertText: Color(0xFFFF8F7D),
    alertSoft: Color(0xFF3D1E19),
    place: Color(0xFF8FA9D6),
    onPlace: Color(0xFF131317),
    placeSoft: Color(0xFF232C3D),
    positiveText: Color(0xFF5FD69A),
    positiveSoft: Color(0xFF17301F),
    surfaceGlass: Color(0xC717191D),
    scrim: Color(0x99000000),
    camera: Color(0xFF0E0E12),
    onCamera: Color(0xFFF3F2F6),
  );
}
