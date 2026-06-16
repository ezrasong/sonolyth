// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SonolythAudioSourceContainerPreset _$SonolythAudioSourceContainerPresetFromJson(
    Map<String, dynamic> json) {
  switch (json['type']) {
    case 'lossy':
      return SonolythAudioSourceContainerPresetLossy.fromJson(json);
    case 'lossless':
      return SonolythAudioSourceContainerPresetLossless.fromJson(json);

    default:
      throw CheckedFromJsonException(
          json,
          'type',
          'SonolythAudioSourceContainerPreset',
          'Invalid union type "${json['type']}"!');
  }
}

/// @nodoc
mixin _$SonolythAudioSourceContainerPreset {
  SonolythMediaCompressionType get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<Object> get qualities => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)
        lossy,
    required TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)?
        lossy,
    TResult? Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)?
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)?
        lossy,
    TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)?
        lossless,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SonolythAudioSourceContainerPresetLossy value)
        lossy,
    required TResult Function(SonolythAudioSourceContainerPresetLossless value)
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SonolythAudioSourceContainerPresetLossy value)? lossy,
    TResult? Function(SonolythAudioSourceContainerPresetLossless value)?
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SonolythAudioSourceContainerPresetLossy value)? lossy,
    TResult Function(SonolythAudioSourceContainerPresetLossless value)?
        lossless,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this SonolythAudioSourceContainerPreset to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythAudioSourceContainerPresetCopyWith<
          SonolythAudioSourceContainerPreset>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythAudioSourceContainerPresetCopyWith<$Res> {
  factory $SonolythAudioSourceContainerPresetCopyWith(
          SonolythAudioSourceContainerPreset value,
          $Res Function(SonolythAudioSourceContainerPreset) then) =
      _$SonolythAudioSourceContainerPresetCopyWithImpl<$Res,
          SonolythAudioSourceContainerPreset>;
  @useResult
  $Res call({SonolythMediaCompressionType type, String name});
}

/// @nodoc
class _$SonolythAudioSourceContainerPresetCopyWithImpl<$Res,
        $Val extends SonolythAudioSourceContainerPreset>
    implements $SonolythAudioSourceContainerPresetCopyWith<$Res> {
  _$SonolythAudioSourceContainerPresetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? name = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SonolythMediaCompressionType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythAudioSourceContainerPresetLossyImplCopyWith<$Res>
    implements $SonolythAudioSourceContainerPresetCopyWith<$Res> {
  factory _$$SonolythAudioSourceContainerPresetLossyImplCopyWith(
          _$SonolythAudioSourceContainerPresetLossyImpl value,
          $Res Function(_$SonolythAudioSourceContainerPresetLossyImpl) then) =
      __$$SonolythAudioSourceContainerPresetLossyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SonolythMediaCompressionType type,
      String name,
      List<SonolythAudioLossyContainerQuality> qualities});
}

/// @nodoc
class __$$SonolythAudioSourceContainerPresetLossyImplCopyWithImpl<$Res>
    extends _$SonolythAudioSourceContainerPresetCopyWithImpl<$Res,
        _$SonolythAudioSourceContainerPresetLossyImpl>
    implements _$$SonolythAudioSourceContainerPresetLossyImplCopyWith<$Res> {
  __$$SonolythAudioSourceContainerPresetLossyImplCopyWithImpl(
      _$SonolythAudioSourceContainerPresetLossyImpl _value,
      $Res Function(_$SonolythAudioSourceContainerPresetLossyImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? name = null,
    Object? qualities = null,
  }) {
    return _then(_$SonolythAudioSourceContainerPresetLossyImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SonolythMediaCompressionType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      qualities: null == qualities
          ? _value._qualities
          : qualities // ignore: cast_nullable_to_non_nullable
              as List<SonolythAudioLossyContainerQuality>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythAudioSourceContainerPresetLossyImpl
    extends SonolythAudioSourceContainerPresetLossy {
  _$SonolythAudioSourceContainerPresetLossyImpl(
      {required this.type,
      required this.name,
      required final List<SonolythAudioLossyContainerQuality> qualities})
      : _qualities = qualities,
        super._();

  factory _$SonolythAudioSourceContainerPresetLossyImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythAudioSourceContainerPresetLossyImplFromJson(json);

  @override
  final SonolythMediaCompressionType type;
  @override
  final String name;
  final List<SonolythAudioLossyContainerQuality> _qualities;
  @override
  List<SonolythAudioLossyContainerQuality> get qualities {
    if (_qualities is EqualUnmodifiableListView) return _qualities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_qualities);
  }

  @override
  String toString() {
    return 'SonolythAudioSourceContainerPreset.lossy(type: $type, name: $name, qualities: $qualities)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythAudioSourceContainerPresetLossyImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._qualities, _qualities));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, name, const DeepCollectionEquality().hash(_qualities));

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythAudioSourceContainerPresetLossyImplCopyWith<
          _$SonolythAudioSourceContainerPresetLossyImpl>
      get copyWith =>
          __$$SonolythAudioSourceContainerPresetLossyImplCopyWithImpl<
              _$SonolythAudioSourceContainerPresetLossyImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)
        lossy,
    required TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)
        lossless,
  }) {
    return lossy(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)?
        lossy,
    TResult? Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)?
        lossless,
  }) {
    return lossy?.call(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)?
        lossy,
    TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)?
        lossless,
    required TResult orElse(),
  }) {
    if (lossy != null) {
      return lossy(type, name, qualities);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SonolythAudioSourceContainerPresetLossy value)
        lossy,
    required TResult Function(SonolythAudioSourceContainerPresetLossless value)
        lossless,
  }) {
    return lossy(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SonolythAudioSourceContainerPresetLossy value)? lossy,
    TResult? Function(SonolythAudioSourceContainerPresetLossless value)?
        lossless,
  }) {
    return lossy?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SonolythAudioSourceContainerPresetLossy value)? lossy,
    TResult Function(SonolythAudioSourceContainerPresetLossless value)?
        lossless,
    required TResult orElse(),
  }) {
    if (lossy != null) {
      return lossy(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythAudioSourceContainerPresetLossyImplToJson(
      this,
    );
  }
}

abstract class SonolythAudioSourceContainerPresetLossy
    extends SonolythAudioSourceContainerPreset {
  factory SonolythAudioSourceContainerPresetLossy(
          {required final SonolythMediaCompressionType type,
          required final String name,
          required final List<SonolythAudioLossyContainerQuality> qualities}) =
      _$SonolythAudioSourceContainerPresetLossyImpl;
  SonolythAudioSourceContainerPresetLossy._() : super._();

  factory SonolythAudioSourceContainerPresetLossy.fromJson(
          Map<String, dynamic> json) =
      _$SonolythAudioSourceContainerPresetLossyImpl.fromJson;

  @override
  SonolythMediaCompressionType get type;
  @override
  String get name;
  @override
  List<SonolythAudioLossyContainerQuality> get qualities;

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythAudioSourceContainerPresetLossyImplCopyWith<
          _$SonolythAudioSourceContainerPresetLossyImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SonolythAudioSourceContainerPresetLosslessImplCopyWith<$Res>
    implements $SonolythAudioSourceContainerPresetCopyWith<$Res> {
  factory _$$SonolythAudioSourceContainerPresetLosslessImplCopyWith(
          _$SonolythAudioSourceContainerPresetLosslessImpl value,
          $Res Function(_$SonolythAudioSourceContainerPresetLosslessImpl)
              then) =
      __$$SonolythAudioSourceContainerPresetLosslessImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SonolythMediaCompressionType type,
      String name,
      List<SonolythAudioLosslessContainerQuality> qualities});
}

