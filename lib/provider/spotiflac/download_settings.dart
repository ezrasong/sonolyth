import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/services/spotiflac/providers/deezer_provider.dart';
import 'package:sonolyth/services/spotiflac/providers/qobuz_provider.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';

/// All download providers Sonolyth ships natively, in default priority order.
final allSpotiFlacProviders = <SpotiFlacProvider>[
  QobuzProvider(),
  DeezerProvider(),
];

const _prefsKey = "spotiflac-download-settings";

class SpotiFlacDownloadSettings {
  /// Provider ids in user-chosen priority order (best first).
  final List<String> order;

  /// Provider ids the user has disabled.
  final Set<String> disabled;

  /// Selected quality id per provider.
  final Map<String, String> qualityByProvider;

  const SpotiFlacDownloadSettings({
    required this.order,
    required this.disabled,
    required this.qualityByProvider,
  });

  factory SpotiFlacDownloadSettings.defaults() => SpotiFlacDownloadSettings(
        order: allSpotiFlacProviders.map((p) => p.id).toList(),
        disabled: const {},
        qualityByProvider: {
          for (final provider in allSpotiFlacProviders)
            provider.id: provider.defaultQuality,
        },
      );

  /// Enabled providers, resolved to instances, in priority order.
  List<SpotiFlacProvider> get enabledProviders {
    final byId = {for (final p in allSpotiFlacProviders) p.id: p};
    return [
      for (final id in order)
        if (!disabled.contains(id) && byId.containsKey(id)) byId[id]!,
    ];
  }

  SpotiFlacDownloadSettings copyWith({
    List<String>? order,
    Set<String>? disabled,
    Map<String, String>? qualityByProvider,
  }) {
    return SpotiFlacDownloadSettings(
      order: order ?? this.order,
      disabled: disabled ?? this.disabled,
      qualityByProvider: qualityByProvider ?? this.qualityByProvider,
    );
  }

  Map<String, dynamic> toJson() => {
        "order": order,
        "disabled": disabled.toList(),
        "qualityByProvider": qualityByProvider,
      };

  factory SpotiFlacDownloadSettings.fromJson(Map<String, dynamic> json) {
    final defaults = SpotiFlacDownloadSettings.defaults();
    final knownIds = allSpotiFlacProviders.map((p) => p.id).toSet();

    final storedOrder =
        (json["order"] as List?)?.map((e) => e.toString()).toList() ?? [];
    // Keep stored ordering, then append any providers added since.
    final order = [
      ...storedOrder.where(knownIds.contains),
      ...defaults.order.where((id) => !storedOrder.contains(id)),
    ];

    return SpotiFlacDownloadSettings(
      order: order,
      disabled: (json["disabled"] as List?)
              ?.map((e) => e.toString())
              .where(knownIds.contains)
              .toSet() ??
          {},
      qualityByProvider: {
        ...defaults.qualityByProvider,
        ...?(json["qualityByProvider"] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      },
    );
  }
}

class SpotiFlacDownloadSettingsNotifier
    extends AsyncNotifier<SpotiFlacDownloadSettings> {
  @override
  Future<SpotiFlacDownloadSettings> build() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_prefsKey);
    if (stored == null) return SpotiFlacDownloadSettings.defaults();
    try {
      return SpotiFlacDownloadSettings.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } catch (_) {
      return SpotiFlacDownloadSettings.defaults();
    }
  }

  Future<void> _persist(SpotiFlacDownloadSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_prefsKey, jsonEncode(settings.toJson()));
    state = AsyncData(settings);
  }

  Future<void> setEnabled(String providerId, bool enabled) async {
    final current = state.value ?? SpotiFlacDownloadSettings.defaults();
    final disabled = {...current.disabled};
    if (enabled) {
      disabled.remove(providerId);
    } else {
      disabled.add(providerId);
    }
    await _persist(current.copyWith(disabled: disabled));
  }

  Future<void> setQuality(String providerId, String quality) async {
    final current = state.value ?? SpotiFlacDownloadSettings.defaults();
    await _persist(current.copyWith(
      qualityByProvider: {...current.qualityByProvider, providerId: quality},
    ));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value ?? SpotiFlacDownloadSettings.defaults();
    final order = [...current.order];
    if (oldIndex < 0 || oldIndex >= order.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, order.length - 1);
    final moved = order.removeAt(oldIndex);
    order.insert(target, moved);
    await _persist(current.copyWith(order: order));
  }
}

final spotiFlacDownloadSettingsProvider = AsyncNotifierProvider<
    SpotiFlacDownloadSettingsNotifier, SpotiFlacDownloadSettings>(
  SpotiFlacDownloadSettingsNotifier.new,
);
