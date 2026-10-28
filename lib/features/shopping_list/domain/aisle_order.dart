import 'package:bipa/core/catalog/product_kind.dart';
import 'package:meta/meta.dart';

/// Onde uma seção fica no percurso de um mercado, de 0 (entrada) a 1
/// (fundo), e em quantas compras isso foi visto (ADR 0014).
@immutable
final class LearnedAisle {
  const LearnedAisle({required this.position, required this.samples});

  final double position;
  final int samples;

  @override
  bool operator ==(Object other) =>
      other is LearnedAisle && other.position == position && other.samples == samples;

  @override
  int get hashCode => Object.hash(position, samples);

  @override
  String toString() => 'LearnedAisle($position, $samples)';
}

/// Uma seção pegando um item numa compra: o item marcado na lista ou bipado
/// no carrinho, e quando.
typedef AislePick = ({Aisle aisle, DateTime at});

/// A ordem das seções num mercado, aprendida com as compras (ADR 0014).
///
/// Começa na ordem genérica de [Aisle]. A cada compra, as seções visitadas
/// trocam de lugar entre si, na ordem em que foram percorridas; as outras
/// ficam onde estavam. "Outros" não ensina nada: pode estar em qualquer
/// lugar.
@immutable
final class AisleOrder {
  const AisleOrder([this.learned = const {}]);

  static const empty = AisleOrder();

  /// Na primeira vez, a seção vai direto para o lugar visto; depois, anda
  /// metade do caminho, para uma compra fora do comum não bagunçar tudo.
  static const _learningRate = 0.5;

  final Map<Aisle, LearnedAisle> learned;

  /// O lugar da seção no percurso: o aprendido ou o da ordem genérica.
  double positionOf(Aisle aisle) => learned[aisle]?.position ?? defaultPosition(aisle);

  /// O lugar na ordem genérica, espalhado de 0 a 1.
  static double defaultPosition(Aisle aisle) => aisle.index / (Aisle.values.length - 1);

  /// As seções na ordem do percurso; "Outros" sempre no fim.
  List<Aisle> sort(Iterable<Aisle> aisles) => aisles.toList()
    ..sort((a, b) {
      if ((a == Aisle.other) != (b == Aisle.other)) return a == Aisle.other ? 1 : -1;
      final byPosition = positionOf(a).compareTo(positionOf(b));
      return byPosition != 0 ? byPosition : a.index.compareTo(b.index);
    });

  /// Aprende com uma compra: cada seção visitada entra no percurso pelo
  /// horário mediano dos seus itens, o que ignora uma volta para buscar algo
  /// esquecido. Com menos de duas seções, não há ordem para aprender.
  AisleOrder learn(Iterable<AislePick> picks) {
    final times = <Aisle, List<DateTime>>{};
    for (final pick in picks) {
      if (pick.aisle != Aisle.other) times.putIfAbsent(pick.aisle, () => []).add(pick.at);
    }
    if (times.length < 2) return this;

    final medians = {for (final MapEntry(key: aisle, value: at) in times.entries) aisle: _median(at)};
    final walked = medians.keys.toList()
      ..sort((a, b) {
        final byTime = medians[a]!.compareTo(medians[b]!);
        return byTime != 0 ? byTime : positionOf(a).compareTo(positionOf(b));
      });
    // Os lugares que essas seções ocupam hoje, redistribuídos na ordem vista.
    final slots = [for (final aisle in walked) positionOf(aisle)]..sort();

    final next = Map.of(learned);
    for (final (index, aisle) in walked.indexed) {
      final current = learned[aisle];
      final seen = slots[index];
      next[aisle] = current == null
          ? LearnedAisle(position: seen, samples: 1)
          : LearnedAisle(
              position: current.position + (seen - current.position) * _learningRate,
              samples: current.samples + 1,
            );
    }
    return AisleOrder(next);
  }

  static DateTime _median(List<DateTime> times) {
    final sorted = [...times]..sort();
    return sorted[(sorted.length - 1) ~/ 2];
  }

  @override
  bool operator ==(Object other) {
    if (other is! AisleOrder || other.learned.length != learned.length) return false;
    for (final MapEntry(key: aisle, value: value) in learned.entries) {
      if (other.learned[aisle] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(learned.entries.map((e) => Object.hash(e.key, e.value)));
}

/// Acesso à ordem aprendida de cada mercado. Privada, como a lista: o
/// percurso é de quem compra (ADR 0007).
abstract interface class AisleOrderRepository {
  Stream<AisleOrder> watch(String marketId);

  Future<AisleOrder> find(String marketId);

  /// Troca a ordem aprendida do mercado por [order].
  Future<void> save(String marketId, AisleOrder order);
}
