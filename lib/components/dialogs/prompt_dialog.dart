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
      // The dialog auto-sizes to its content, so short title/message text would
      // hug-left and not visibly center. Give the content a bounded width and
      // stretch+center it so the text sits centred in the modal.
      final dialogWidth =
          (MediaQuery.sizeOf(context).width - 64).clamp(0.0, 360.0).toDouble();
      return AlertDialog(
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, textAlign: TextAlign.center).large().semiBold(),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
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