/// @nodoc
class __$$SonolythAudioSourceContainerPresetLosslessImplCopyWithImpl<$Res>
    extends _$SonolythAudioSourceContainerPresetCopyWithImpl<$Res,
        _$SonolythAudioSourceContainerPresetLosslessImpl>
    implements _$$SonolythAudioSourceContainerPresetLosslessImplCopyWith<$Res> {
  __$$SonolythAudioSourceContainerPresetLosslessImplCopyWithImpl(
      _$SonolythAudioSourceContainerPresetLosslessImpl _value,
      $Res Function(_$SonolythAudioSourceContainerPresetLosslessImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? name = null,
    Object? qualities = null,
  }) {
    return _then(_$SonolythAudioSourceContainerPresetLosslessImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SonolythMediaCompressionType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      qualities: null == qualities
          ? _value._qualities
          : qualities // ignore: cast_nullable_to_non_nullable
              as List<SonolythAudioLosslessContainerQuality>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythAudioSourceContainerPresetLosslessImpl
    extends SonolythAudioSourceContainerPresetLossless {
  _$SonolythAudioSourceContainerPresetLosslessImpl(
      {required this.type,
      required this.name,
      required final List<SonolythAudioLosslessContainerQuality> qualities})
      : _qualities = qualities,
        super._();

  factory _$SonolythAudioSourceContainerPresetLosslessImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythAudioSourceContainerPresetLosslessImplFromJson(json);

  @override
  final SonolythMediaCompressionType type;
  @override
  final String name;
  final List<SonolythAudioLosslessContainerQuality> _qualities;
  @override
  List<SonolythAudioLosslessContainerQuality> get qualities {
    if (_qualities is EqualUnmodifiableListView) return _qualities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_qualities);
  }

  @override
  String toString() {
    return 'SonolythAudioSourceContainerPreset.lossless(type: $type, name: $name, qualities: $qualities)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythAudioSourceContainerPresetLosslessImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._qualities, _qualities));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, name, const DeepCollectionEquality().hash(_qualities));

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythAudioSourceContainerPresetLosslessImplCopyWith<
          _$SonolythAudioSourceContainerPresetLosslessImpl>
      get copyWith =>
          __$$SonolythAudioSourceContainerPresetLosslessImplCopyWithImpl<
                  _$SonolythAudioSourceContainerPresetLosslessImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)
        lossy,
    required TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)
        lossless,
  }) {
    return lossless(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)?
        lossy,
    TResult? Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)?
        lossless,
  }) {
    return lossless?.call(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLossyContainerQuality> qualities)?
        lossy,
    TResult Function(SonolythMediaCompressionType type, String name,
            List<SonolythAudioLosslessContainerQuality> qualities)?
        lossless,
    required TResult orElse(),
  }) {
    if (lossless != null) {
      return lossless(type, name, qualities);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SonolythAudioSourceContainerPresetLossy value)
        lossy,
    required TResult Function(SonolythAudioSourceContainerPresetLossless value)
        lossless,
  }) {
    return lossless(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SonolythAudioSourceContainerPresetLossy value)? lossy,
    TResult? Function(SonolythAudioSourceContainerPresetLossless value)?
        lossless,
  }) {
    return lossless?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SonolythAudioSourceContainerPresetLossy value)? lossy,
    TResult Function(SonolythAudioSourceContainerPresetLossless value)?
        lossless,
    required TResult orElse(),
  }) {
    if (lossless != null) {
      return lossless(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythAudioSourceContainerPresetLosslessImplToJson(
      this,
    );
  }
}

abstract class SonolythAudioSourceContainerPresetLossless
    extends SonolythAudioSourceContainerPreset {
  factory SonolythAudioSourceContainerPresetLossless(
      {required final SonolythMediaCompressionType type,
      required final String name,
      required final List<SonolythAudioLosslessContainerQuality>
          qualities}) = _$SonolythAudioSourceContainerPresetLosslessImpl;
  SonolythAudioSourceContainerPresetLossless._() : super._();

  factory SonolythAudioSourceContainerPresetLossless.fromJson(
          Map<String, dynamic> json) =
      _$SonolythAudioSourceContainerPresetLosslessImpl.fromJson;

  @override
  SonolythMediaCompressionType get type;
  @override
  String get name;
  @override
  List<SonolythAudioLosslessContainerQuality> get qualities;

  /// Create a copy of SonolythAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythAudioSourceContainerPresetLosslessImplCopyWith<
          _$SonolythAudioSourceContainerPresetLosslessImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythAudioLossyContainerQuality _$SonolythAudioLossyContainerQualityFromJson(
    Map<String, dynamic> json) {
  return _SonolythAudioLossyContainerQuality.fromJson(json);
}

/// @nodoc
mixin _$SonolythAudioLossyContainerQuality {
  int get bitrate => throw _privateConstructorUsedError;

  /// Serializes this SonolythAudioLossyContainerQuality to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythAudioLossyContainerQualityCopyWith<
          SonolythAudioLossyContainerQuality>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythAudioLossyContainerQualityCopyWith<$Res> {
  factory $SonolythAudioLossyContainerQualityCopyWith(
          SonolythAudioLossyContainerQuality value,
          $Res Function(SonolythAudioLossyContainerQuality) then) =
      _$SonolythAudioLossyContainerQualityCopyWithImpl<$Res,
          SonolythAudioLossyContainerQuality>;
  @useResult
  $Res call({int bitrate});
}

/// @nodoc
class _$SonolythAudioLossyContainerQualityCopyWithImpl<$Res,
        $Val extends SonolythAudioLossyContainerQuality>
    implements $SonolythAudioLossyContainerQualityCopyWith<$Res> {
  _$SonolythAudioLossyContainerQualityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitrate = null,
  }) {
    return _then(_value.copyWith(
      bitrate: null == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythAudioLossyContainerQualityImplCopyWith<$Res>
    implements $SonolythAudioLossyContainerQualityCopyWith<$Res> {
  factory _$$SonolythAudioLossyContainerQualityImplCopyWith(
          _$SonolythAudioLossyContainerQualityImpl value,
          $Res Function(_$SonolythAudioLossyContainerQualityImpl) then) =
      __$$SonolythAudioLossyContainerQualityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int bitrate});
}

/// @nodoc
class __$$SonolythAudioLossyContainerQualityImplCopyWithImpl<$Res>
    extends _$SonolythAudioLossyContainerQualityCopyWithImpl<$Res,
        _$SonolythAudioLossyContainerQualityImpl>
    implements _$$SonolythAudioLossyContainerQualityImplCopyWith<$Res> {
  __$$SonolythAudioLossyContainerQualityImplCopyWithImpl(
      _$SonolythAudioLossyContainerQualityImpl _value,
      $Res Function(_$SonolythAudioLossyContainerQualityImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitrate = null,
  }) {
    return _then(_$SonolythAudioLossyContainerQualityImpl(
      bitrate: null == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythAudioLossyContainerQualityImpl
    extends _SonolythAudioLossyContainerQuality {
  _$SonolythAudioLossyContainerQualityImpl({required this.bitrate}) : super._();

  factory _$SonolythAudioLossyContainerQualityImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythAudioLossyContainerQualityImplFromJson(json);

  @override
  final int bitrate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythAudioLossyContainerQualityImpl &&
            (identical(other.bitrate, bitrate) || other.bitrate == bitrate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, bitrate);

  /// Create a copy of SonolythAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythAudioLossyContainerQualityImplCopyWith<
          _$SonolythAudioLossyContainerQualityImpl>
      get copyWith => __$$SonolythAudioLossyContainerQualityImplCopyWithImpl<
          _$SonolythAudioLossyContainerQualityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythAudioLossyContainerQualityImplToJson(
      this,
    );
  }
}

abstract class _SonolythAudioLossyContainerQuality
    extends SonolythAudioLossyContainerQuality {
  factory _SonolythAudioLossyContainerQuality({required final int bitrate}) =
      _$SonolythAudioLossyContainerQualityImpl;
  _SonolythAudioLossyContainerQuality._() : super._();

  factory _SonolythAudioLossyContainerQuality.fromJson(
          Map<String, dynamic> json) =
      _$SonolythAudioLossyContainerQualityImpl.fromJson;

  @override
  int get bitrate;

  /// Create a copy of SonolythAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythAudioLossyContainerQualityImplCopyWith<
          _$SonolythAudioLossyContainerQualityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythAudioLosslessContainerQuality
    _$SonolythAudioLosslessContainerQualityFromJson(Map<String, dynamic> json) {
  return _SonolythAudioLosslessContainerQuality.fromJson(json);
}

/// @nodoc
mixin _$SonolythAudioLosslessContainerQuality {
  int get bitDepth => throw _privateConstructorUsedError; // bit
  int get sampleRate => throw _privateConstructorUsedError;

  /// Serializes this SonolythAudioLosslessContainerQuality to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythAudioLosslessContainerQualityCopyWith<
          SonolythAudioLosslessContainerQuality>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythAudioLosslessContainerQualityCopyWith<$Res> {
  factory $SonolythAudioLosslessContainerQualityCopyWith(
          SonolythAudioLosslessContainerQuality value,
          $Res Function(SonolythAudioLosslessContainerQuality) then) =
      _$SonolythAudioLosslessContainerQualityCopyWithImpl<$Res,
          SonolythAudioLosslessContainerQuality>;
  @useResult
  $Res call({int bitDepth, int sampleRate});
}

/// @nodoc
class _$SonolythAudioLosslessContainerQualityCopyWithImpl<$Res,
        $Val extends SonolythAudioLosslessContainerQuality>
    implements $SonolythAudioLosslessContainerQualityCopyWith<$Res> {
  _$SonolythAudioLosslessContainerQualityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitDepth = null,
    Object? sampleRate = null,
  }) {
    return _then(_value.copyWith(
      bitDepth: null == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int,
      sampleRate: null == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythAudioLosslessContainerQualityImplCopyWith<$Res>
    implements $SonolythAudioLosslessContainerQualityCopyWith<$Res> {
  factory _$$SonolythAudioLosslessContainerQualityImplCopyWith(
          _$SonolythAudioLosslessContainerQualityImpl value,
          $Res Function(_$SonolythAudioLosslessContainerQualityImpl) then) =
      __$$SonolythAudioLosslessContainerQualityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int bitDepth, int sampleRate});
}

/// @nodoc
class __$$SonolythAudioLosslessContainerQualityImplCopyWithImpl<$Res>
    extends _$SonolythAudioLosslessContainerQualityCopyWithImpl<$Res,
        _$SonolythAudioLosslessContainerQualityImpl>
    implements _$$SonolythAudioLosslessContainerQualityImplCopyWith<$Res> {
  __$$SonolythAudioLosslessContainerQualityImplCopyWithImpl(
      _$SonolythAudioLosslessContainerQualityImpl _value,
      $Res Function(_$SonolythAudioLosslessContainerQualityImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitDepth = null,
    Object? sampleRate = null,
  }) {
    return _then(_$SonolythAudioLosslessContainerQualityImpl(
      bitDepth: null == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int,
      sampleRate: null == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythAudioLosslessContainerQualityImpl
    extends _SonolythAudioLosslessContainerQuality {
  _$SonolythAudioLosslessContainerQualityImpl(
      {required this.bitDepth, required this.sampleRate})
      : super._();

  factory _$SonolythAudioLosslessContainerQualityImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythAudioLosslessContainerQualityImplFromJson(json);

  @override
  final int bitDepth;
// bit
  @override
  final int sampleRate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythAudioLosslessContainerQualityImpl &&
            (identical(other.bitDepth, bitDepth) ||
                other.bitDepth == bitDepth) &&
            (identical(other.sampleRate, sampleRate) ||
                other.sampleRate == sampleRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, bitDepth, sampleRate);

  /// Create a copy of SonolythAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythAudioLosslessContainerQualityImplCopyWith<
          _$SonolythAudioLosslessContainerQualityImpl>
      get copyWith => __$$SonolythAudioLosslessContainerQualityImplCopyWithImpl<
          _$SonolythAudioLosslessContainerQualityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythAudioLosslessContainerQualityImplToJson(
      this,
    );
  }
}

abstract class _SonolythAudioLosslessContainerQuality
    extends SonolythAudioLosslessContainerQuality {
  factory _SonolythAudioLosslessContainerQuality(
          {required final int bitDepth, required final int sampleRate}) =
      _$SonolythAudioLosslessContainerQualityImpl;
  _SonolythAudioLosslessContainerQuality._() : super._();

  factory _SonolythAudioLosslessContainerQuality.fromJson(
          Map<String, dynamic> json) =
      _$SonolythAudioLosslessContainerQualityImpl.fromJson;

  @override
  int get bitDepth; // bit
  @override
  int get sampleRate;

  /// Create a copy of SonolythAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythAudioLosslessContainerQualityImplCopyWith<
          _$SonolythAudioLosslessContainerQualityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythAudioSourceMatchObject _$SonolythAudioSourceMatchObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythAudioSourceMatchObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythAudioSourceMatchObject {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  List<String> get artists => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  String? get thumbnail => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;

  /// Serializes this SonolythAudioSourceMatchObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythAudioSourceMatchObjectCopyWith<SonolythAudioSourceMatchObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythAudioSourceMatchObjectCopyWith<$Res> {
  factory $SonolythAudioSourceMatchObjectCopyWith(
          SonolythAudioSourceMatchObject value,
          $Res Function(SonolythAudioSourceMatchObject) then) =
      _$SonolythAudioSourceMatchObjectCopyWithImpl<$Res,
          SonolythAudioSourceMatchObject>;
  @useResult
  $Res call(
      {String id,
      String title,
      List<String> artists,
      Duration duration,
      String? thumbnail,
      String externalUri});
}

/// @nodoc
class _$SonolythAudioSourceMatchObjectCopyWithImpl<$Res,
        $Val extends SonolythAudioSourceMatchObject>
    implements $SonolythAudioSourceMatchObjectCopyWith<$Res> {
  _$SonolythAudioSourceMatchObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artists = null,
    Object? duration = null,
    Object? thumbnail = freezed,
    Object? externalUri = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<String>,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnail: freezed == thumbnail
          ? _value.thumbnail
          : thumbnail // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythAudioSourceMatchObjectImplCopyWith<$Res>
    implements $SonolythAudioSourceMatchObjectCopyWith<$Res> {
  factory _$$SonolythAudioSourceMatchObjectImplCopyWith(
          _$SonolythAudioSourceMatchObjectImpl value,
          $Res Function(_$SonolythAudioSourceMatchObjectImpl) then) =
      __$$SonolythAudioSourceMatchObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      List<String> artists,
      Duration duration,
      String? thumbnail,
      String externalUri});
}

/// @nodoc
class __$$SonolythAudioSourceMatchObjectImplCopyWithImpl<$Res>
    extends _$SonolythAudioSourceMatchObjectCopyWithImpl<$Res,
        _$SonolythAudioSourceMatchObjectImpl>
    implements _$$SonolythAudioSourceMatchObjectImplCopyWith<$Res> {
  __$$SonolythAudioSourceMatchObjectImplCopyWithImpl(
      _$SonolythAudioSourceMatchObjectImpl _value,
      $Res Function(_$SonolythAudioSourceMatchObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artists = null,
    Object? duration = null,
    Object? thumbnail = freezed,
    Object? externalUri = null,
  }) {
    return _then(_$SonolythAudioSourceMatchObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<String>,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnail: freezed == thumbnail
          ? _value.thumbnail
          : thumbnail // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythAudioSourceMatchObjectImpl
    implements _SonolythAudioSourceMatchObject {
  _$SonolythAudioSourceMatchObjectImpl(
      {required this.id,
      required this.title,
      required final List<String> artists,
      required this.duration,
      this.thumbnail,
      required this.externalUri})
      : _artists = artists;

  factory _$SonolythAudioSourceMatchObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythAudioSourceMatchObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  final List<String> _artists;
  @override
  List<String> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  @override
  final Duration duration;
  @override
  final String? thumbnail;
  @override
  final String externalUri;

  @override
  String toString() {
    return 'SonolythAudioSourceMatchObject(id: $id, title: $title, artists: $artists, duration: $duration, thumbnail: $thumbnail, externalUri: $externalUri)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythAudioSourceMatchObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.thumbnail, thumbnail) ||
                other.thumbnail == thumbnail) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      const DeepCollectionEquality().hash(_artists),
      duration,
      thumbnail,
      externalUri);

  /// Create a copy of SonolythAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythAudioSourceMatchObjectImplCopyWith<
          _$SonolythAudioSourceMatchObjectImpl>
      get copyWith => __$$SonolythAudioSourceMatchObjectImplCopyWithImpl<
          _$SonolythAudioSourceMatchObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythAudioSourceMatchObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythAudioSourceMatchObject
    implements SonolythAudioSourceMatchObject {
  factory _SonolythAudioSourceMatchObject(
          {required final String id,
          required final String title,
          required final List<String> artists,
          required final Duration duration,
          final String? thumbnail,
          required final String externalUri}) =
      _$SonolythAudioSourceMatchObjectImpl;

  factory _SonolythAudioSourceMatchObject.fromJson(Map<String, dynamic> json) =
      _$SonolythAudioSourceMatchObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  List<String> get artists;
  @override
  Duration get duration;
  @override
  String? get thumbnail;
  @override
  String get externalUri;

  /// Create a copy of SonolythAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythAudioSourceMatchObjectImplCopyWith<
          _$SonolythAudioSourceMatchObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythAudioSourceStreamObject _$SonolythAudioSourceStreamObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythAudioSourceStreamObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythAudioSourceStreamObject {
  String get url => throw _privateConstructorUsedError;
  String get container => throw _privateConstructorUsedError;
  SonolythMediaCompressionType get type => throw _privateConstructorUsedError;
  String? get codec => throw _privateConstructorUsedError;
  double? get bitrate => throw _privateConstructorUsedError;
  int? get bitDepth => throw _privateConstructorUsedError;
  double? get sampleRate => throw _privateConstructorUsedError;

  /// Serializes this SonolythAudioSourceStreamObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythAudioSourceStreamObjectCopyWith<SonolythAudioSourceStreamObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythAudioSourceStreamObjectCopyWith<$Res> {
  factory $SonolythAudioSourceStreamObjectCopyWith(
          SonolythAudioSourceStreamObject value,
          $Res Function(SonolythAudioSourceStreamObject) then) =
      _$SonolythAudioSourceStreamObjectCopyWithImpl<$Res,
          SonolythAudioSourceStreamObject>;
  @useResult
  $Res call(
      {String url,
      String container,
      SonolythMediaCompressionType type,
      String? codec,
      double? bitrate,
      int? bitDepth,
      double? sampleRate});
}

/// @nodoc
class _$SonolythAudioSourceStreamObjectCopyWithImpl<$Res,
        $Val extends SonolythAudioSourceStreamObject>
    implements $SonolythAudioSourceStreamObjectCopyWith<$Res> {
  _$SonolythAudioSourceStreamObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? container = null,
    Object? type = null,
    Object? codec = freezed,
    Object? bitrate = freezed,
    Object? bitDepth = freezed,
    Object? sampleRate = freezed,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      container: null == container
          ? _value.container
          : container // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SonolythMediaCompressionType,
      codec: freezed == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String?,
      bitrate: freezed == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as double?,
      bitDepth: freezed == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int?,
      sampleRate: freezed == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythAudioSourceStreamObjectImplCopyWith<$Res>
    implements $SonolythAudioSourceStreamObjectCopyWith<$Res> {
  factory _$$SonolythAudioSourceStreamObjectImplCopyWith(
          _$SonolythAudioSourceStreamObjectImpl value,
          $Res Function(_$SonolythAudioSourceStreamObjectImpl) then) =
      __$$SonolythAudioSourceStreamObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String url,
      String container,
      SonolythMediaCompressionType type,
      String? codec,
      double? bitrate,
      int? bitDepth,
      double? sampleRate});
}

/// @nodoc
class __$$SonolythAudioSourceStreamObjectImplCopyWithImpl<$Res>
    extends _$SonolythAudioSourceStreamObjectCopyWithImpl<$Res,
        _$SonolythAudioSourceStreamObjectImpl>
    implements _$$SonolythAudioSourceStreamObjectImplCopyWith<$Res> {
  __$$SonolythAudioSourceStreamObjectImplCopyWithImpl(
      _$SonolythAudioSourceStreamObjectImpl _value,
      $Res Function(_$SonolythAudioSourceStreamObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? container = null,
    Object? type = null,
    Object? codec = freezed,
    Object? bitrate = freezed,
    Object? bitDepth = freezed,
    Object? sampleRate = freezed,
  }) {
    return _then(_$SonolythAudioSourceStreamObjectImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      container: null == container
          ? _value.container
          : container // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SonolythMediaCompressionType,
      codec: freezed == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String?,
      bitrate: freezed == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as double?,
      bitDepth: freezed == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int?,
      sampleRate: freezed == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythAudioSourceStreamObjectImpl
    implements _SonolythAudioSourceStreamObject {
  _$SonolythAudioSourceStreamObjectImpl(
      {required this.url,
      required this.container,
      required this.type,
      this.codec,
      this.bitrate,
      this.bitDepth,
      this.sampleRate});

  factory _$SonolythAudioSourceStreamObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythAudioSourceStreamObjectImplFromJson(json);

  @override
  final String url;
  @override
  final String container;
  @override
  final SonolythMediaCompressionType type;
  @override
  final String? codec;
  @override
  final double? bitrate;
  @override
  final int? bitDepth;
  @override
  final double? sampleRate;

  @override
  String toString() {
    return 'SonolythAudioSourceStreamObject(url: $url, container: $container, type: $type, codec: $codec, bitrate: $bitrate, bitDepth: $bitDepth, sampleRate: $sampleRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythAudioSourceStreamObjectImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.container, container) ||
                other.container == container) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.codec, codec) || other.codec == codec) &&
            (identical(other.bitrate, bitrate) || other.bitrate == bitrate) &&
            (identical(other.bitDepth, bitDepth) ||
                other.bitDepth == bitDepth) &&
            (identical(other.sampleRate, sampleRate) ||
                other.sampleRate == sampleRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, url, container, type, codec, bitrate, bitDepth, sampleRate);

  /// Create a copy of SonolythAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythAudioSourceStreamObjectImplCopyWith<
          _$SonolythAudioSourceStreamObjectImpl>
      get copyWith => __$$SonolythAudioSourceStreamObjectImplCopyWithImpl<
          _$SonolythAudioSourceStreamObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythAudioSourceStreamObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythAudioSourceStreamObject
    implements SonolythAudioSourceStreamObject {
  factory _SonolythAudioSourceStreamObject(
      {required final String url,
      required final String container,
      required final SonolythMediaCompressionType type,
      final String? codec,
      final double? bitrate,
      final int? bitDepth,
      final double? sampleRate}) = _$SonolythAudioSourceStreamObjectImpl;

  factory _SonolythAudioSourceStreamObject.fromJson(Map<String, dynamic> json) =
      _$SonolythAudioSourceStreamObjectImpl.fromJson;

  @override
  String get url;
  @override
  String get container;
  @override
  SonolythMediaCompressionType get type;
  @override
  String? get codec;
  @override
  double? get bitrate;
  @override
  int? get bitDepth;
  @override
  double? get sampleRate;

  /// Create a copy of SonolythAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythAudioSourceStreamObjectImplCopyWith<
          _$SonolythAudioSourceStreamObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythFullAlbumObject _$SonolythFullAlbumObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythFullAlbumObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythFullAlbumObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<SonolythSimpleArtistObject> get artists =>
      throw _privateConstructorUsedError;
  List<SonolythImageObject> get images => throw _privateConstructorUsedError;
  String get releaseDate => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  int get totalTracks => throw _privateConstructorUsedError;
  SonolythAlbumType get albumType => throw _privateConstructorUsedError;
  String? get recordLabel => throw _privateConstructorUsedError;
  List<String>? get genres => throw _privateConstructorUsedError;

  /// Serializes this SonolythFullAlbumObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythFullAlbumObjectCopyWith<SonolythFullAlbumObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythFullAlbumObjectCopyWith<$Res> {
  factory $SonolythFullAlbumObjectCopyWith(SonolythFullAlbumObject value,
          $Res Function(SonolythFullAlbumObject) then) =
      _$SonolythFullAlbumObjectCopyWithImpl<$Res, SonolythFullAlbumObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<SonolythSimpleArtistObject> artists,
      List<SonolythImageObject> images,
      String releaseDate,
      String externalUri,
      int totalTracks,
      SonolythAlbumType albumType,
      String? recordLabel,
      List<String>? genres});
}

/// @nodoc
class _$SonolythFullAlbumObjectCopyWithImpl<$Res,
        $Val extends SonolythFullAlbumObject>
    implements $SonolythFullAlbumObjectCopyWith<$Res> {
  _$SonolythFullAlbumObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artists = null,
    Object? images = null,
    Object? releaseDate = null,
    Object? externalUri = null,
    Object? totalTracks = null,
    Object? albumType = null,
    Object? recordLabel = freezed,
    Object? genres = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      releaseDate: null == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      totalTracks: null == totalTracks
          ? _value.totalTracks
          : totalTracks // ignore: cast_nullable_to_non_nullable
              as int,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SonolythAlbumType,
      recordLabel: freezed == recordLabel
          ? _value.recordLabel
          : recordLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      genres: freezed == genres
          ? _value.genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythFullAlbumObjectImplCopyWith<$Res>
    implements $SonolythFullAlbumObjectCopyWith<$Res> {
  factory _$$SonolythFullAlbumObjectImplCopyWith(
          _$SonolythFullAlbumObjectImpl value,
          $Res Function(_$SonolythFullAlbumObjectImpl) then) =
      __$$SonolythFullAlbumObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<SonolythSimpleArtistObject> artists,
      List<SonolythImageObject> images,
      String releaseDate,
      String externalUri,
      int totalTracks,
      SonolythAlbumType albumType,
      String? recordLabel,
      List<String>? genres});
}

/// @nodoc
class __$$SonolythFullAlbumObjectImplCopyWithImpl<$Res>
    extends _$SonolythFullAlbumObjectCopyWithImpl<$Res,
        _$SonolythFullAlbumObjectImpl>
    implements _$$SonolythFullAlbumObjectImplCopyWith<$Res> {
  __$$SonolythFullAlbumObjectImplCopyWithImpl(
      _$SonolythFullAlbumObjectImpl _value,
      $Res Function(_$SonolythFullAlbumObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artists = null,
    Object? images = null,
    Object? releaseDate = null,
    Object? externalUri = null,
    Object? totalTracks = null,
    Object? albumType = null,
    Object? recordLabel = freezed,
    Object? genres = freezed,
  }) {
    return _then(_$SonolythFullAlbumObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      releaseDate: null == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      totalTracks: null == totalTracks
          ? _value.totalTracks
          : totalTracks // ignore: cast_nullable_to_non_nullable
              as int,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SonolythAlbumType,
      recordLabel: freezed == recordLabel
          ? _value.recordLabel
          : recordLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      genres: freezed == genres
          ? _value._genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythFullAlbumObjectImpl implements _SonolythFullAlbumObject {
  _$SonolythFullAlbumObjectImpl(
      {required this.id,
      required this.name,
      required final List<SonolythSimpleArtistObject> artists,
      final List<SonolythImageObject> images = const [],
      required this.releaseDate,
      required this.externalUri,
      required this.totalTracks,
      required this.albumType,
      this.recordLabel,
      final List<String>? genres})
      : _artists = artists,
        _images = images,
        _genres = genres;

  factory _$SonolythFullAlbumObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythFullAlbumObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<SonolythSimpleArtistObject> _artists;
  @override
  List<SonolythSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  final List<SonolythImageObject> _images;
  @override
  @JsonKey()
  List<SonolythImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final String releaseDate;
  @override
  final String externalUri;
  @override
  final int totalTracks;
  @override
  final SonolythAlbumType albumType;
  @override
  final String? recordLabel;
  final List<String>? _genres;
  @override
  List<String>? get genres {
    final value = _genres;
    if (value == null) return null;
    if (_genres is EqualUnmodifiableListView) return _genres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'SonolythFullAlbumObject(id: $id, name: $name, artists: $artists, images: $images, releaseDate: $releaseDate, externalUri: $externalUri, totalTracks: $totalTracks, albumType: $albumType, recordLabel: $recordLabel, genres: $genres)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythFullAlbumObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.releaseDate, releaseDate) ||
                other.releaseDate == releaseDate) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.totalTracks, totalTracks) ||
                other.totalTracks == totalTracks) &&
            (identical(other.albumType, albumType) ||
                other.albumType == albumType) &&
            (identical(other.recordLabel, recordLabel) ||
                other.recordLabel == recordLabel) &&
            const DeepCollectionEquality().equals(other._genres, _genres));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      const DeepCollectionEquality().hash(_artists),
      const DeepCollectionEquality().hash(_images),
      releaseDate,
      externalUri,
      totalTracks,
      albumType,
      recordLabel,
      const DeepCollectionEquality().hash(_genres));

  /// Create a copy of SonolythFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythFullAlbumObjectImplCopyWith<_$SonolythFullAlbumObjectImpl>
      get copyWith => __$$SonolythFullAlbumObjectImplCopyWithImpl<
          _$SonolythFullAlbumObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythFullAlbumObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythFullAlbumObject implements SonolythFullAlbumObject {
  factory _SonolythFullAlbumObject(
      {required final String id,
      required final String name,
      required final List<SonolythSimpleArtistObject> artists,
      final List<SonolythImageObject> images,
      required final String releaseDate,
      required final String externalUri,
      required final int totalTracks,
      required final SonolythAlbumType albumType,
      final String? recordLabel,
      final List<String>? genres}) = _$SonolythFullAlbumObjectImpl;

  factory _SonolythFullAlbumObject.fromJson(Map<String, dynamic> json) =
      _$SonolythFullAlbumObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<SonolythSimpleArtistObject> get artists;
  @override
  List<SonolythImageObject> get images;
  @override
  String get releaseDate;
  @override
  String get externalUri;
  @override
  int get totalTracks;
  @override
  SonolythAlbumType get albumType;
  @override
  String? get recordLabel;
  @override
  List<String>? get genres;

  /// Create a copy of SonolythFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythFullAlbumObjectImplCopyWith<_$SonolythFullAlbumObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythSimpleAlbumObject _$SonolythSimpleAlbumObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythSimpleAlbumObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythSimpleAlbumObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SonolythSimpleArtistObject> get artists =>
      throw _privateConstructorUsedError;
  List<SonolythImageObject> get images => throw _privateConstructorUsedError;
  SonolythAlbumType get albumType => throw _privateConstructorUsedError;
  String? get releaseDate => throw _privateConstructorUsedError;

  /// Serializes this SonolythSimpleAlbumObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythSimpleAlbumObjectCopyWith<SonolythSimpleAlbumObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythSimpleAlbumObjectCopyWith<$Res> {
  factory $SonolythSimpleAlbumObjectCopyWith(SonolythSimpleAlbumObject value,
          $Res Function(SonolythSimpleAlbumObject) then) =
      _$SonolythSimpleAlbumObjectCopyWithImpl<$Res, SonolythSimpleAlbumObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythSimpleArtistObject> artists,
      List<SonolythImageObject> images,
      SonolythAlbumType albumType,
      String? releaseDate});
}

/// @nodoc
class _$SonolythSimpleAlbumObjectCopyWithImpl<$Res,
        $Val extends SonolythSimpleAlbumObject>
    implements $SonolythSimpleAlbumObjectCopyWith<$Res> {
  _$SonolythSimpleAlbumObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? images = null,
    Object? albumType = null,
    Object? releaseDate = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SonolythAlbumType,
      releaseDate: freezed == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythSimpleAlbumObjectImplCopyWith<$Res>
    implements $SonolythSimpleAlbumObjectCopyWith<$Res> {
  factory _$$SonolythSimpleAlbumObjectImplCopyWith(
          _$SonolythSimpleAlbumObjectImpl value,
          $Res Function(_$SonolythSimpleAlbumObjectImpl) then) =
      __$$SonolythSimpleAlbumObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythSimpleArtistObject> artists,
      List<SonolythImageObject> images,
      SonolythAlbumType albumType,
      String? releaseDate});
}

/// @nodoc
class __$$SonolythSimpleAlbumObjectImplCopyWithImpl<$Res>
    extends _$SonolythSimpleAlbumObjectCopyWithImpl<$Res,
        _$SonolythSimpleAlbumObjectImpl>
    implements _$$SonolythSimpleAlbumObjectImplCopyWith<$Res> {
  __$$SonolythSimpleAlbumObjectImplCopyWithImpl(
      _$SonolythSimpleAlbumObjectImpl _value,
      $Res Function(_$SonolythSimpleAlbumObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? images = null,
    Object? albumType = null,
    Object? releaseDate = freezed,
  }) {
    return _then(_$SonolythSimpleAlbumObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SonolythAlbumType,
      releaseDate: freezed == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythSimpleAlbumObjectImpl implements _SonolythSimpleAlbumObject {
  _$SonolythSimpleAlbumObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      required final List<SonolythSimpleArtistObject> artists,
      final List<SonolythImageObject> images = const [],
      required this.albumType,
      this.releaseDate})
      : _artists = artists,
        _images = images;

  factory _$SonolythSimpleAlbumObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythSimpleAlbumObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SonolythSimpleArtistObject> _artists;
  @override
  List<SonolythSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  final List<SonolythImageObject> _images;
  @override
  @JsonKey()
  List<SonolythImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final SonolythAlbumType albumType;
  @override
  final String? releaseDate;

  @override
  String toString() {
    return 'SonolythSimpleAlbumObject(id: $id, name: $name, externalUri: $externalUri, artists: $artists, images: $images, albumType: $albumType, releaseDate: $releaseDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythSimpleAlbumObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.albumType, albumType) ||
                other.albumType == albumType) &&
            (identical(other.releaseDate, releaseDate) ||
                other.releaseDate == releaseDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      externalUri,
      const DeepCollectionEquality().hash(_artists),
      const DeepCollectionEquality().hash(_images),
      albumType,
      releaseDate);

  /// Create a copy of SonolythSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythSimpleAlbumObjectImplCopyWith<_$SonolythSimpleAlbumObjectImpl>
      get copyWith => __$$SonolythSimpleAlbumObjectImplCopyWithImpl<
          _$SonolythSimpleAlbumObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythSimpleAlbumObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythSimpleAlbumObject implements SonolythSimpleAlbumObject {
  factory _SonolythSimpleAlbumObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      required final List<SonolythSimpleArtistObject> artists,
      final List<SonolythImageObject> images,
      required final SonolythAlbumType albumType,
      final String? releaseDate}) = _$SonolythSimpleAlbumObjectImpl;

  factory _SonolythSimpleAlbumObject.fromJson(Map<String, dynamic> json) =
      _$SonolythSimpleAlbumObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SonolythSimpleArtistObject> get artists;
  @override
  List<SonolythImageObject> get images;
  @override
  SonolythAlbumType get albumType;
  @override
  String? get releaseDate;

  /// Create a copy of SonolythSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythSimpleAlbumObjectImplCopyWith<_$SonolythSimpleAlbumObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythFullArtistObject _$SonolythFullArtistObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythFullArtistObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythFullArtistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SonolythImageObject> get images => throw _privateConstructorUsedError;
  List<String>? get genres => throw _privateConstructorUsedError;
  int? get followers => throw _privateConstructorUsedError;

  /// Serializes this SonolythFullArtistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythFullArtistObjectCopyWith<SonolythFullArtistObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythFullArtistObjectCopyWith<$Res> {
  factory $SonolythFullArtistObjectCopyWith(SonolythFullArtistObject value,
          $Res Function(SonolythFullArtistObject) then) =
      _$SonolythFullArtistObjectCopyWithImpl<$Res, SonolythFullArtistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythImageObject> images,
      List<String>? genres,
      int? followers});
}

/// @nodoc
class _$SonolythFullArtistObjectCopyWithImpl<$Res,
        $Val extends SonolythFullArtistObject>
    implements $SonolythFullArtistObjectCopyWith<$Res> {
  _$SonolythFullArtistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = null,
    Object? genres = freezed,
    Object? followers = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      genres: freezed == genres
          ? _value.genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      followers: freezed == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythFullArtistObjectImplCopyWith<$Res>
    implements $SonolythFullArtistObjectCopyWith<$Res> {
  factory _$$SonolythFullArtistObjectImplCopyWith(
          _$SonolythFullArtistObjectImpl value,
          $Res Function(_$SonolythFullArtistObjectImpl) then) =
      __$$SonolythFullArtistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythImageObject> images,
      List<String>? genres,
      int? followers});
}

/// @nodoc
class __$$SonolythFullArtistObjectImplCopyWithImpl<$Res>
    extends _$SonolythFullArtistObjectCopyWithImpl<$Res,
        _$SonolythFullArtistObjectImpl>
    implements _$$SonolythFullArtistObjectImplCopyWith<$Res> {
  __$$SonolythFullArtistObjectImplCopyWithImpl(
      _$SonolythFullArtistObjectImpl _value,
      $Res Function(_$SonolythFullArtistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = null,
    Object? genres = freezed,
    Object? followers = freezed,
  }) {
    return _then(_$SonolythFullArtistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      genres: freezed == genres
          ? _value._genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      followers: freezed == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythFullArtistObjectImpl implements _SonolythFullArtistObject {
  _$SonolythFullArtistObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SonolythImageObject> images = const [],
      final List<String>? genres,
      this.followers})
      : _images = images,
        _genres = genres;

  factory _$SonolythFullArtistObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythFullArtistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SonolythImageObject> _images;
  @override
  @JsonKey()
  List<SonolythImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  final List<String>? _genres;
  @override
  List<String>? get genres {
    final value = _genres;
    if (value == null) return null;
    if (_genres is EqualUnmodifiableListView) return _genres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final int? followers;

  @override
  String toString() {
    return 'SonolythFullArtistObject(id: $id, name: $name, externalUri: $externalUri, images: $images, genres: $genres, followers: $followers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythFullArtistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            const DeepCollectionEquality().equals(other._genres, _genres) &&
            (identical(other.followers, followers) ||
                other.followers == followers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      externalUri,
      const DeepCollectionEquality().hash(_images),
      const DeepCollectionEquality().hash(_genres),
      followers);

  /// Create a copy of SonolythFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythFullArtistObjectImplCopyWith<_$SonolythFullArtistObjectImpl>
      get copyWith => __$$SonolythFullArtistObjectImplCopyWithImpl<
          _$SonolythFullArtistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythFullArtistObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythFullArtistObject implements SonolythFullArtistObject {
  factory _SonolythFullArtistObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      final List<SonolythImageObject> images,
      final List<String>? genres,
      final int? followers}) = _$SonolythFullArtistObjectImpl;

  factory _SonolythFullArtistObject.fromJson(Map<String, dynamic> json) =
      _$SonolythFullArtistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SonolythImageObject> get images;
  @override
  List<String>? get genres;
  @override
  int? get followers;

  /// Create a copy of SonolythFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythFullArtistObjectImplCopyWith<_$SonolythFullArtistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythSimpleArtistObject _$SonolythSimpleArtistObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythSimpleArtistObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythSimpleArtistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SonolythImageObject>? get images => throw _privateConstructorUsedError;

  /// Serializes this SonolythSimpleArtistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythSimpleArtistObjectCopyWith<SonolythSimpleArtistObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythSimpleArtistObjectCopyWith<$Res> {
  factory $SonolythSimpleArtistObjectCopyWith(SonolythSimpleArtistObject value,
          $Res Function(SonolythSimpleArtistObject) then) =
      _$SonolythSimpleArtistObjectCopyWithImpl<$Res,
          SonolythSimpleArtistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythImageObject>? images});
}

/// @nodoc
class _$SonolythSimpleArtistObjectCopyWithImpl<$Res,
        $Val extends SonolythSimpleArtistObject>
    implements $SonolythSimpleArtistObjectCopyWith<$Res> {
  _$SonolythSimpleArtistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: freezed == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythSimpleArtistObjectImplCopyWith<$Res>
    implements $SonolythSimpleArtistObjectCopyWith<$Res> {
  factory _$$SonolythSimpleArtistObjectImplCopyWith(
          _$SonolythSimpleArtistObjectImpl value,
          $Res Function(_$SonolythSimpleArtistObjectImpl) then) =
      __$$SonolythSimpleArtistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythImageObject>? images});
}

/// @nodoc
class __$$SonolythSimpleArtistObjectImplCopyWithImpl<$Res>
    extends _$SonolythSimpleArtistObjectCopyWithImpl<$Res,
        _$SonolythSimpleArtistObjectImpl>
    implements _$$SonolythSimpleArtistObjectImplCopyWith<$Res> {
  __$$SonolythSimpleArtistObjectImplCopyWithImpl(
      _$SonolythSimpleArtistObjectImpl _value,
      $Res Function(_$SonolythSimpleArtistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = freezed,
  }) {
    return _then(_$SonolythSimpleArtistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: freezed == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythSimpleArtistObjectImpl implements _SonolythSimpleArtistObject {
  _$SonolythSimpleArtistObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SonolythImageObject>? images})
      : _images = images;

  factory _$SonolythSimpleArtistObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythSimpleArtistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SonolythImageObject>? _images;
  @override
  List<SonolythImageObject>? get images {
    final value = _images;
    if (value == null) return null;
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'SonolythSimpleArtistObject(id: $id, name: $name, externalUri: $externalUri, images: $images)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythSimpleArtistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._images, _images));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, externalUri,
      const DeepCollectionEquality().hash(_images));

  /// Create a copy of SonolythSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythSimpleArtistObjectImplCopyWith<_$SonolythSimpleArtistObjectImpl>
      get copyWith => __$$SonolythSimpleArtistObjectImplCopyWithImpl<
          _$SonolythSimpleArtistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythSimpleArtistObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythSimpleArtistObject
    implements SonolythSimpleArtistObject {
  factory _SonolythSimpleArtistObject(
          {required final String id,
          required final String name,
          required final String externalUri,
          final List<SonolythImageObject>? images}) =
      _$SonolythSimpleArtistObjectImpl;

  factory _SonolythSimpleArtistObject.fromJson(Map<String, dynamic> json) =
      _$SonolythSimpleArtistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SonolythImageObject>? get images;

  /// Create a copy of SonolythSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythSimpleArtistObjectImplCopyWith<_$SonolythSimpleArtistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythBrowseSectionObject<T> _$SonolythBrowseSectionObjectFromJson<T>(
    Map<String, dynamic> json, T Function(Object?) fromJsonT) {
  return _SonolythBrowseSectionObject<T>.fromJson(json, fromJsonT);
}

/// @nodoc
mixin _$SonolythBrowseSectionObject<T> {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  bool get browseMore => throw _privateConstructorUsedError;
  List<T> get items => throw _privateConstructorUsedError;

  /// Serializes this SonolythBrowseSectionObject to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) =>
      throw _privateConstructorUsedError;

  /// Create a copy of SonolythBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythBrowseSectionObjectCopyWith<T, SonolythBrowseSectionObject<T>>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythBrowseSectionObjectCopyWith<T, $Res> {
  factory $SonolythBrowseSectionObjectCopyWith(
          SonolythBrowseSectionObject<T> value,
          $Res Function(SonolythBrowseSectionObject<T>) then) =
      _$SonolythBrowseSectionObjectCopyWithImpl<T, $Res,
          SonolythBrowseSectionObject<T>>;
  @useResult
  $Res call(
      {String id,
      String title,
      String externalUri,
      bool browseMore,
      List<T> items});
}

/// @nodoc
class _$SonolythBrowseSectionObjectCopyWithImpl<T, $Res,
        $Val extends SonolythBrowseSectionObject<T>>
    implements $SonolythBrowseSectionObjectCopyWith<T, $Res> {
  _$SonolythBrowseSectionObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? externalUri = null,
    Object? browseMore = null,
    Object? items = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      browseMore: null == browseMore
          ? _value.browseMore
          : browseMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythBrowseSectionObjectImplCopyWith<T, $Res>
    implements $SonolythBrowseSectionObjectCopyWith<T, $Res> {
  factory _$$SonolythBrowseSectionObjectImplCopyWith(
          _$SonolythBrowseSectionObjectImpl<T> value,
          $Res Function(_$SonolythBrowseSectionObjectImpl<T>) then) =
      __$$SonolythBrowseSectionObjectImplCopyWithImpl<T, $Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String externalUri,
      bool browseMore,
      List<T> items});
}

/// @nodoc
class __$$SonolythBrowseSectionObjectImplCopyWithImpl<T, $Res>
    extends _$SonolythBrowseSectionObjectCopyWithImpl<T, $Res,
        _$SonolythBrowseSectionObjectImpl<T>>
    implements _$$SonolythBrowseSectionObjectImplCopyWith<T, $Res> {
  __$$SonolythBrowseSectionObjectImplCopyWithImpl(
      _$SonolythBrowseSectionObjectImpl<T> _value,
      $Res Function(_$SonolythBrowseSectionObjectImpl<T>) _then)
      : super(_value, _then);

  /// Create a copy of SonolythBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? externalUri = null,
    Object? browseMore = null,
    Object? items = null,
  }) {
    return _then(_$SonolythBrowseSectionObjectImpl<T>(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      browseMore: null == browseMore
          ? _value.browseMore
          : browseMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ));
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _$SonolythBrowseSectionObjectImpl<T>
    implements _SonolythBrowseSectionObject<T> {
  _$SonolythBrowseSectionObjectImpl(
      {required this.id,
      required this.title,
      required this.externalUri,
      required this.browseMore,
      required final List<T> items})
      : _items = items;

  factory _$SonolythBrowseSectionObjectImpl.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$$SonolythBrowseSectionObjectImplFromJson(json, fromJsonT);

  @override
  final String id;
  @override
  final String title;
  @override
  final String externalUri;
  @override
  final bool browseMore;
  final List<T> _items;
  @override
  List<T> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'SonolythBrowseSectionObject<$T>(id: $id, title: $title, externalUri: $externalUri, browseMore: $browseMore, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythBrowseSectionObjectImpl<T> &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.browseMore, browseMore) ||
                other.browseMore == browseMore) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, externalUri,
      browseMore, const DeepCollectionEquality().hash(_items));

  /// Create a copy of SonolythBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythBrowseSectionObjectImplCopyWith<T,
          _$SonolythBrowseSectionObjectImpl<T>>
      get copyWith => __$$SonolythBrowseSectionObjectImplCopyWithImpl<T,
          _$SonolythBrowseSectionObjectImpl<T>>(this, _$identity);

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$$SonolythBrowseSectionObjectImplToJson<T>(this, toJsonT);
  }
}

abstract class _SonolythBrowseSectionObject<T>
    implements SonolythBrowseSectionObject<T> {
  factory _SonolythBrowseSectionObject(
      {required final String id,
      required final String title,
      required final String externalUri,
      required final bool browseMore,
      required final List<T> items}) = _$SonolythBrowseSectionObjectImpl<T>;

  factory _SonolythBrowseSectionObject.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =
      _$SonolythBrowseSectionObjectImpl<T>.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get externalUri;
  @override
  bool get browseMore;
  @override
  List<T> get items;

  /// Create a copy of SonolythBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythBrowseSectionObjectImplCopyWith<T,
          _$SonolythBrowseSectionObjectImpl<T>>
      get copyWith => throw _privateConstructorUsedError;
}

MetadataFormFieldObject _$MetadataFormFieldObjectFromJson(
    Map<String, dynamic> json) {
  switch (json['objectType']) {
    case 'input':
      return MetadataFormFieldInputObject.fromJson(json);
    case 'text':
      return MetadataFormFieldTextObject.fromJson(json);

    default:
      throw CheckedFromJsonException(
          json,
          'objectType',
          'MetadataFormFieldObject',
          'Invalid union type "${json['objectType']}"!');
  }
}

/// @nodoc
mixin _$MetadataFormFieldObject {
  String get objectType => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)
        input,
    required TResult Function(String objectType, String text) text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult? Function(String objectType, String text)? text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult Function(String objectType, String text)? text,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MetadataFormFieldInputObject value) input,
    required TResult Function(MetadataFormFieldTextObject value) text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MetadataFormFieldInputObject value)? input,
    TResult? Function(MetadataFormFieldTextObject value)? text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MetadataFormFieldInputObject value)? input,
    TResult Function(MetadataFormFieldTextObject value)? text,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this MetadataFormFieldObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetadataFormFieldObjectCopyWith<MetadataFormFieldObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataFormFieldObjectCopyWith<$Res> {
  factory $MetadataFormFieldObjectCopyWith(MetadataFormFieldObject value,
          $Res Function(MetadataFormFieldObject) then) =
      _$MetadataFormFieldObjectCopyWithImpl<$Res, MetadataFormFieldObject>;
  @useResult
  $Res call({String objectType});
}

/// @nodoc
class _$MetadataFormFieldObjectCopyWithImpl<$Res,
        $Val extends MetadataFormFieldObject>
    implements $MetadataFormFieldObjectCopyWith<$Res> {
  _$MetadataFormFieldObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectType = null,
  }) {
    return _then(_value.copyWith(
      objectType: null == objectType
          ? _value.objectType
          : objectType // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetadataFormFieldInputObjectImplCopyWith<$Res>
    implements $MetadataFormFieldObjectCopyWith<$Res> {
  factory _$$MetadataFormFieldInputObjectImplCopyWith(
          _$MetadataFormFieldInputObjectImpl value,
          $Res Function(_$MetadataFormFieldInputObjectImpl) then) =
      __$$MetadataFormFieldInputObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String objectType,
      String id,
      FormFieldVariant variant,
      String? placeholder,
      String? defaultValue,
      bool? required,
      String? regex});
}

/// @nodoc
class __$$MetadataFormFieldInputObjectImplCopyWithImpl<$Res>
    extends _$MetadataFormFieldObjectCopyWithImpl<$Res,
        _$MetadataFormFieldInputObjectImpl>
    implements _$$MetadataFormFieldInputObjectImplCopyWith<$Res> {
  __$$MetadataFormFieldInputObjectImplCopyWithImpl(
      _$MetadataFormFieldInputObjectImpl _value,
      $Res Function(_$MetadataFormFieldInputObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectType = null,
    Object? id = null,
    Object? variant = null,
    Object? placeholder = freezed,
    Object? defaultValue = freezed,
    Object? required = freezed,
    Object? regex = freezed,
  }) {
    return _then(_$MetadataFormFieldInputObjectImpl(
      objectType: null == objectType
          ? _value.objectType
          : objectType // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      variant: null == variant
          ? _value.variant
          : variant // ignore: cast_nullable_to_non_nullable
              as FormFieldVariant,
      placeholder: freezed == placeholder
          ? _value.placeholder
          : placeholder // ignore: cast_nullable_to_non_nullable
              as String?,
      defaultValue: freezed == defaultValue
          ? _value.defaultValue
          : defaultValue // ignore: cast_nullable_to_non_nullable
              as String?,
      required: freezed == required
          ? _value.required
          : required // ignore: cast_nullable_to_non_nullable
              as bool?,
      regex: freezed == regex
          ? _value.regex
          : regex // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MetadataFormFieldInputObjectImpl
    implements MetadataFormFieldInputObject {
  _$MetadataFormFieldInputObjectImpl(
      {required this.objectType,
      required this.id,
      this.variant = FormFieldVariant.text,
      this.placeholder,
      this.defaultValue,
      this.required,
      this.regex});

  factory _$MetadataFormFieldInputObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$MetadataFormFieldInputObjectImplFromJson(json);

  @override
  final String objectType;
  @override
  final String id;
  @override
  @JsonKey()
  final FormFieldVariant variant;
  @override
  final String? placeholder;
  @override
  final String? defaultValue;
  @override
  final bool? required;
  @override
  final String? regex;

  @override
  String toString() {
    return 'MetadataFormFieldObject.input(objectType: $objectType, id: $id, variant: $variant, placeholder: $placeholder, defaultValue: $defaultValue, required: $required, regex: $regex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataFormFieldInputObjectImpl &&
            (identical(other.objectType, objectType) ||
                other.objectType == objectType) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.variant, variant) || other.variant == variant) &&
            (identical(other.placeholder, placeholder) ||
                other.placeholder == placeholder) &&
            (identical(other.defaultValue, defaultValue) ||
                other.defaultValue == defaultValue) &&
            (identical(other.required, required) ||
                other.required == required) &&
            (identical(other.regex, regex) || other.regex == regex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, objectType, id, variant,
      placeholder, defaultValue, required, regex);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataFormFieldInputObjectImplCopyWith<
          _$MetadataFormFieldInputObjectImpl>
      get copyWith => __$$MetadataFormFieldInputObjectImplCopyWithImpl<
          _$MetadataFormFieldInputObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)
        input,
    required TResult Function(String objectType, String text) text,
  }) {
    return input(
        objectType, id, variant, placeholder, defaultValue, required, regex);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult? Function(String objectType, String text)? text,
  }) {
    return input?.call(
        objectType, id, variant, placeholder, defaultValue, required, regex);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult Function(String objectType, String text)? text,
    required TResult orElse(),
  }) {
    if (input != null) {
      return input(
          objectType, id, variant, placeholder, defaultValue, required, regex);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MetadataFormFieldInputObject value) input,
    required TResult Function(MetadataFormFieldTextObject value) text,
  }) {
    return input(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MetadataFormFieldInputObject value)? input,
    TResult? Function(MetadataFormFieldTextObject value)? text,
  }) {
    return input?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MetadataFormFieldInputObject value)? input,
    TResult Function(MetadataFormFieldTextObject value)? text,
    required TResult orElse(),
  }) {
    if (input != null) {
      return input(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataFormFieldInputObjectImplToJson(
      this,
    );
  }
}

abstract class MetadataFormFieldInputObject implements MetadataFormFieldObject {
  factory MetadataFormFieldInputObject(
      {required final String objectType,
      required final String id,
      final FormFieldVariant variant,
      final String? placeholder,
      final String? defaultValue,
      final bool? required,
      final String? regex}) = _$MetadataFormFieldInputObjectImpl;

  factory MetadataFormFieldInputObject.fromJson(Map<String, dynamic> json) =
      _$MetadataFormFieldInputObjectImpl.fromJson;

  @override
  String get objectType;
  String get id;
  FormFieldVariant get variant;
  String? get placeholder;
  String? get defaultValue;
  bool? get required;
  String? get regex;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataFormFieldInputObjectImplCopyWith<
          _$MetadataFormFieldInputObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MetadataFormFieldTextObjectImplCopyWith<$Res>
    implements $MetadataFormFieldObjectCopyWith<$Res> {
  factory _$$MetadataFormFieldTextObjectImplCopyWith(
          _$MetadataFormFieldTextObjectImpl value,
          $Res Function(_$MetadataFormFieldTextObjectImpl) then) =
      __$$MetadataFormFieldTextObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String objectType, String text});
}

