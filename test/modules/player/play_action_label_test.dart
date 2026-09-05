import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/l10n/l10n.dart';
import 'package:sonolyth/modules/player/play_or_verify.dart';

/// The name the play/pause control carries, on the full player's transport and
/// on the mini player's button (CONTEXT item 65).
///
/// While §43's gate holds a queue out of mpv the button runs the verify dialog
/// rather than `resume()`, and the one thing that must not happen is a control
/// doing something other than what it is announced as: a screen reader reads
/// this string, and "Play" that opens a Cloudflare challenge is a worse
/// failure than the dead button it replaced.
void main() {
  late BuildContext context;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  testWidgets('a deferred queue names the action it actually runs',
      (tester) async {
    await pumpHost(tester);

    expect(
      playActionLabel(context, playing: false, deferred: true),
      'Verify lossless',
      reason: 'the same words the meta chip beside it uses',
    );
  });

  testWidgets('an ordinary paused player still says resume', (tester) async {
    await pumpHost(tester);

    expect(
      playActionLabel(context, playing: false, deferred: false),
      AppLocalizations.of(context)!.resume_playback,
    );
  });

  testWidgets('playing wins over deferred', (tester) async {
    await pumpHost(tester);

    // Defensive rather than reachable: the gate only ever holds a queue mpv
    // is not playing. If both are ever true the button must still be the one
    // that stops the sound.
    expect(
      playActionLabel(context, playing: true, deferred: true),
      AppLocalizations.of(context)!.pause_playback,
    );
  });
}
