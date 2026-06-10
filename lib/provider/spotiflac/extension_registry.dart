import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/services/dio/dio.dart';

const defaultSpotiFlacExtensionRegistryUrl =
    "https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/registry.json";

const _spotiFlacRegistryPrefsKey = "spotiflac-extension-registries";

class SpotiFlacExtension {
  final String id;
  final String name;
  final String version;
  final String description;
  final String downloadUrl;
  final String category;
  final List<String> tags;
  final String registryUrl;

  const SpotiFlacExtension({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.downloadUrl,
    required this.category,
    required this.tags,
    required this.registryUrl,
  });

  bool get isDownloadProvider =>
      category == "download" || tags.contains("download");

  factory SpotiFlacExtension.fromJson(
    Map<String, dynamic> json,
    String registryUrl,
  ) {
    return SpotiFlacExtension(
      id: json["id"]?.toString() ?? json["name"]?.toString() ?? "",
      name: json["display_name"]?.toString() ??
          json["name"]?.toString() ??
          "SpotiFLAC Extension",
      version: json["version"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      downloadUrl: json["download_url"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "",
      tags: (json["tags"] as List? ?? []).map((tag) => "$tag").toList(),
      registryUrl: registryUrl,
    );
  }
}

class SpotiFlacExtensionRegistryState {
  final List<String> registries;
  final List<SpotiFlacExtension> extensions;

  const SpotiFlacExtensionRegistryState({
    required this.registries,
    required this.extensions,
  });
}

class SpotiFlacExtensionRegistryNotifier
    extends AsyncNotifier<SpotiFlacExtensionRegistryState> {
  Future<List<String>> _loadRegistries() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_spotiFlacRegistryPrefsKey) ?? [];
    return [
      defaultSpotiFlacExtensionRegistryUrl,
      ...stored.where((url) => url != defaultSpotiFlacExtensionRegistryUrl),
    ];
  }

  Future<void> _saveRegistries(List<String> registries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _spotiFlacRegistryPrefsKey,
      registries
          .where((url) => url != defaultSpotiFlacExtensionRegistryUrl)
          .toList(),
    );
  }

  Future<List<SpotiFlacExtension>> _fetchRegistry(String registryUrl) async {
    final response = await globalDio.get(registryUrl);
    final payload = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    final extensions = payload["extensions"] as List? ?? [];
    return extensions
        .map((extension) => SpotiFlacExtension.fromJson(
              Map<String, dynamic>.from(extension as Map),
              registryUrl,
            ))
        .where((extension) => extension.downloadUrl.isNotEmpty)
        .toList();
  }

  Future<SpotiFlacExtensionRegistryState> _fetchAll(
    List<String> registries,
  ) async {
    final extensionLists = await Future.wait(
      registries.map((registry) async {
        try {
          return await _fetchRegistry(registry);
        } catch (_) {
          return <SpotiFlacExtension>[];
        }
      }),
    );

    return SpotiFlacExtensionRegistryState(
      registries: registries,
      extensions: extensionLists.expand((extensions) => extensions).toList(),
    );
  }

  @override
  Future<SpotiFlacExtensionRegistryState> build() async {
    return _fetchAll(await _loadRegistries());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() async => _fetchAll(await _loadRegistries()));
  }

  Future<void> addRegistry(String registryUrl) async {
    final normalized = registryUrl.trim();
    if (normalized.isEmpty) return;

    final current = await _loadRegistries();
    if (current.contains(normalized)) return;

    final next = [...current, normalized];
    await _saveRegistries(next);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetchAll(next));
  }

  Future<void> removeRegistry(String registryUrl) async {
    if (registryUrl == defaultSpotiFlacExtensionRegistryUrl) return;

    final next =
        (await _loadRegistries()).where((url) => url != registryUrl).toList();
    await _saveRegistries(next);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _fetchAll(next));
  }
}

final spotiFlacExtensionRegistryProvider = AsyncNotifierProvider<
    SpotiFlacExtensionRegistryNotifier, SpotiFlacExtensionRegistryState>(
  SpotiFlacExtensionRegistryNotifier.new,
);