/// @nodoc
class __$$MetadataFormFieldTextObjectImplCopyWithImpl<$Res>
    extends _$MetadataFormFieldObjectCopyWithImpl<$Res,
        _$MetadataFormFieldTextObjectImpl>
    implements _$$MetadataFormFieldTextObjectImplCopyWith<$Res> {
  __$$MetadataFormFieldTextObjectImplCopyWithImpl(
      _$MetadataFormFieldTextObjectImpl _value,
      $Res Function(_$MetadataFormFieldTextObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectType = null,
    Object? text = null,
  }) {
    return _then(_$MetadataFormFieldTextObjectImpl(
      objectType: null == objectType
          ? _value.objectType
          : objectType // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MetadataFormFieldTextObjectImpl implements MetadataFormFieldTextObject {
  _$MetadataFormFieldTextObjectImpl(
      {required this.objectType, required this.text});

  factory _$MetadataFormFieldTextObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$MetadataFormFieldTextObjectImplFromJson(json);

  @override
  final String objectType;
  @override
  final String text;

  @override
  String toString() {
    return 'MetadataFormFieldObject.text(objectType: $objectType, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataFormFieldTextObjectImpl &&
            (identical(other.objectType, objectType) ||
                other.objectType == objectType) &&
            (identical(other.text, text) || other.text == text));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, objectType, text);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataFormFieldTextObjectImplCopyWith<_$MetadataFormFieldTextObjectImpl>
      get copyWith => __$$MetadataFormFieldTextObjectImplCopyWithImpl<
          _$MetadataFormFieldTextObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)
        input,
    required TResult Function(String objectType, String text) text,
  }) {
    return text(objectType, this.text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult? Function(String objectType, String text)? text,
  }) {
    return text?.call(objectType, this.text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult Function(String objectType, String text)? text,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(objectType, this.text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MetadataFormFieldInputObject value) input,
    required TResult Function(MetadataFormFieldTextObject value) text,
  }) {
    return text(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MetadataFormFieldInputObject value)? input,
    TResult? Function(MetadataFormFieldTextObject value)? text,
  }) {
    return text?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MetadataFormFieldInputObject value)? input,
    TResult Function(MetadataFormFieldTextObject value)? text,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataFormFieldTextObjectImplToJson(
      this,
    );
  }
}

