import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sonolyth/collections/assets.gen.dart';

class UniversalImage extends HookWidget {
  final String path;
  final double? height;
  final double? width;
  final double scale;
  final String? placeholder;
  final BoxFit? fit;

  /// What a screen reader should call this image.
  ///
  /// Null — the default — means the image is decorative and is dropped from
  /// the semantics tree entirely. That is the right answer nearly everywhere
  /// here: cover art in this app always sits beside the title it belongs to,
  /// so announcing it a second time as an image only adds a stop to swipe
  /// through. (Rows and cards paint their art as a `DecorationImage`, which
  /// emits no semantics at all — this keeps the widget consistent with them.)
  /// Pass a label where the image really is the only thing carrying meaning.
  final String? semanticLabel;

  const UniversalImage({
    required this.path,
    this.height,
    this.width,
    this.placeholder,
    this.fit,
    this.scale = 1,
    this.semanticLabel,
    super.key,
  });

  static ImageProvider imageProvider(
    String path, {
    final double? height,
    final double? width,
    final double scale = 1,
  }) {
    if (path.startsWith("http")) {
      return CachedNetworkImageProvider(
        path,
        maxHeight: height?.toInt(),
        maxWidth: width?.toInt(),
        cacheKey: path,
        scale: scale,
      );
    } else if (path.startsWith("assets/")) {
      return AssetImage(path);
    } else if (Uri.tryParse(path) != null) {
      return FileImage(File(path), scale: scale);
    }
    return MemoryImage(base64Decode(path), scale: scale);
  }

  @override
  Widget build(BuildContext context) {
    final image = _buildImage(context);
    if (semanticLabel == null) return ExcludeSemantics(child: image);
    return Semantics(image: true, label: semanticLabel, child: image);
  }

  Widget _buildImage(BuildContext context) {
    if (path.startsWith("http")) {
      return FadeInImage(
        image: CachedNetworkImageProvider(
          path,
          maxHeight: height?.toInt(),
          maxWidth: width?.toInt(),
          cacheKey: path,
          scale: scale,
        ),
        height: height,
        width: width,
        placeholder: AssetImage(placeholder ?? Assets.images.placeholder.path),
        imageErrorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
        fit: fit,
      );
    } else if (Uri.tryParse(path) != null && !path.startsWith("assets")) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    } else if (path.startsWith("assets")) {
      return Image.asset(
        path,
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    }

    return Image.memory(
      base64Decode(path),
      width: width,
      height: height,
      cacheHeight: height?.toInt(),
      cacheWidth: width?.toInt(),
      scale: scale,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          placeholder ?? Assets.images.placeholder.path,
          width: width,
          height: height,
          cacheHeight: height?.toInt(),
          cacheWidth: width?.toInt(),
          scale: scale,
        );
      },
    );
  }
}
