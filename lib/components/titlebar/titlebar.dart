import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/button/back_button.dart';
class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  final bool automaticallyImplyLeading;
  final List<Widget> trailing;
  final List<Widget> leading;
  final Widget? child;
  final Widget? title;
  final Widget? header; // small widget placed on top of title
  final Widget? subtitle; // small widget placed below title
  final bool
      trailingExpanded; // expand the trailing instead of the main content
  final AlignmentGeometry alignment;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? leadingGap;
  final double? trailingGap;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool useSafeArea;
  final double? surfaceBlur;
  final double? surfaceOpacity;

  const TitleBar({
    super.key,
    this.automaticallyImplyLeading = true,
    this.trailing = const [],
    this.leading = const [],
    this.title,
    this.header,
    this.subtitle,
    this.child,
    this.trailingExpanded = false,
    this.alignment = Alignment.center,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.leadingGap,
    this.trailingGap,
    this.height,
    this.surfaceBlur,
    this.surfaceOpacity,
    this.useSafeArea = false,
  });

  /// The bar is 48dp, plus whatever the page title needs above that at the
  /// viewer's system font size.
  ///
  /// A fixed 48 clipped the title at large font scales — 1px at 200%, since
  /// Android 14 scales a 29sp heading far less than a 13sp label, but clipped
  /// all the same and reported on every settings screen (§37). Zero growth at
  /// the default scale, so the skin's 48dp header is untouched.
  double _height(BuildContext context) =>
      height ??
      (48 * context.theme.scaling) +
          zenithLineGrowth(context, zenithPageTitle(context.theme.colorScheme));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canPop = leading.isEmpty &&
              automaticallyImplyLeading &&
              (Navigator.canPop(context) || context.watchRouter.canPop());

          return AppBar(
              leading: canPop ? [const BackButton()] : leading,
              trailing: trailing,
              // Every screen title in the app goes through here, so this is
              // the one place the skin's header type has to be applied:
              // `ItemTextTitle_Text` × `ItemTextTitle_scene_header` = 29sp
              // **normal** weight. Call sites pass a bare `Text` and inherit it.
              title: title == null
                  ? null
                  : DefaultTextStyle.merge(
                      style: zenithPageTitle(context.theme.colorScheme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title!,
                    ),
              header: header,
              subtitle: subtitle,
              trailingExpanded: trailingExpanded,
              alignment: alignment,
              padding: padding ?? EdgeInsets.zero,
              // Page-coloured unless a caller says otherwise. Nothing in Zenith
              // is raised: the skin's list header is `colorBgPrimary`, and
              // every page converted so far passed `Colors.transparent` by
              // hand — the settings family, which did not, wore shadcn's
              // lighter surface band as a result.
              backgroundColor: backgroundColor ?? Colors.transparent,
              leadingGap: leadingGap,
              trailingGap: trailingGap,
              height: _height(context),
              surfaceBlur: surfaceBlur ?? 0,
              surfaceOpacity: surfaceOpacity,
              useSafeArea: useSafeArea,
              child: child,
            );
        },
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height ?? 48);
}