abstract class MetadataFormFieldTextObject implements MetadataFormFieldObject {
  factory MetadataFormFieldTextObject(
      {required final String objectType,
      required final String text}) = _$MetadataFormFieldTextObjectImpl;

  factory MetadataFormFieldTextObject.fromJson(Map<String, dynamic> json) =
      _$MetadataFormFieldTextObjectImpl.fromJson;

  @override
  String get objectType;
  String get text;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataFormFieldTextObjectImplCopyWith<_$MetadataFormFieldTextObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythImageObject _$SonolythImageObjectFromJson(Map<String, dynamic> json) {
  return _SonolythImageObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythImageObject {
  String get url => throw _privateConstructorUsedError;
  int? get width => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;

  /// Serializes this SonolythImageObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythImageObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythImageObjectCopyWith<SonolythImageObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythImageObjectCopyWith<$Res> {
  factory $SonolythImageObjectCopyWith(
          SonolythImageObject value, $Res Function(SonolythImageObject) then) =
      _$SonolythImageObjectCopyWithImpl<$Res, SonolythImageObject>;
  @useResult
  $Res call({String url, int? width, int? height});
}

/// @nodoc
class _$SonolythImageObjectCopyWithImpl<$Res, $Val extends SonolythImageObject>
    implements $SonolythImageObjectCopyWith<$Res> {
  _$SonolythImageObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythImageObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythImageObjectImplCopyWith<$Res>
    implements $SonolythImageObjectCopyWith<$Res> {
  factory _$$SonolythImageObjectImplCopyWith(_$SonolythImageObjectImpl value,
          $Res Function(_$SonolythImageObjectImpl) then) =
      __$$SonolythImageObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String url, int? width, int? height});
}

/// @nodoc
class __$$SonolythImageObjectImplCopyWithImpl<$Res>
    extends _$SonolythImageObjectCopyWithImpl<$Res, _$SonolythImageObjectImpl>
    implements _$$SonolythImageObjectImplCopyWith<$Res> {
  __$$SonolythImageObjectImplCopyWithImpl(_$SonolythImageObjectImpl _value,
      $Res Function(_$SonolythImageObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythImageObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_$SonolythImageObjectImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythImageObjectImpl implements _SonolythImageObject {
  _$SonolythImageObjectImpl({required this.url, this.width, this.height});

  factory _$SonolythImageObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythImageObjectImplFromJson(json);

  @override
  final String url;
  @override
  final int? width;
  @override
  final int? height;

  @override
  String toString() {
    return 'SonolythImageObject(url: $url, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythImageObjectImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, url, width, height);

  /// Create a copy of SonolythImageObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythImageObjectImplCopyWith<_$SonolythImageObjectImpl> get copyWith =>
      __$$SonolythImageObjectImplCopyWithImpl<_$SonolythImageObjectImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythImageObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythImageObject implements SonolythImageObject {
  factory _SonolythImageObject(
      {required final String url,
      final int? width,
      final int? height}) = _$SonolythImageObjectImpl;

  factory _SonolythImageObject.fromJson(Map<String, dynamic> json) =
      _$SonolythImageObjectImpl.fromJson;

  @override
  String get url;
  @override
  int? get width;
  @override
  int? get height;

  /// Create a copy of SonolythImageObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythImageObjectImplCopyWith<_$SonolythImageObjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SonolythPaginationResponseObject<T>
    _$SonolythPaginationResponseObjectFromJson<T>(
        Map<String, dynamic> json, T Function(Object?) fromJsonT) {
  return _SonolythPaginationResponseObject<T>.fromJson(json, fromJsonT);
}

/// @nodoc
mixin _$SonolythPaginationResponseObject<T> {
  int get limit => throw _privateConstructorUsedError;
  int? get nextOffset => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;
  List<T> get items => throw _privateConstructorUsedError;

  /// Serializes this SonolythPaginationResponseObject to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) =>
      throw _privateConstructorUsedError;

  /// Create a copy of SonolythPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythPaginationResponseObjectCopyWith<T,
          SonolythPaginationResponseObject<T>>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythPaginationResponseObjectCopyWith<T, $Res> {
  factory $SonolythPaginationResponseObjectCopyWith(
          SonolythPaginationResponseObject<T> value,
          $Res Function(SonolythPaginationResponseObject<T>) then) =
      _$SonolythPaginationResponseObjectCopyWithImpl<T, $Res,
          SonolythPaginationResponseObject<T>>;
  @useResult
  $Res call(
      {int limit, int? nextOffset, int total, bool hasMore, List<T> items});
}

/// @nodoc
class _$SonolythPaginationResponseObjectCopyWithImpl<T, $Res,
        $Val extends SonolythPaginationResponseObject<T>>
    implements $SonolythPaginationResponseObjectCopyWith<T, $Res> {
  _$SonolythPaginationResponseObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? limit = null,
    Object? nextOffset = freezed,
    Object? total = null,
    Object? hasMore = null,
    Object? items = null,
  }) {
    return _then(_value.copyWith(
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      nextOffset: freezed == nextOffset
          ? _value.nextOffset
          : nextOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythPaginationResponseObjectImplCopyWith<T, $Res>
    implements $SonolythPaginationResponseObjectCopyWith<T, $Res> {
  factory _$$SonolythPaginationResponseObjectImplCopyWith(
          _$SonolythPaginationResponseObjectImpl<T> value,
          $Res Function(_$SonolythPaginationResponseObjectImpl<T>) then) =
      __$$SonolythPaginationResponseObjectImplCopyWithImpl<T, $Res>;
  @override
  @useResult
  $Res call(
      {int limit, int? nextOffset, int total, bool hasMore, List<T> items});
}

/// @nodoc
class __$$SonolythPaginationResponseObjectImplCopyWithImpl<T, $Res>
    extends _$SonolythPaginationResponseObjectCopyWithImpl<T, $Res,
        _$SonolythPaginationResponseObjectImpl<T>>
    implements _$$SonolythPaginationResponseObjectImplCopyWith<T, $Res> {
  __$$SonolythPaginationResponseObjectImplCopyWithImpl(
      _$SonolythPaginationResponseObjectImpl<T> _value,
      $Res Function(_$SonolythPaginationResponseObjectImpl<T>) _then)
      : super(_value, _then);

  /// Create a copy of SonolythPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? limit = null,
    Object? nextOffset = freezed,
    Object? total = null,
    Object? hasMore = null,
    Object? items = null,
  }) {
    return _then(_$SonolythPaginationResponseObjectImpl<T>(
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      nextOffset: freezed == nextOffset
          ? _value.nextOffset
          : nextOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ));
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _$SonolythPaginationResponseObjectImpl<T>
    implements _SonolythPaginationResponseObject<T> {
  _$SonolythPaginationResponseObjectImpl(
      {required this.limit,
      required this.nextOffset,
      required this.total,
      required this.hasMore,
      required final List<T> items})
      : _items = items;

  factory _$SonolythPaginationResponseObjectImpl.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$$SonolythPaginationResponseObjectImplFromJson(json, fromJsonT);

  @override
  final int limit;
  @override
  final int? nextOffset;
  @override
  final int total;
  @override
  final bool hasMore;
  final List<T> _items;
  @override
  List<T> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'SonolythPaginationResponseObject<$T>(limit: $limit, nextOffset: $nextOffset, total: $total, hasMore: $hasMore, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythPaginationResponseObjectImpl<T> &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.nextOffset, nextOffset) ||
                other.nextOffset == nextOffset) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, limit, nextOffset, total,
      hasMore, const DeepCollectionEquality().hash(_items));

  /// Create a copy of SonolythPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythPaginationResponseObjectImplCopyWith<T,
          _$SonolythPaginationResponseObjectImpl<T>>
      get copyWith => __$$SonolythPaginationResponseObjectImplCopyWithImpl<T,
          _$SonolythPaginationResponseObjectImpl<T>>(this, _$identity);

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$$SonolythPaginationResponseObjectImplToJson<T>(this, toJsonT);
  }
}

abstract class _SonolythPaginationResponseObject<T>
    implements SonolythPaginationResponseObject<T> {
  factory _SonolythPaginationResponseObject(
          {required final int limit,
          required final int? nextOffset,
          required final int total,
          required final bool hasMore,
          required final List<T> items}) =
      _$SonolythPaginationResponseObjectImpl<T>;

  factory _SonolythPaginationResponseObject.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =
      _$SonolythPaginationResponseObjectImpl<T>.fromJson;

  @override
  int get limit;
  @override
  int? get nextOffset;
  @override
  int get total;
  @override
  bool get hasMore;
  @override
  List<T> get items;

  /// Create a copy of SonolythPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythPaginationResponseObjectImplCopyWith<T,
          _$SonolythPaginationResponseObjectImpl<T>>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythFullPlaylistObject _$SonolythFullPlaylistObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythFullPlaylistObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythFullPlaylistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  SonolythUserObject get owner => throw _privateConstructorUsedError;
  List<SonolythImageObject> get images => throw _privateConstructorUsedError;
  List<SonolythUserObject> get collaborators =>
      throw _privateConstructorUsedError;
  bool get collaborative => throw _privateConstructorUsedError;
  bool get public => throw _privateConstructorUsedError;

  /// Serializes this SonolythFullPlaylistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythFullPlaylistObjectCopyWith<SonolythFullPlaylistObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythFullPlaylistObjectCopyWith<$Res> {
  factory $SonolythFullPlaylistObjectCopyWith(SonolythFullPlaylistObject value,
          $Res Function(SonolythFullPlaylistObject) then) =
      _$SonolythFullPlaylistObjectCopyWithImpl<$Res,
          SonolythFullPlaylistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SonolythUserObject owner,
      List<SonolythImageObject> images,
      List<SonolythUserObject> collaborators,
      bool collaborative,
      bool public});

  $SonolythUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class _$SonolythFullPlaylistObjectCopyWithImpl<$Res,
        $Val extends SonolythFullPlaylistObject>
    implements $SonolythFullPlaylistObjectCopyWith<$Res> {
  _$SonolythFullPlaylistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
    Object? collaborators = null,
    Object? collaborative = null,
    Object? public = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SonolythUserObject,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      collaborators: null == collaborators
          ? _value.collaborators
          : collaborators // ignore: cast_nullable_to_non_nullable
              as List<SonolythUserObject>,
      collaborative: null == collaborative
          ? _value.collaborative
          : collaborative // ignore: cast_nullable_to_non_nullable
              as bool,
      public: null == public
          ? _value.public
          : public // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of SonolythFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SonolythUserObjectCopyWith<$Res> get owner {
    return $SonolythUserObjectCopyWith<$Res>(_value.owner, (value) {
      return _then(_value.copyWith(owner: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SonolythFullPlaylistObjectImplCopyWith<$Res>
    implements $SonolythFullPlaylistObjectCopyWith<$Res> {
  factory _$$SonolythFullPlaylistObjectImplCopyWith(
          _$SonolythFullPlaylistObjectImpl value,
          $Res Function(_$SonolythFullPlaylistObjectImpl) then) =
      __$$SonolythFullPlaylistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SonolythUserObject owner,
      List<SonolythImageObject> images,
      List<SonolythUserObject> collaborators,
      bool collaborative,
      bool public});

  @override
  $SonolythUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class __$$SonolythFullPlaylistObjectImplCopyWithImpl<$Res>
    extends _$SonolythFullPlaylistObjectCopyWithImpl<$Res,
        _$SonolythFullPlaylistObjectImpl>
    implements _$$SonolythFullPlaylistObjectImplCopyWith<$Res> {
  __$$SonolythFullPlaylistObjectImplCopyWithImpl(
      _$SonolythFullPlaylistObjectImpl _value,
      $Res Function(_$SonolythFullPlaylistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
    Object? collaborators = null,
    Object? collaborative = null,
    Object? public = null,
  }) {
    return _then(_$SonolythFullPlaylistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SonolythUserObject,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      collaborators: null == collaborators
          ? _value._collaborators
          : collaborators // ignore: cast_nullable_to_non_nullable
              as List<SonolythUserObject>,
      collaborative: null == collaborative
          ? _value.collaborative
          : collaborative // ignore: cast_nullable_to_non_nullable
              as bool,
      public: null == public
          ? _value.public
          : public // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythFullPlaylistObjectImpl implements _SonolythFullPlaylistObject {
  _$SonolythFullPlaylistObjectImpl(
      {required this.id,
      required this.name,
      required this.description,
      required this.externalUri,
      required this.owner,
      final List<SonolythImageObject> images = const [],
      final List<SonolythUserObject> collaborators = const [],
      this.collaborative = false,
      this.public = false})
      : _images = images,
        _collaborators = collaborators;

  factory _$SonolythFullPlaylistObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythFullPlaylistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String externalUri;
  @override
  final SonolythUserObject owner;
  final List<SonolythImageObject> _images;
  @override
  @JsonKey()
  List<SonolythImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  final List<SonolythUserObject> _collaborators;
  @override
  @JsonKey()
  List<SonolythUserObject> get collaborators {
    if (_collaborators is EqualUnmodifiableListView) return _collaborators;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_collaborators);
  }

  @override
  @JsonKey()
  final bool collaborative;
  @override
  @JsonKey()
  final bool public;

  @override
  String toString() {
    return 'SonolythFullPlaylistObject(id: $id, name: $name, description: $description, externalUri: $externalUri, owner: $owner, images: $images, collaborators: $collaborators, collaborative: $collaborative, public: $public)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythFullPlaylistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            const DeepCollectionEquality()
                .equals(other._collaborators, _collaborators) &&
            (identical(other.collaborative, collaborative) ||
                other.collaborative == collaborative) &&
            (identical(other.public, public) || other.public == public));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      externalUri,
      owner,
      const DeepCollectionEquality().hash(_images),
      const DeepCollectionEquality().hash(_collaborators),
      collaborative,
      public);

  /// Create a copy of SonolythFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythFullPlaylistObjectImplCopyWith<_$SonolythFullPlaylistObjectImpl>
      get copyWith => __$$SonolythFullPlaylistObjectImplCopyWithImpl<
          _$SonolythFullPlaylistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythFullPlaylistObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythFullPlaylistObject
    implements SonolythFullPlaylistObject {
  factory _SonolythFullPlaylistObject(
      {required final String id,
      required final String name,
      required final String description,
      required final String externalUri,
      required final SonolythUserObject owner,
      final List<SonolythImageObject> images,
      final List<SonolythUserObject> collaborators,
      final bool collaborative,
      final bool public}) = _$SonolythFullPlaylistObjectImpl;

  factory _SonolythFullPlaylistObject.fromJson(Map<String, dynamic> json) =
      _$SonolythFullPlaylistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String get externalUri;
  @override
  SonolythUserObject get owner;
  @override
  List<SonolythImageObject> get images;
  @override
  List<SonolythUserObject> get collaborators;
  @override
  bool get collaborative;
  @override
  bool get public;

  /// Create a copy of SonolythFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythFullPlaylistObjectImplCopyWith<_$SonolythFullPlaylistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythSimplePlaylistObject _$SonolythSimplePlaylistObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythSimplePlaylistObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythSimplePlaylistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  SonolythUserObject get owner => throw _privateConstructorUsedError;
  List<SonolythImageObject> get images => throw _privateConstructorUsedError;

  /// Serializes this SonolythSimplePlaylistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythSimplePlaylistObjectCopyWith<SonolythSimplePlaylistObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythSimplePlaylistObjectCopyWith<$Res> {
  factory $SonolythSimplePlaylistObjectCopyWith(
          SonolythSimplePlaylistObject value,
          $Res Function(SonolythSimplePlaylistObject) then) =
      _$SonolythSimplePlaylistObjectCopyWithImpl<$Res,
          SonolythSimplePlaylistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SonolythUserObject owner,
      List<SonolythImageObject> images});

  $SonolythUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class _$SonolythSimplePlaylistObjectCopyWithImpl<$Res,
        $Val extends SonolythSimplePlaylistObject>
    implements $SonolythSimplePlaylistObjectCopyWith<$Res> {
  _$SonolythSimplePlaylistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SonolythUserObject,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
    ) as $Val);
  }

  /// Create a copy of SonolythSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SonolythUserObjectCopyWith<$Res> get owner {
    return $SonolythUserObjectCopyWith<$Res>(_value.owner, (value) {
      return _then(_value.copyWith(owner: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SonolythSimplePlaylistObjectImplCopyWith<$Res>
    implements $SonolythSimplePlaylistObjectCopyWith<$Res> {
  factory _$$SonolythSimplePlaylistObjectImplCopyWith(
          _$SonolythSimplePlaylistObjectImpl value,
          $Res Function(_$SonolythSimplePlaylistObjectImpl) then) =
      __$$SonolythSimplePlaylistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SonolythUserObject owner,
      List<SonolythImageObject> images});

  @override
  $SonolythUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class __$$SonolythSimplePlaylistObjectImplCopyWithImpl<$Res>
    extends _$SonolythSimplePlaylistObjectCopyWithImpl<$Res,
        _$SonolythSimplePlaylistObjectImpl>
    implements _$$SonolythSimplePlaylistObjectImplCopyWith<$Res> {
  __$$SonolythSimplePlaylistObjectImplCopyWithImpl(
      _$SonolythSimplePlaylistObjectImpl _value,
      $Res Function(_$SonolythSimplePlaylistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
  }) {
    return _then(_$SonolythSimplePlaylistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SonolythUserObject,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythSimplePlaylistObjectImpl
    implements _SonolythSimplePlaylistObject {
  _$SonolythSimplePlaylistObjectImpl(
      {required this.id,
      required this.name,
      required this.description,
      required this.externalUri,
      required this.owner,
      final List<SonolythImageObject> images = const []})
      : _images = images;

  factory _$SonolythSimplePlaylistObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythSimplePlaylistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String externalUri;
  @override
  final SonolythUserObject owner;
  final List<SonolythImageObject> _images;
  @override
  @JsonKey()
  List<SonolythImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  String toString() {
    return 'SonolythSimplePlaylistObject(id: $id, name: $name, description: $description, externalUri: $externalUri, owner: $owner, images: $images)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythSimplePlaylistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            const DeepCollectionEquality().equals(other._images, _images));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description,
      externalUri, owner, const DeepCollectionEquality().hash(_images));

  /// Create a copy of SonolythSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythSimplePlaylistObjectImplCopyWith<
          _$SonolythSimplePlaylistObjectImpl>
      get copyWith => __$$SonolythSimplePlaylistObjectImplCopyWithImpl<
          _$SonolythSimplePlaylistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythSimplePlaylistObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythSimplePlaylistObject
    implements SonolythSimplePlaylistObject {
  factory _SonolythSimplePlaylistObject(
          {required final String id,
          required final String name,
          required final String description,
          required final String externalUri,
          required final SonolythUserObject owner,
          final List<SonolythImageObject> images}) =
      _$SonolythSimplePlaylistObjectImpl;

  factory _SonolythSimplePlaylistObject.fromJson(Map<String, dynamic> json) =
      _$SonolythSimplePlaylistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String get externalUri;
  @override
  SonolythUserObject get owner;
  @override
  List<SonolythImageObject> get images;

  /// Create a copy of SonolythSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythSimplePlaylistObjectImplCopyWith<
          _$SonolythSimplePlaylistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythSearchResponseObject _$SonolythSearchResponseObjectFromJson(
    Map<String, dynamic> json) {
  return _SonolythSearchResponseObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythSearchResponseObject {
  List<SonolythSimpleAlbumObject> get albums =>
      throw _privateConstructorUsedError;
  List<SonolythFullArtistObject> get artists =>
      throw _privateConstructorUsedError;
  List<SonolythSimplePlaylistObject> get playlists =>
      throw _privateConstructorUsedError;
  List<SonolythFullTrackObject> get tracks =>
      throw _privateConstructorUsedError;

  /// Serializes this SonolythSearchResponseObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythSearchResponseObjectCopyWith<SonolythSearchResponseObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythSearchResponseObjectCopyWith<$Res> {
  factory $SonolythSearchResponseObjectCopyWith(
          SonolythSearchResponseObject value,
          $Res Function(SonolythSearchResponseObject) then) =
      _$SonolythSearchResponseObjectCopyWithImpl<$Res,
          SonolythSearchResponseObject>;
  @useResult
  $Res call(
      {List<SonolythSimpleAlbumObject> albums,
      List<SonolythFullArtistObject> artists,
      List<SonolythSimplePlaylistObject> playlists,
      List<SonolythFullTrackObject> tracks});
}

/// @nodoc
class _$SonolythSearchResponseObjectCopyWithImpl<$Res,
        $Val extends SonolythSearchResponseObject>
    implements $SonolythSearchResponseObjectCopyWith<$Res> {
  _$SonolythSearchResponseObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? albums = null,
    Object? artists = null,
    Object? playlists = null,
    Object? tracks = null,
  }) {
    return _then(_value.copyWith(
      albums: null == albums
          ? _value.albums
          : albums // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleAlbumObject>,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythFullArtistObject>,
      playlists: null == playlists
          ? _value.playlists
          : playlists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimplePlaylistObject>,
      tracks: null == tracks
          ? _value.tracks
          : tracks // ignore: cast_nullable_to_non_nullable
              as List<SonolythFullTrackObject>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythSearchResponseObjectImplCopyWith<$Res>
    implements $SonolythSearchResponseObjectCopyWith<$Res> {
  factory _$$SonolythSearchResponseObjectImplCopyWith(
          _$SonolythSearchResponseObjectImpl value,
          $Res Function(_$SonolythSearchResponseObjectImpl) then) =
      __$$SonolythSearchResponseObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<SonolythSimpleAlbumObject> albums,
      List<SonolythFullArtistObject> artists,
      List<SonolythSimplePlaylistObject> playlists,
      List<SonolythFullTrackObject> tracks});
}

/// @nodoc
class __$$SonolythSearchResponseObjectImplCopyWithImpl<$Res>
    extends _$SonolythSearchResponseObjectCopyWithImpl<$Res,
        _$SonolythSearchResponseObjectImpl>
    implements _$$SonolythSearchResponseObjectImplCopyWith<$Res> {
  __$$SonolythSearchResponseObjectImplCopyWithImpl(
      _$SonolythSearchResponseObjectImpl _value,
      $Res Function(_$SonolythSearchResponseObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? albums = null,
    Object? artists = null,
    Object? playlists = null,
    Object? tracks = null,
  }) {
    return _then(_$SonolythSearchResponseObjectImpl(
      albums: null == albums
          ? _value._albums
          : albums // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleAlbumObject>,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythFullArtistObject>,
      playlists: null == playlists
          ? _value._playlists
          : playlists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimplePlaylistObject>,
      tracks: null == tracks
          ? _value._tracks
          : tracks // ignore: cast_nullable_to_non_nullable
              as List<SonolythFullTrackObject>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythSearchResponseObjectImpl
    implements _SonolythSearchResponseObject {
  _$SonolythSearchResponseObjectImpl(
      {required final List<SonolythSimpleAlbumObject> albums,
      required final List<SonolythFullArtistObject> artists,
      required final List<SonolythSimplePlaylistObject> playlists,
      required final List<SonolythFullTrackObject> tracks})
      : _albums = albums,
        _artists = artists,
        _playlists = playlists,
        _tracks = tracks;

  factory _$SonolythSearchResponseObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SonolythSearchResponseObjectImplFromJson(json);

  final List<SonolythSimpleAlbumObject> _albums;
  @override
  List<SonolythSimpleAlbumObject> get albums {
    if (_albums is EqualUnmodifiableListView) return _albums;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_albums);
  }

  final List<SonolythFullArtistObject> _artists;
  @override
  List<SonolythFullArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  final List<SonolythSimplePlaylistObject> _playlists;
  @override
  List<SonolythSimplePlaylistObject> get playlists {
    if (_playlists is EqualUnmodifiableListView) return _playlists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_playlists);
  }

  final List<SonolythFullTrackObject> _tracks;
  @override
  List<SonolythFullTrackObject> get tracks {
    if (_tracks is EqualUnmodifiableListView) return _tracks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tracks);
  }

  @override
  String toString() {
    return 'SonolythSearchResponseObject(albums: $albums, artists: $artists, playlists: $playlists, tracks: $tracks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythSearchResponseObjectImpl &&
            const DeepCollectionEquality().equals(other._albums, _albums) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            const DeepCollectionEquality()
                .equals(other._playlists, _playlists) &&
            const DeepCollectionEquality().equals(other._tracks, _tracks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_albums),
      const DeepCollectionEquality().hash(_artists),
      const DeepCollectionEquality().hash(_playlists),
      const DeepCollectionEquality().hash(_tracks));

  /// Create a copy of SonolythSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythSearchResponseObjectImplCopyWith<
          _$SonolythSearchResponseObjectImpl>
      get copyWith => __$$SonolythSearchResponseObjectImplCopyWithImpl<
          _$SonolythSearchResponseObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythSearchResponseObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythSearchResponseObject
    implements SonolythSearchResponseObject {
  factory _SonolythSearchResponseObject(
          {required final List<SonolythSimpleAlbumObject> albums,
          required final List<SonolythFullArtistObject> artists,
          required final List<SonolythSimplePlaylistObject> playlists,
          required final List<SonolythFullTrackObject> tracks}) =
      _$SonolythSearchResponseObjectImpl;

  factory _SonolythSearchResponseObject.fromJson(Map<String, dynamic> json) =
      _$SonolythSearchResponseObjectImpl.fromJson;

  @override
  List<SonolythSimpleAlbumObject> get albums;
  @override
  List<SonolythFullArtistObject> get artists;
  @override
  List<SonolythSimplePlaylistObject> get playlists;
  @override
  List<SonolythFullTrackObject> get tracks;

  /// Create a copy of SonolythSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythSearchResponseObjectImplCopyWith<
          _$SonolythSearchResponseObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythTrackObject _$SonolythTrackObjectFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'local':
      return SonolythLocalTrackObject.fromJson(json);
    case 'full':
      return SonolythFullTrackObject.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'SonolythTrackObject',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$SonolythTrackObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SonolythSimpleArtistObject> get artists =>
      throw _privateConstructorUsedError;
  SonolythSimpleAlbumObject get album => throw _privateConstructorUsedError;
  int get durationMs => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)
        local,
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)
        full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)?
        full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)?
        full,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SonolythLocalTrackObject value) local,
    required TResult Function(SonolythFullTrackObject value) full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SonolythLocalTrackObject value)? local,
    TResult? Function(SonolythFullTrackObject value)? full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SonolythLocalTrackObject value)? local,
    TResult Function(SonolythFullTrackObject value)? full,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this SonolythTrackObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythTrackObjectCopyWith<SonolythTrackObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythTrackObjectCopyWith<$Res> {
  factory $SonolythTrackObjectCopyWith(
          SonolythTrackObject value, $Res Function(SonolythTrackObject) then) =
      _$SonolythTrackObjectCopyWithImpl<$Res, SonolythTrackObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythSimpleArtistObject> artists,
      SonolythSimpleAlbumObject album,
      int durationMs});

  $SonolythSimpleAlbumObjectCopyWith<$Res> get album;
}

/// @nodoc
class _$SonolythTrackObjectCopyWithImpl<$Res, $Val extends SonolythTrackObject>
    implements $SonolythTrackObjectCopyWith<$Res> {
  _$SonolythTrackObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? album = null,
    Object? durationMs = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      album: null == album
          ? _value.album
          : album // ignore: cast_nullable_to_non_nullable
              as SonolythSimpleAlbumObject,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SonolythSimpleAlbumObjectCopyWith<$Res> get album {
    return $SonolythSimpleAlbumObjectCopyWith<$Res>(_value.album, (value) {
      return _then(_value.copyWith(album: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SonolythLocalTrackObjectImplCopyWith<$Res>
    implements $SonolythTrackObjectCopyWith<$Res> {
  factory _$$SonolythLocalTrackObjectImplCopyWith(
          _$SonolythLocalTrackObjectImpl value,
          $Res Function(_$SonolythLocalTrackObjectImpl) then) =
      __$$SonolythLocalTrackObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythSimpleArtistObject> artists,
      SonolythSimpleAlbumObject album,
      int durationMs,
      String path});

  @override
  $SonolythSimpleAlbumObjectCopyWith<$Res> get album;
}

/// @nodoc
class __$$SonolythLocalTrackObjectImplCopyWithImpl<$Res>
    extends _$SonolythTrackObjectCopyWithImpl<$Res,
        _$SonolythLocalTrackObjectImpl>
    implements _$$SonolythLocalTrackObjectImplCopyWith<$Res> {
  __$$SonolythLocalTrackObjectImplCopyWithImpl(
      _$SonolythLocalTrackObjectImpl _value,
      $Res Function(_$SonolythLocalTrackObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? album = null,
    Object? durationMs = null,
    Object? path = null,
  }) {
    return _then(_$SonolythLocalTrackObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      album: null == album
          ? _value.album
          : album // ignore: cast_nullable_to_non_nullable
              as SonolythSimpleAlbumObject,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythLocalTrackObjectImpl implements SonolythLocalTrackObject {
  _$SonolythLocalTrackObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SonolythSimpleArtistObject> artists = const [],
      required this.album,
      required this.durationMs,
      required this.path,
      final String? $type})
      : _artists = artists,
        $type = $type ?? 'local';

  factory _$SonolythLocalTrackObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythLocalTrackObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SonolythSimpleArtistObject> _artists;
  @override
  @JsonKey()
  List<SonolythSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  @override
  final SonolythSimpleAlbumObject album;
  @override
  final int durationMs;
  @override
  final String path;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SonolythTrackObject.local(id: $id, name: $name, externalUri: $externalUri, artists: $artists, album: $album, durationMs: $durationMs, path: $path)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythLocalTrackObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.path, path) || other.path == path));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, externalUri,
      const DeepCollectionEquality().hash(_artists), album, durationMs, path);

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythLocalTrackObjectImplCopyWith<_$SonolythLocalTrackObjectImpl>
      get copyWith => __$$SonolythLocalTrackObjectImplCopyWithImpl<
          _$SonolythLocalTrackObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)
        local,
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)
        full,
  }) {
    return local(id, name, externalUri, artists, album, durationMs, path);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)?
        full,
  }) {
    return local?.call(id, name, externalUri, artists, album, durationMs, path);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)?
        full,
    required TResult orElse(),
  }) {
    if (local != null) {
      return local(id, name, externalUri, artists, album, durationMs, path);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SonolythLocalTrackObject value) local,
    required TResult Function(SonolythFullTrackObject value) full,
  }) {
    return local(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SonolythLocalTrackObject value)? local,
    TResult? Function(SonolythFullTrackObject value)? full,
  }) {
    return local?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SonolythLocalTrackObject value)? local,
    TResult Function(SonolythFullTrackObject value)? full,
    required TResult orElse(),
  }) {
    if (local != null) {
      return local(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythLocalTrackObjectImplToJson(
      this,
    );
  }
}

abstract class SonolythLocalTrackObject implements SonolythTrackObject {
  factory SonolythLocalTrackObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      final List<SonolythSimpleArtistObject> artists,
      required final SonolythSimpleAlbumObject album,
      required final int durationMs,
      required final String path}) = _$SonolythLocalTrackObjectImpl;

