import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/button/back_button.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/components/ui/button_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/blacklist_provider.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class BlackListPage extends HookConsumerWidget {
  static const name = "blacklist";

  const BlackListPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();
    final blacklist = ref.watch(blacklistProvider);
    final searchText = useState("");

    final filteredBlacklist = useMemoized(
      () {
        if (searchText.value.isEmpty) {
          return blacklist.asData?.value ?? [];
        }
        return blacklist.asData?.value
                .map(
                  (e) => (
                    weightedRatio(
                        "${e.name} ${e.elementType.name}", searchText.value),
                    e,
                  ),
                )
                .sorted((a, b) => b.$1.compareTo(a.$1))
                .where((e) => e.$1 > 50)
                .map((e) => e.$2)
                .toList() ??
            [];
      },
      [blacklist, searchText.value],
    );

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            title: Text(context.l10n.blacklist),
            leading: const [BackButton()],
          )
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (value) => searchText.value = value,
                placeholder: Text(context.l10n.search),
                // prefixIcon: const Icon(SonolythIcons.search),
              ),
            ),
            if (blacklist.hasError)
              Expanded(
                child: Center(
                  child: ErrorBox(
                    error: blacklist.error!,
                    onRetry: () {
                      ref.invalidate(blacklistProvider);
                    },
                  ),
                ),
              )
            else if (filteredBlacklist.isEmpty)
              Expanded(
                child: Center(
                  child: Text(context.l10n.nothing_found).muted(),
                ),
              )
            else
              Expanded(
                child: InterScrollbar(
                  controller: controller,
                  child: ListView.builder(
                    controller: controller,
                    itemCount: filteredBlacklist.length,
                    itemBuilder: (context, index) {
                      final item = filteredBlacklist.elementAt(index);
                      return ButtonTile(
                        style: ButtonVariance.ghost,
                        leading: Text("${index + 1}."),
                        title: Text(
                          "${item.name} (${item.elementType.name})",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.elementId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton.ghost(
                          icon: Icon(
                            SonolythIcons.trash,
                            color: context.theme.colorScheme.destructive,
                          ),
                          onPressed: () async {
                            final confirmed = await showPromptDialog(
                              context: context,
                              title: context.l10n.remove_from_blacklist,
                              message: context.l10n.are_you_sure,
                            );
                            if (!confirmed) return;
                            ref
                                .read(blacklistProvider.notifier)
                                .remove(item.elementId);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
