import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/location/location_failure_label.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/widgets/messages.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cadastro e edição de mercado. Ao salvar, devolve o [Market] via `pop`.
class MarketFormPage extends ConsumerStatefulWidget {
  const MarketFormPage({this.marketId, this.here = false, super.key});

  /// Quando informado, edita o mercado existente.
  final String? marketId;

  /// A pessoa está no mercado agora (cadastro feito na escolha do mercado da
  /// compra): a localização atual entra sozinha. De casa, ela gravaria o
  /// endereço errado.
  final bool here;

  @override
  ConsumerState<MarketFormPage> createState() => _MarketFormPageState();
}

class _MarketFormPageState extends ConsumerState<MarketFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  GeoPoint? _location;
  Market? _original;
  var _loading = false;
  var _locating = false;
  var _saving = false;

  bool get _isEditing => widget.marketId != null;

  @override
  void initState() {
    super.initState();
    final marketId = widget.marketId;
    if (marketId != null) {
      _loading = true;
      _load(marketId);
    } else if (widget.here) {
      _useCurrentLocation();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final market = await ref.read(marketRepositoryProvider).findById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (market == null) return;
      _original = market;
      _name.text = market.name;
      _address.text = market.address ?? '';
      _location = market.location;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result is LocationFound) _location = result.point;
    });
    if (result case LocationUnavailable(:final failure)) {
      context.showMessage(failure.localizedLabel(AppLocalizations.of(context)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final now = ref.read(clockProvider)();
    final original = _original;
    final address = _address.text.trim();
    final market = Market(
      id: original?.id ?? ref.read(idGeneratorProvider).newId(),
      name: _name.text.trim(),
      address: address.isEmpty ? null : address,
      location: _location,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(marketRepositoryProvider).save(market);
      if (mounted) context.pop(market);
    } on Exception {
      if (mounted) context.showMessage(AppLocalizations.of(context).marketSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.marketEdit : l10n.marketsNew)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l10n.formNameRequired),
                    validator: (value) => (value == null || value.trim().isEmpty) ? l10n.marketNameMissing : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _address,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l10n.marketAddress, helperText: l10n.formOptional),
                  ),
                  const SizedBox(height: 24),
                  _LocationCard(
                    location: _location,
                    locating: _locating,
                    onUseCurrent: _useCurrentLocation,
                    onClear: () => setState(() => _location = null),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.save),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.locating,
    required this.onUseCurrent,
    required this.onClear,
  });

  final GeoPoint? location;
  final bool locating;
  final VoidCallback onUseCurrent;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final point = location;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.marketLocation, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              point == null
                  ? l10n.marketLocationMissing
                  : l10n.marketLocationSaved,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: locating ? null : onUseCurrent,
                  icon: locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(l10n.marketUseLocation),
                ),
                if (point != null)
                  TextButton(onPressed: onClear, child: Text(l10n.marketRemoveLocation)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
