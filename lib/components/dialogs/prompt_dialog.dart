import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/extensions/context.dart';

Future<bool> showPromptDialog({
  required BuildContext context,
  required String title,
  required String message,
  String okText = "Ok",
  String? cancelText = "Cancel",
  // Styles the confirm button red for destructive actions (delete/remove).
  bool destructive = false,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final confirmChild = Text(okText == "Ok" ? context.l10n.ok : okText);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (cancelText != null)
            Button.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                cancelText == "Cancel" ? context.l10n.cancel : cancelText,
              ),
            ),
          if (destructive)
            Button.destructive(
              onPressed: () => Navigator.of(context).pop(true),
              child: confirmChild,
            )
          else
            Button.primary(
              onPressed: () => Navigator.of(context).pop(true),
              child: confirmChild,
            ),
        ],
      );
    },
  ).then((value) => value ?? false);
}
