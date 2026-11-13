import "dart:io";
import "package:material_ui/material_ui.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

import "data/bookmark_store.dart";
import "data/dictionary_session.dart";
import "screens/home_screen.dart";
import "theme.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final session = await DictionarySession.open();
  final bookmarks = await BookmarkStore.open();
  runApp(PunzhDictApp(session: session, bookmarks: bookmarks));
}

class PunzhDictApp extends StatelessWidget {
  const PunzhDictApp({
    super.key,
    required this.session,
    required this.bookmarks,
  });

  final DictionarySession session;
  final BookmarkStore bookmarks;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Словарь Пунжиной",
      theme: buildPunzhTheme(),
      // UI is always the light dictionary chrome; do not follow OS dark mode
      // (that washed out status-bar icons on the light drawer strip).
      themeMode: ThemeMode.light,
      home: HomeScreen(session: session, bookmarks: bookmarks),
    );
  }
}
