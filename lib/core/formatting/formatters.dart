import 'package:intl/intl.dart';

/// Formatação de valores para exibição em pt-BR.
abstract final class Formatters {
  static final _date = DateFormat('dd/MM/yyyy');
  static final _quantity = NumberFormat('#,##0.##', 'pt_BR');
  static final _kilometers = NumberFormat('#,##0.0', 'pt_BR');

  /// Ex.: `27/10/2026`.
  static String date(DateTime value) => _date.format(value);

  /// Quantidade sem casas decimais desnecessárias, ex.: `2` ou `1,5`.
  static String quantity(double value) => _quantity.format(value);

  /// Distância amigável, ex.: `120 m` ou `1,5 km`.
  static String distance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${_kilometers.format(meters / 1000)} km';
}