  factory SonolythLocalTrackObject.fromJson(Map<String, dynamic> json) =
      _$SonolythLocalTrackObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SonolythSimpleArtistObject> get artists;
  @override
  SonolythSimpleAlbumObject get album;
  @override
  int get durationMs;
  String get path;

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythLocalTrackObjectImplCopyWith<_$SonolythLocalTrackObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SonolythFullTrackObjectImplCopyWith<$Res>
    implements $SonolythTrackObjectCopyWith<$Res> {
  factory _$$SonolythFullTrackObjectImplCopyWith(
          _$SonolythFullTrackObjectImpl value,
          $Res Function(_$SonolythFullTrackObjectImpl) then) =
      __$$SonolythFullTrackObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SonolythSimpleArtistObject> artists,
      SonolythSimpleAlbumObject album,
      int durationMs,
      String isrc,
      bool explicit,
      String? addedAt});

  @override
  $SonolythSimpleAlbumObjectCopyWith<$Res> get album;
}

/// @nodoc
class __$$SonolythFullTrackObjectImplCopyWithImpl<$Res>
    extends _$SonolythTrackObjectCopyWithImpl<$Res,
        _$SonolythFullTrackObjectImpl>
    implements _$$SonolythFullTrackObjectImplCopyWith<$Res> {
  __$$SonolythFullTrackObjectImplCopyWithImpl(
      _$SonolythFullTrackObjectImpl _value,
      $Res Function(_$SonolythFullTrackObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? album = null,
    Object? durationMs = null,
    Object? isrc = null,
    Object? explicit = null,
    Object? addedAt = freezed,
  }) {
    return _then(_$SonolythFullTrackObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SonolythSimpleArtistObject>,
      album: null == album
          ? _value.album
          : album // ignore: cast_nullable_to_non_nullable
              as SonolythSimpleAlbumObject,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      isrc: null == isrc
          ? _value.isrc
          : isrc // ignore: cast_nullable_to_non_nullable
              as String,
      explicit: null == explicit
          ? _value.explicit
          : explicit // ignore: cast_nullable_to_non_nullable
              as bool,
      addedAt: freezed == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythFullTrackObjectImpl implements SonolythFullTrackObject {
  _$SonolythFullTrackObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SonolythSimpleArtistObject> artists = const [],
      required this.album,
      required this.durationMs,
      required this.isrc,
      required this.explicit,
      this.addedAt,
      final String? $type})
      : _artists = artists,
        $type = $type ?? 'full';

  factory _$SonolythFullTrackObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythFullTrackObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SonolythSimpleArtistObject> _artists;
  @override
  @JsonKey()
  List<SonolythSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  @override
  final SonolythSimpleAlbumObject album;
  @override
  final int durationMs;
  @override
  final String isrc;
  @override
  final bool explicit;
// ISO-8601 timestamp of when the track was added to the collection it was
// fetched from (playlist / liked songs). Null outside those contexts
// (album tracks, search results) and on providers that don't expose it.
  @override
  final String? addedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SonolythTrackObject.full(id: $id, name: $name, externalUri: $externalUri, artists: $artists, album: $album, durationMs: $durationMs, isrc: $isrc, explicit: $explicit, addedAt: $addedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythFullTrackObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.isrc, isrc) || other.isrc == isrc) &&
            (identical(other.explicit, explicit) ||
                other.explicit == explicit) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      externalUri,
      const DeepCollectionEquality().hash(_artists),
      album,
      durationMs,
      isrc,
      explicit,
      addedAt);

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythFullTrackObjectImplCopyWith<_$SonolythFullTrackObjectImpl>
      get copyWith => __$$SonolythFullTrackObjectImplCopyWithImpl<
          _$SonolythFullTrackObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)
        local,
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)
        full,
  }) {
    return full(id, name, externalUri, artists, album, durationMs, isrc,
        explicit, addedAt);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)?
        full,
  }) {
    return full?.call(id, name, externalUri, artists, album, durationMs, isrc,
        explicit, addedAt);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SonolythSimpleArtistObject> artists,
            SonolythSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String? addedAt)?
        full,
    required TResult orElse(),
  }) {
    if (full != null) {
      return full(id, name, externalUri, artists, album, durationMs, isrc,
          explicit, addedAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SonolythLocalTrackObject value) local,
    required TResult Function(SonolythFullTrackObject value) full,
  }) {
    return full(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SonolythLocalTrackObject value)? local,
    TResult? Function(SonolythFullTrackObject value)? full,
  }) {
    return full?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SonolythLocalTrackObject value)? local,
    TResult Function(SonolythFullTrackObject value)? full,
    required TResult orElse(),
  }) {
    if (full != null) {
      return full(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythFullTrackObjectImplToJson(
      this,
    );
  }
}

abstract class SonolythFullTrackObject implements SonolythTrackObject {
  factory SonolythFullTrackObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      final List<SonolythSimpleArtistObject> artists,
      required final SonolythSimpleAlbumObject album,
      required final int durationMs,
      required final String isrc,
      required final bool explicit,
      final String? addedAt}) = _$SonolythFullTrackObjectImpl;

  factory SonolythFullTrackObject.fromJson(Map<String, dynamic> json) =
      _$SonolythFullTrackObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SonolythSimpleArtistObject> get artists;
  @override
  SonolythSimpleAlbumObject get album;
  @override
  int get durationMs;
  String get isrc;
  bool
      get explicit; // ISO-8601 timestamp of when the track was added to the collection it was
