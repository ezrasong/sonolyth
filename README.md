## Hetu otp_util

A pure otp generator library written in Hetu Script (depends on hetu_std)

Includes following modules:

- HOTP
- TOTP

### Installation

Just add the dependency using pub get:

```
$ flutter pub add hetu_otp_util hetu_std hetu_script
```

### Usage

To load the bindings we provide a `HetuOtpUtilLoader` collection.

```dart
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:hetu_otp_util/hetu_otp_util.dart';

void main() async {
  final hetu = Hetu();
  hetu.init();
  HetuStdLoader.loadBindings(hetu);
  // Loading hetu_std
  await HetuStdLoader.loadBytecodePureDart(
    hetu,
    "~/.pub-cache/hosted/pub.dev/hetu_std-0.1.0",
  );
  await HetuOtpUtilLoader.loadBytecodePureDart(
    hetu,
    "~/.pub-cache/hosted/pub.dev/hetu_otp_util-0.1.0",
  );

  hetu.eval(r"""
    import 'module:std' as std
    import 'module:otp_util' as otp

    var { DateTime } = std
    var { TOTP, OTPAlgorithm, Util } = otp

    final totp = TOTP(
      secret: "ONXW2ZJAOJSWC3DMPEQGO33PMQQHGZLDOJSXI===",
      algorithm: OTPAlgorithm.SHA1,
      digits: 6,
      interval: 30,
    )

    final code = totp.generateOTP(
      input: Util.timeFormat(
        time: DateTime.now(),
        interval: 30,
      ),
    )

    print("OTP Code: ${code}")
    
    final verify = totp.verify(otp: code)

    print("Verify: ${verify}")
  """);
}
```

For Flutter usage:

First add the package assets in your `pubspec.yaml`

```yaml
flutter:
  assets:
    - packages/hetu_std/assets/bytecode/std.out
    - packages/hetu_otp_util/assets/bytecode/otp_util.out
```

Then you can just load it using the helper method that we provide:
```dart
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:hetu_otp_util/hetu_otp_util.dart';

void main() async {
  final hetu = Hetu();
  hetu.init();
  HetuStdLoader.loadBindings(hetu);
  await HetuStdLoader.loadBytecodeFlutter(hetu);
  await HetuOtpUtilLoader.loadBytecodeFlutter(hetu);

  hetu.eval(r"""
    import 'module:std' as std
    import 'module:otp_util' as otp

    var { DateTime } = std
    var { TOTP, OTPAlgorithm, Util } = otp

    final totp = TOTP(
      secret: "ONXW2ZJAOJSWC3DMPEQGO33PMQQHGZLDOJSXI===",
      algorithm: OTPAlgorithm.SHA1,
      digits: 6,
      interval: 30,
    )

    final code = totp.generateOTP(
      input: Util.timeFormat(
        time: DateTime.now(),
        interval: 30,
      ),
    )

    print("OTP Code: ${code}")
    
    final verify = totp.verify(otp: code)

    print("Verify: ${verify}")
  """);
}
```