import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/l10n/generated/app_localizations.dart';
import 'package:sonolyth/l10n/generated/app_localizations_de.dart';
import 'package:sonolyth/l10n/generated/app_localizations_en.dart';

/// The Stats page counts things, and every string it counted with was a plain
/// interpolation — so a row read "1 plays", the minutes page "1 mins", and a
/// summary card said "6 artist's" at every count, because `summary_artists`
/// was literally the string "artist's".
///
/// The count could not select a branch while it arrived as a
/// `compactNumberFormatter.format(...)` **string**. It is an `int` now, and
/// `format: compact` moved the compact formatting into gen-l10n — which does
/// it per-locale rather than through the app's one locale-less formatter.
void main() {
  final en = AppLocalizationsEn();

  group("counted rows", () {
    test("one play is singular, everything else is not", () {
      expect(en.count_plays(1), "1 play");
      expect(en.count_plays(0), "0 plays");
      expect(en.count_plays(2), "2 plays");
    });

    test("one minute is singular", () {
      expect(en.count_mins(1), "1 min");
      expect(en.count_mins(0), "0 mins");
      expect(en.count_mins(47), "47 mins");
    });

    test("the figure is still compact past a thousand", () {
      expect(en.count_plays(1200), "1.2K plays");
      expect(en.count_mins(2500), "2.5K mins");
    });
  });

  group("summary card units", () {
    // The card draws the figure and the unit as two runs, so these carry no
    // number of their own.
    test("the possessive is gone at every count", () {
      expect(en.summary_artists(1), "artist");
      expect(en.summary_artists(6), "artists");
    });

    test("the other four units agree with their figure", () {
      expect(en.summary_minutes(1), "minute");
      expect(en.summary_minutes(90), "minutes");
      expect(en.summary_songs(1), "song");
      expect(en.summary_songs(3), "songs");
      expect(en.summary_full_albums(1), "full album");
      expect(en.summary_full_albums(3), "full albums");
      expect(en.summary_playlists(1), "playlist");
      expect(en.summary_playlists(3), "playlists");
    });
  });

  group("locales without a plural form", () {
    // gen-l10n gives a translation that never declared a plural a method that
    // takes the count and ignores it, so only the template had to change —
    // the other 29 ARB files are untouched and a translator can add branches
    // to any of them later without a code change.
    final de = AppLocalizationsDe();

    test("keeps its own single form", () {
      expect(de.count_plays(1), "1 Wiedergaben");
      expect(de.summary_artists(1), "Künstler");
    });

    test("and formats its figure the way its own locale does", () {
      // The gain that came free with the plural: the count used to be
      // formatted by one locale-less `NumberFormat.compact()`, so every
      // locale got English's "1.5M". gen-l10n formats per locale.
      expect(de.count_plays(1500000), "1,5 Mio. Wiedergaben");
      expect(en.count_plays(1500000), "1.5M plays");
    });
  });

  group("count_plays_kept — the Settings row's chip", () {
    test("says what is being kept, including nothing", () {
      // The row is disabled at zero, so "No plays" is what a screen reader
      // reads off a chip nobody can act on — it still has to say something.
      expect(en.count_plays_kept(0), "No plays");
      expect(en.count_plays_kept(1), "1 play");
      expect(en.count_plays_kept(63), "63 plays");
    });
  });

  test("every locale answers without throwing", () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final n in [0, 1, 2, 11, 1200]) {
        expect(l.count_plays(n), isNotEmpty, reason: "count_plays $locale $n");
        expect(l.count_mins(n), isNotEmpty, reason: "count_mins $locale $n");
        expect(l.count_plays_kept(n), isNotEmpty,
            reason: "count_plays_kept $locale $n");
        expect(l.summary_artists(n), isNotEmpty,
            reason: "summary_artists $locale $n");
      }
    }
  });
}
