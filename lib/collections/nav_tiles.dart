import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/l10n/l10n.dart';

/// One destination in the app's navigation.
///
/// This was `side_bar_tiles.dart` and a `SideBarTiles` class, and it held a
/// third list — `getSidebarTileList`, Home / Search / Lyrics / Stats — that
/// only the desktop sidebar ever read. The sidebar is gone (§38: Poweramp has
/// no sidebar, no rail and no tablet layout at any width, and the desktop
/// platforms were deleted when the fork was established), so the list went
/// with it and the names say what is left: the **navbar**'s three glyphs and
/// the **library** root's category rows.
class NavTile {
  final IconData icon;
  final String title;
  final String id;
  final String pathPrefix;
  final PageRouteInfo route;

  NavTile({
    required this.icon,
    required this.title,
    required this.id,
    required this.route,
    required this.pathPrefix,
  });
}

List<NavTile> getLibraryTileList(AppLocalizations l10n) => [
      NavTile(
        id: "playlists",
        pathPrefix: "/library/playlists",
        title: l10n.playlists,
        route: const UserPlaylistsRoute(),
        icon: SonolythIcons.playlist,
      ),
      NavTile(
        id: "artists",
        pathPrefix: "/library/artists",
        title: l10n.artists,
        route: const UserArtistsRoute(),
        icon: SonolythIcons.artist,
      ),
      NavTile(
        id: "albums",
        pathPrefix: "/library/albums",
        title: l10n.albums,
        route: const UserAlbumsRoute(),
        icon: SonolythIcons.album,
      ),
      // The route and the page both exist; this entry was the only thing
      // missing, so local files were unreachable from the phone UI entirely
      // (and with them the silence-trim feature, which only covers local +
      // downloaded files).
      NavTile(
        id: "local",
        pathPrefix: "/library/local",
        title: l10n.local_tab,
        route: const UserLocalLibraryRoute(),
        icon: SonolythIcons.folder,
      ),
    ];

List<NavTile> getNavbarTileList(AppLocalizations l10n) => [
      NavTile(
        id: "home",
        pathPrefix: "/home",
        route: const HomeRoute(),
        icon: SonolythIcons.home,
        title: l10n.home,
      ),
      NavTile(
        id: "search",
        pathPrefix: "/search",
        route: const SearchRoute(),
        icon: SonolythIcons.search,
        title: l10n.search,
      ),
      NavTile(
        id: "library",
        pathPrefix: "/library",
        route: const UserPlaylistsRoute(),
        icon: SonolythIcons.library,
        title: l10n.library,
      ),
    ];
