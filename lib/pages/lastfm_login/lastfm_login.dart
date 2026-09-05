import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/button/back_button.dart';
import 'package:sonolyth/components/ui/zenith_popup_card.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/scrobbler/scrobbler.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class LastFMLoginPage extends HookConsumerWidget {
  static const name = "lastfm_login";
  const LastFMLoginPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrobblerNotifier = ref.read(scrobblerProvider.notifier);

    final usernameKey =
        useMemoized(() => const FormKey<String>("username"), []);
    final passwordKey =
        useMemoized(() => const FormKey<String>("password"), []);

    final passwordVisible = useState(false);

    final isLoading = useState(false);

    return Scaffold(
      headers: const [
        SafeArea(
          bottom: false,
          child: TitleBar(
            leading: [BackButton()],
          ),
        ),
      ],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              // `popup_bg`: flat `popover` at radius 20, no stroke. Data-entry
              // fields inside keep their boxes (Poweramp's own settings
              // dialogs have bordered edit boxes).
              child: ZenithPopupCard(
                margin: EdgeInsets.zero,
                child: Form(
                  onSubmit: (context, values) async {
                    try {
                      isLoading.value = true;
                      await scrobblerNotifier.login(
                        values[usernameKey].trim(),
                        values[passwordKey],
                      );
                      if (context.mounted) {
                        context.back();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showPromptDialog(
                          context: context,
                          title: context.l10n
                              .error(context.l10n.authentication_failed),
                          message: e.toString(),
                          cancelText: null,
                        );
                      }
                    } finally {
                      isLoading.value = false;
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      // Achromatic. The Last.fm red is a brand hue, and the
                      // skin's one sanctioned hue is `destructive`; a bare
                      // glyph at `colorIconPrimary`, like every other icon.
                      Icon(
                        SonolythIcons.lastFm,
                        color: Theme.of(context).colorScheme.primary,
                        size: 60,
                      ),
                      // `DialogTitle_Text` — 19sp bold.
                      Text(
                        "last.fm",
                        style: zenithDialogTitle(Theme.of(context).colorScheme),
                      ),
                      Text(context.l10n.login_with_your_lastfm),
                      AutofillGroup(
                        child: Column(
                          spacing: 10,
                          children: [
                            FormField(
                              label: Text(context.l10n.username),
                              key: usernameKey,
                              validator: NotEmptyValidator(
                                message: context.l10n.username_is_required,
                              ),
                              child: TextField(
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                placeholder: Text(context.l10n.username),
                              ),
                            ),
                            FormField(
                              key: passwordKey,
                              validator: NotEmptyValidator(
                                message: context.l10n.password_is_required,
                              ),
                              label: Text(context.l10n.password),
                              child: TextField(
                                autofillHints: const [
                                  AutofillHints.password,
                                ],
                                obscureText: !passwordVisible.value,
                                placeholder: Text(context.l10n.password),
                                features: [
                                  InputFeature.trailing(
                                    ZenithTooltip(
                                      message: passwordVisible.value
                                          ? context.l10n.hide_password
                                          : context.l10n.show_password,
                                      child: IconButton.ghost(
                                        icon: Icon(
                                          passwordVisible.value
                                              ? SonolythIcons.eye
                                              : SonolythIcons.noEye,
                                        ),
                                        onPressed: () => passwordVisible.value =
                                            !passwordVisible.value,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      FormErrorBuilder(builder: (context, errors, child) {
                        // `DialogPositiveButtonStyle` — see
                        // [zenithPositiveButton].
                        return Button(
                          style: zenithPositiveButton(
                            Theme.of(context).colorScheme,
                          ),
                          onPressed: () => context.submitForm(),
                          enabled: errors.isEmpty && !isLoading.value,
                          child: Text(context.l10n.login),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
