import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import 'app_info.dart';
import 'haptics.dart';
import 'screens/home.dart';
import 'sound.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final store = AppStore();
  await store.load();
  Sfx.init();
  Haptics.init();
  PackageInfo.fromPlatform()
      .then((info) => AppInfo.version = 'v${info.version} (${info.buildNumber})')
      .catchError((_) => '');
  runApp(PackLiteApp(store: store));
}

class PackLiteApp extends StatelessWidget {
  const PackLiteApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: Consumer<AppStore>(
        builder: (context, s, _) => MaterialApp(
          title: 'Pack Lite',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: harborTheme(Harbor.light, Brightness.light),
          darkTheme: harborTheme(Harbor.dark, Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