// fetched from (playlist / liked songs). Null outside those contexts
// (album tracks, search results) and on providers that don't expose it.
  String? get addedAt;

  /// Create a copy of SonolythTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythFullTrackObjectImplCopyWith<_$SonolythFullTrackObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SonolythUserObject _$SonolythUserObjectFromJson(Map<String, dynamic> json) {
  return _SonolythUserObject.fromJson(json);
}

/// @nodoc
mixin _$SonolythUserObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<SonolythImageObject> get images => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;

  /// Serializes this SonolythUserObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SonolythUserObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SonolythUserObjectCopyWith<SonolythUserObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SonolythUserObjectCopyWith<$Res> {
  factory $SonolythUserObjectCopyWith(
          SonolythUserObject value, $Res Function(SonolythUserObject) then) =
      _$SonolythUserObjectCopyWithImpl<$Res, SonolythUserObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<SonolythImageObject> images,
      String externalUri});
}

/// @nodoc
class _$SonolythUserObjectCopyWithImpl<$Res, $Val extends SonolythUserObject>
    implements $SonolythUserObjectCopyWith<$Res> {
  _$SonolythUserObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SonolythUserObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? images = null,
    Object? externalUri = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SonolythUserObjectImplCopyWith<$Res>
    implements $SonolythUserObjectCopyWith<$Res> {
  factory _$$SonolythUserObjectImplCopyWith(_$SonolythUserObjectImpl value,
          $Res Function(_$SonolythUserObjectImpl) then) =
      __$$SonolythUserObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<SonolythImageObject> images,
      String externalUri});
}

