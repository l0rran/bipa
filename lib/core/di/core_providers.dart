import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio usado pelas regras de negócio. Sobrescreva em testes.
final clockProvider = Provider<Clock>((ref) => systemClock);

/// Gerador de IDs usado na criação de registros. Sobrescreva em testes.
final idGeneratorProvider = Provider<IdGenerator>((ref) => const UuidGenerator());
