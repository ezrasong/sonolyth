import 'dart:io';

import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:hetu_otp_util/hetu_otp_util.dart';
import 'package:path/path.dart';

void runOtpUtil() async {
  final hetu = Hetu();
  hetu.init();
  HetuStdLoader.loadBindings(hetu);

  // Loading hetu_std
  await HetuStdLoader.loadBytecodePureDart(
    hetu,
    join(Platform.environment["HOME"] as String, "dev/hetu_std"),
  );
  await HetuOtpUtilLoader.loadBytecodePureDart(
    hetu,
    "..",
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