/// @nodoc
class __$$SonolythUserObjectImplCopyWithImpl<$Res>
    extends _$SonolythUserObjectCopyWithImpl<$Res, _$SonolythUserObjectImpl>
    implements _$$SonolythUserObjectImplCopyWith<$Res> {
  __$$SonolythUserObjectImplCopyWithImpl(_$SonolythUserObjectImpl _value,
      $Res Function(_$SonolythUserObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SonolythUserObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? images = null,
    Object? externalUri = null,
  }) {
    return _then(_$SonolythUserObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SonolythImageObject>,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SonolythUserObjectImpl implements _SonolythUserObject {
  _$SonolythUserObjectImpl(
      {required this.id,
      required this.name,
      final List<SonolythImageObject> images = const [],
      required this.externalUri})
      : _images = images;

  factory _$SonolythUserObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SonolythUserObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<SonolythImageObject> _images;
  @override
  @JsonKey()
  List<SonolythImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final String externalUri;

  @override
  String toString() {
    return 'SonolythUserObject(id: $id, name: $name, images: $images, externalUri: $externalUri)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SonolythUserObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name,
      const DeepCollectionEquality().hash(_images), externalUri);

  /// Create a copy of SonolythUserObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SonolythUserObjectImplCopyWith<_$SonolythUserObjectImpl> get copyWith =>
      __$$SonolythUserObjectImplCopyWithImpl<_$SonolythUserObjectImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SonolythUserObjectImplToJson(
      this,
    );
  }
}

abstract class _SonolythUserObject implements SonolythUserObject {
  factory _SonolythUserObject(
      {required final String id,
      required final String name,
      final List<SonolythImageObject> images,
      required final String externalUri}) = _$SonolythUserObjectImpl;

  factory _SonolythUserObject.fromJson(Map<String, dynamic> json) =
      _$SonolythUserObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<SonolythImageObject> get images;
  @override
  String get externalUri;

  /// Create a copy of SonolythUserObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SonolythUserObjectImplCopyWith<_$SonolythUserObjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PluginConfiguration _$PluginConfigurationFromJson(Map<String, dynamic> json) {
  return _PluginConfiguration.fromJson(json);
}

/// @nodoc
mixin _$PluginConfiguration {
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get entryPoint => throw _privateConstructorUsedError;
  String get pluginApiVersion => throw _privateConstructorUsedError;
  List<PluginApis> get apis => throw _privateConstructorUsedError;
  List<PluginAbilities> get abilities => throw _privateConstructorUsedError;
  String? get repository => throw _privateConstructorUsedError;

  /// Serializes this PluginConfiguration to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PluginConfigurationCopyWith<PluginConfiguration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PluginConfigurationCopyWith<$Res> {
  factory $PluginConfigurationCopyWith(
          PluginConfiguration value, $Res Function(PluginConfiguration) then) =
      _$PluginConfigurationCopyWithImpl<$Res, PluginConfiguration>;
  @useResult
  $Res call(
      {String name,
      String description,
      String version,
      String author,
      String entryPoint,
      String pluginApiVersion,
      List<PluginApis> apis,
      List<PluginAbilities> abilities,
      String? repository});
}

/// @nodoc
class _$PluginConfigurationCopyWithImpl<$Res, $Val extends PluginConfiguration>
    implements $PluginConfigurationCopyWith<$Res> {
  _$PluginConfigurationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? version = null,
    Object? author = null,
    Object? entryPoint = null,
    Object? pluginApiVersion = null,
    Object? apis = null,
    Object? abilities = null,
    Object? repository = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      entryPoint: null == entryPoint
          ? _value.entryPoint
          : entryPoint // ignore: cast_nullable_to_non_nullable
              as String,
      pluginApiVersion: null == pluginApiVersion
          ? _value.pluginApiVersion
          : pluginApiVersion // ignore: cast_nullable_to_non_nullable
              as String,
      apis: null == apis
          ? _value.apis
          : apis // ignore: cast_nullable_to_non_nullable
              as List<PluginApis>,
      abilities: null == abilities
          ? _value.abilities
          : abilities // ignore: cast_nullable_to_non_nullable
              as List<PluginAbilities>,
      repository: freezed == repository
          ? _value.repository
          : repository // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PluginConfigurationImplCopyWith<$Res>
    implements $PluginConfigurationCopyWith<$Res> {
  factory _$$PluginConfigurationImplCopyWith(_$PluginConfigurationImpl value,
          $Res Function(_$PluginConfigurationImpl) then) =
      __$$PluginConfigurationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String description,
      String version,
      String author,
      String entryPoint,
      String pluginApiVersion,
      List<PluginApis> apis,
      List<PluginAbilities> abilities,
      String? repository});
}

/// @nodoc
class __$$PluginConfigurationImplCopyWithImpl<$Res>
    extends _$PluginConfigurationCopyWithImpl<$Res, _$PluginConfigurationImpl>
    implements _$$PluginConfigurationImplCopyWith<$Res> {
  __$$PluginConfigurationImplCopyWithImpl(_$PluginConfigurationImpl _value,
      $Res Function(_$PluginConfigurationImpl) _then)
      : super(_value, _then);

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? version = null,
    Object? author = null,
    Object? entryPoint = null,
    Object? pluginApiVersion = null,
    Object? apis = null,
    Object? abilities = null,
    Object? repository = freezed,
  }) {
    return _then(_$PluginConfigurationImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      entryPoint: null == entryPoint
          ? _value.entryPoint
          : entryPoint // ignore: cast_nullable_to_non_nullable
              as String,
      pluginApiVersion: null == pluginApiVersion
          ? _value.pluginApiVersion
          : pluginApiVersion // ignore: cast_nullable_to_non_nullable
              as String,
      apis: null == apis
          ? _value._apis
          : apis // ignore: cast_nullable_to_non_nullable
              as List<PluginApis>,
      abilities: null == abilities
          ? _value._abilities
          : abilities // ignore: cast_nullable_to_non_nullable
              as List<PluginAbilities>,
      repository: freezed == repository
          ? _value.repository
          : repository // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PluginConfigurationImpl extends _PluginConfiguration {
  _$PluginConfigurationImpl(
      {required this.name,
      required this.description,
      required this.version,
      required this.author,
      required this.entryPoint,
      required this.pluginApiVersion,
      final List<PluginApis> apis = const [],
      final List<PluginAbilities> abilities = const [],
      this.repository})
      : _apis = apis,
        _abilities = abilities,
        super._();

  factory _$PluginConfigurationImpl.fromJson(Map<String, dynamic> json) =>
      _$$PluginConfigurationImplFromJson(json);

  @override
  final String name;
  @override
  final String description;
  @override
  final String version;
  @override
  final String author;
  @override
  final String entryPoint;
  @override
  final String pluginApiVersion;
  final List<PluginApis> _apis;
  @override
  @JsonKey()
  List<PluginApis> get apis {
    if (_apis is EqualUnmodifiableListView) return _apis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_apis);
  }

  final List<PluginAbilities> _abilities;
  @override
  @JsonKey()
  List<PluginAbilities> get abilities {
    if (_abilities is EqualUnmodifiableListView) return _abilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_abilities);
  }

  @override
  final String? repository;

  @override
  String toString() {
    return 'PluginConfiguration(name: $name, description: $description, version: $version, author: $author, entryPoint: $entryPoint, pluginApiVersion: $pluginApiVersion, apis: $apis, abilities: $abilities, repository: $repository)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PluginConfigurationImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.entryPoint, entryPoint) ||
                other.entryPoint == entryPoint) &&
            (identical(other.pluginApiVersion, pluginApiVersion) ||
                other.pluginApiVersion == pluginApiVersion) &&
            const DeepCollectionEquality().equals(other._apis, _apis) &&
            const DeepCollectionEquality()
                .equals(other._abilities, _abilities) &&
            (identical(other.repository, repository) ||
                other.repository == repository));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      description,
      version,
      author,
      entryPoint,
      pluginApiVersion,
      const DeepCollectionEquality().hash(_apis),
      const DeepCollectionEquality().hash(_abilities),
      repository);

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PluginConfigurationImplCopyWith<_$PluginConfigurationImpl> get copyWith =>
      __$$PluginConfigurationImplCopyWithImpl<_$PluginConfigurationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PluginConfigurationImplToJson(
      this,
    );
  }
}

