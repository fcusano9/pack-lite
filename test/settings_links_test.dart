import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:pack_lite/links.dart';
import 'package:pack_lite/screens/settings_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// The Settings links point at real, user-facing destinations — one of them at
/// a page that takes money. A typo'd URL can't be hot-fixed once shipped, so
/// these pin both the constants and the wiring.
class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = [];
  bool succeeds = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return succeeds;
  }
}

Widget _wrap(AppStore store) => ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: const SettingsScreen(),
      ),
    );

Future<AppStore> _loadedStore() async {
  final store = AppStore();
  await store.load();
  return store;
}

void main() {
  late _FakeUrlLauncher launcher;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  test('legal links point at the hosted policy pages', () {
    for (final url in [Links.privacyPolicy, Links.termsOfService]) {
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'fcusano9.github.io');
    }
    // The stores reject a policy URL that is really the terms, and vice versa.
    expect(Links.privacyPolicy, isNot(Links.termsOfService));
    expect(Links.privacyPolicy, contains('privacy'));
    expect(Links.termsOfService, contains('terms'));
  });

  testWidgets('the LEGAL rows open their links', (tester) async {
    await tester.pumpWidget(_wrap(await _loadedStore()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Terms of Service'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(launcher.launched, [Links.privacyPolicy]);

    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(launcher.launched.last, Links.termsOfService);
  });

  test('link constants are https URLs on the expected hosts', () {
    final source = Uri.parse(Links.sourceCode);
    final sponsor = Uri.parse(Links.sponsor);

    expect(source.scheme, 'https');
    expect(sponsor.scheme, 'https');
    expect(source.host, 'github.com');
    expect(sponsor.host, 'github.com');
    // Guards against the sponsor row silently pointing at the repo.
    expect(sponsor.path, contains('sponsors'));
    expect(Links.sourceCode, isNot(Links.sponsor));
  });

  testWidgets('the ABOUT rows open their links', (tester) async {
    await tester.pumpWidget(_wrap(await _loadedStore()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sponsor on GitHub'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Source on GitHub'));
    await tester.pumpAndSettle();
    expect(launcher.launched, [Links.sourceCode]);

    await tester.tap(find.text('Sponsor on GitHub'));
    await tester.pumpAndSettle();
    expect(launcher.launched, [Links.sourceCode, Links.sponsor]);
  });

  testWidgets('a link that will not open reports it instead of failing silently',
      (tester) async {
    launcher.succeeds = false;
    await tester.pumpWidget(_wrap(await _loadedStore()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sponsor on GitHub'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sponsor on GitHub'));
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t open the link'), findsOneWidget);
  });
}
