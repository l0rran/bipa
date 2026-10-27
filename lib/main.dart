import 'package:bipa/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  _registerFontLicenses();
  runApp(const ProviderScope(child: BipaApp()));
}

/// As fontes embutidas usam a SIL Open Font License, que pede que a licença
/// acompanhe o app. Ela aparece na tela de licenças do Flutter.
void _registerFontLicenses() {
  const fonts = {'Manrope': 'OFL-Manrope', 'Figtree': 'OFL-Figtree', 'JetBrains Mono': 'OFL-JetBrainsMono'};
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in fonts.entries) {
      final text = await rootBundle.loadString('assets/fonts/$file.txt');
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
}