abstract class _PluginConfiguration extends PluginConfiguration {
  factory _PluginConfiguration(
      {required final String name,
      required final String description,
      required final String version,
      required final String author,
      required final String entryPoint,
      required final String pluginApiVersion,
      final List<PluginApis> apis,
      final List<PluginAbilities> abilities,
      final String? repository}) = _$PluginConfigurationImpl;
  _PluginConfiguration._() : super._();

  factory _PluginConfiguration.fromJson(Map<String, dynamic> json) =
      _$PluginConfigurationImpl.fromJson;

  @override
  String get name;
  @override
  String get description;
  @override
  String get version;
  @override
  String get author;
  @override
  String get entryPoint;
  @override
  String get pluginApiVersion;
  @override
  List<PluginApis> get apis;
  @override
  List<PluginAbilities> get abilities;
  @override
  String? get repository;

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PluginConfigurationImplCopyWith<_$PluginConfigurationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PluginUpdateAvailable _$PluginUpdateAvailableFromJson(
    Map<String, dynamic> json) {
  return _PluginUpdateAvailable.fromJson(json);
}

/// @nodoc
mixin _$PluginUpdateAvailable {
  String get downloadUrl => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String? get changelog => throw _privateConstructorUsedError;

  /// Serializes this PluginUpdateAvailable to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PluginUpdateAvailableCopyWith<PluginUpdateAvailable> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PluginUpdateAvailableCopyWith<$Res> {
  factory $PluginUpdateAvailableCopyWith(PluginUpdateAvailable value,
          $Res Function(PluginUpdateAvailable) then) =
      _$PluginUpdateAvailableCopyWithImpl<$Res, PluginUpdateAvailable>;
  @useResult
  $Res call({String downloadUrl, String version, String? changelog});
}

/// @nodoc
class _$PluginUpdateAvailableCopyWithImpl<$Res,
        $Val extends PluginUpdateAvailable>
    implements $PluginUpdateAvailableCopyWith<$Res> {
  _$PluginUpdateAvailableCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadUrl = null,
    Object? version = null,
    Object? changelog = freezed,
  }) {
    return _then(_value.copyWith(
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      changelog: freezed == changelog
          ? _value.changelog
          : changelog // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PluginUpdateAvailableImplCopyWith<$Res>
    implements $PluginUpdateAvailableCopyWith<$Res> {
  factory _$$PluginUpdateAvailableImplCopyWith(
          _$PluginUpdateAvailableImpl value,
          $Res Function(_$PluginUpdateAvailableImpl) then) =
      __$$PluginUpdateAvailableImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String downloadUrl, String version, String? changelog});
}

/// @nodoc
class __$$PluginUpdateAvailableImplCopyWithImpl<$Res>
    extends _$PluginUpdateAvailableCopyWithImpl<$Res,
        _$PluginUpdateAvailableImpl>
    implements _$$PluginUpdateAvailableImplCopyWith<$Res> {
  __$$PluginUpdateAvailableImplCopyWithImpl(_$PluginUpdateAvailableImpl _value,
      $Res Function(_$PluginUpdateAvailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadUrl = null,
    Object? version = null,
    Object? changelog = freezed,
  }) {
    return _then(_$PluginUpdateAvailableImpl(
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      changelog: freezed == changelog
          ? _value.changelog
          : changelog // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PluginUpdateAvailableImpl implements _PluginUpdateAvailable {
  _$PluginUpdateAvailableImpl(
      {required this.downloadUrl, required this.version, this.changelog});

  factory _$PluginUpdateAvailableImpl.fromJson(Map<String, dynamic> json) =>
      _$$PluginUpdateAvailableImplFromJson(json);

  @override
  final String downloadUrl;
  @override
  final String version;
  @override
  final String? changelog;

  @override
  String toString() {
    return 'PluginUpdateAvailable(downloadUrl: $downloadUrl, version: $version, changelog: $changelog)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PluginUpdateAvailableImpl &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.changelog, changelog) ||
                other.changelog == changelog));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, downloadUrl, version, changelog);

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PluginUpdateAvailableImplCopyWith<_$PluginUpdateAvailableImpl>
      get copyWith => __$$PluginUpdateAvailableImplCopyWithImpl<
          _$PluginUpdateAvailableImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PluginUpdateAvailableImplToJson(
      this,
    );
  }
}

abstract class _PluginUpdateAvailable implements PluginUpdateAvailable {
  factory _PluginUpdateAvailable(
      {required final String downloadUrl,
      required final String version,
      final String? changelog}) = _$PluginUpdateAvailableImpl;

  factory _PluginUpdateAvailable.fromJson(Map<String, dynamic> json) =
      _$PluginUpdateAvailableImpl.fromJson;

  @override
  String get downloadUrl;
  @override
  String get version;
  @override
  String? get changelog;

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PluginUpdateAvailableImplCopyWith<_$PluginUpdateAvailableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

MetadataPluginRepository _$MetadataPluginRepositoryFromJson(
    Map<String, dynamic> json) {
  return _MetadataPluginRepository.fromJson(json);
}

/// @nodoc
mixin _$MetadataPluginRepository {
  String get name => throw _privateConstructorUsedError;
  String get owner => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get repoUrl => throw _privateConstructorUsedError;
  List<String> get topics => throw _privateConstructorUsedError;

  /// Serializes this MetadataPluginRepository to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetadataPluginRepositoryCopyWith<MetadataPluginRepository> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataPluginRepositoryCopyWith<$Res> {
  factory $MetadataPluginRepositoryCopyWith(MetadataPluginRepository value,
          $Res Function(MetadataPluginRepository) then) =
      _$MetadataPluginRepositoryCopyWithImpl<$Res, MetadataPluginRepository>;
  @useResult
  $Res call(
      {String name,
      String owner,
      String description,
      String repoUrl,
      List<String> topics});
}

/// @nodoc
class _$MetadataPluginRepositoryCopyWithImpl<$Res,
        $Val extends MetadataPluginRepository>
    implements $MetadataPluginRepositoryCopyWith<$Res> {
  _$MetadataPluginRepositoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? owner = null,
    Object? description = null,
    Object? repoUrl = null,
    Object? topics = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      repoUrl: null == repoUrl
          ? _value.repoUrl
          : repoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      topics: null == topics
          ? _value.topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetadataPluginRepositoryImplCopyWith<$Res>
    implements $MetadataPluginRepositoryCopyWith<$Res> {
  factory _$$MetadataPluginRepositoryImplCopyWith(
          _$MetadataPluginRepositoryImpl value,
          $Res Function(_$MetadataPluginRepositoryImpl) then) =
      __$$MetadataPluginRepositoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String owner,
      String description,
      String repoUrl,
      List<String> topics});
}

/// @nodoc
class __$$MetadataPluginRepositoryImplCopyWithImpl<$Res>
    extends _$MetadataPluginRepositoryCopyWithImpl<$Res,
        _$MetadataPluginRepositoryImpl>
    implements _$$MetadataPluginRepositoryImplCopyWith<$Res> {
  __$$MetadataPluginRepositoryImplCopyWithImpl(
      _$MetadataPluginRepositoryImpl _value,
      $Res Function(_$MetadataPluginRepositoryImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? owner = null,
    Object? description = null,
    Object? repoUrl = null,
    Object? topics = null,
  }) {
    return _then(_$MetadataPluginRepositoryImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      repoUrl: null == repoUrl
          ? _value.repoUrl
          : repoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      topics: null == topics
          ? _value._topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MetadataPluginRepositoryImpl implements _MetadataPluginRepository {
  _$MetadataPluginRepositoryImpl(
      {required this.name,
      required this.owner,
      required this.description,
      required this.repoUrl,
      required final List<String> topics})
      : _topics = topics;

  factory _$MetadataPluginRepositoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$MetadataPluginRepositoryImplFromJson(json);

  @override
  final String name;
  @override
  final String owner;
  @override
  final String description;
  @override
  final String repoUrl;
  final List<String> _topics;
  @override
  List<String> get topics {
    if (_topics is EqualUnmodifiableListView) return _topics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topics);
  }

  @override
  String toString() {
    return 'MetadataPluginRepository(name: $name, owner: $owner, description: $description, repoUrl: $repoUrl, topics: $topics)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataPluginRepositoryImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.repoUrl, repoUrl) || other.repoUrl == repoUrl) &&
            const DeepCollectionEquality().equals(other._topics, _topics));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, owner, description,
      repoUrl, const DeepCollectionEquality().hash(_topics));

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataPluginRepositoryImplCopyWith<_$MetadataPluginRepositoryImpl>
      get copyWith => __$$MetadataPluginRepositoryImplCopyWithImpl<
          _$MetadataPluginRepositoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataPluginRepositoryImplToJson(
      this,
    );
  }
}

abstract class _MetadataPluginRepository implements MetadataPluginRepository {
  factory _MetadataPluginRepository(
      {required final String name,
      required final String owner,
      required final String description,
      required final String repoUrl,
      required final List<String> topics}) = _$MetadataPluginRepositoryImpl;

  factory _MetadataPluginRepository.fromJson(Map<String, dynamic> json) =
      _$MetadataPluginRepositoryImpl.fromJson;

  @override
  String get name;
  @override
  String get owner;
  @override
  String get description;
  @override
  String get repoUrl;
  @override
  List<String> get topics;

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataPluginRepositoryImplCopyWith<_$MetadataPluginRepositoryImpl>
      get copyWith => throw _privateConstructorUsedError;
}
