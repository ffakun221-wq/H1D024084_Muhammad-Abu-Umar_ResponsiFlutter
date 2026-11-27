import 'dart:async';
import 'dart:collection';
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/main.dart';
import 'package:responsi_flutter/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef HttpRequestHandler =
    Future<http.Response> Function(http.Request request);

const LocationModel yogyakartaLocation = LocationModel(
  id: 1621177,
  name: 'Yogyakarta',
  latitude: -7.8014,
  longitude: 110.3647,
  country: 'Indonesia',
  admin1: 'Daerah Istimewa Yogyakarta',
);

const LocationModel jakartaLocation = LocationModel(
  id: 1642911,
  name: 'Jakarta',
  latitude: -6.2146,
  longitude: 106.8451,
  country: 'Indonesia',
  admin1: 'Daerah Khusus Ibukota Jakarta',
);

const LocationModel bandungLocation = LocationModel(
  id: 1650357,
  name: 'Bandung',
  latitude: -6.9222,
  longitude: 107.6069,
  country: 'Indonesia',
  admin1: 'Jawa Barat',
);

const LocationModel surabayaLocation = LocationModel(
  id: 1625822,
  name: 'Surabaya',
  latitude: -7.2492,
  longitude: 112.7508,
  country: 'Indonesia',
  admin1: 'Jawa Timur',
);

const LocationModel semarangLocation = LocationModel(
  id: 1627896,
  name: 'Semarang',
  latitude: -6.9932,
  longitude: 110.4203,
  country: 'Indonesia',
  admin1: 'Jawa Tengah',
);

const LocationModel medanLocation = LocationModel(
  id: 1214520,
  name: 'Medan',
  latitude: 3.5833,
  longitude: 98.6667,
  country: 'Indonesia',
  admin1: 'Sumatera Utara',
);

const LocationModel bogorLocation = LocationModel(
  id: 1648473,
  name: 'Bogor',
  latitude: -6.5944,
  longitude: 106.7892,
  country: 'Indonesia',
  admin1: 'Jawa Barat',
);

const LocationModel malangLocation = LocationModel(
  id: 1636722,
  name: 'Malang',
  latitude: -7.9797,
  longitude: 112.6304,
  country: 'Indonesia',
  admin1: 'Jawa Timur',
);

const LocationModel denpasarLocation = LocationModel(
  id: 1645528,
  name: 'Denpasar',
  latitude: -8.65,
  longitude: 115.2167,
  country: 'Indonesia',
  admin1: 'Bali',
);

const LocationModel soloLocation = LocationModel(
  id: 1625812,
  name: 'Surakarta',
  latitude: -7.5561,
  longitude: 110.8317,
  country: 'Indonesia',
  admin1: 'Jawa Tengah',
);

const LocationModel padangLocation = LocationModel(
  id: 1633419,
  name: 'Padang',
  latitude: -0.9492,
  longitude: 100.3543,
  country: 'Indonesia',
  admin1: 'Sumatera Barat',
);

const LocationModel makassarLocation = LocationModel(
  id: 1636714,
  name: 'Makassar',
  latitude: -5.14,
  longitude: 119.4221,
  country: 'Indonesia',
  admin1: 'Sulawesi Selatan',
);

const LocationModel pontianakLocation = LocationModel(
  id: 1630789,
  name: 'Pontianak',
  latitude: -0.0319,
  longitude: 109.325,
  country: 'Indonesia',
  admin1: 'Kalimantan Barat',
);

const LocationModel tokyoLocation = LocationModel(
  id: 1850147,
  name: 'Tokyo',
  latitude: 35.6895,
  longitude: 139.6917,
  country: 'Jepang',
  admin1: 'Tokyo',
);

const LocationModel londonLocation = LocationModel(
  id: 2643743,
  name: 'London',
  latitude: 51.5085,
  longitude: -0.1257,
  country: 'Inggris Raya',
  admin1: 'England',
);

class E2eMockHttpRouter {
  E2eMockHttpRouter({this.onWeather, this.onGeocoding}) {
    client = MockClient(_handleRequest);
  }

  late final MockClient client;
  final List<http.Request> recordedRequests = <http.Request>[];
  final Queue<HttpRequestHandler> weatherQueue = Queue<HttpRequestHandler>();
  final Queue<HttpRequestHandler> geocodingQueue = Queue<HttpRequestHandler>();

  HttpRequestHandler? onWeather;
  HttpRequestHandler? onGeocoding;

  List<http.Request> get weatherRequests => recordedRequests
      .where((http.Request r) => r.url.host == 'api.open-meteo.com')
      .toList(growable: false);

  List<http.Request> get geocodingRequests => recordedRequests
      .where((http.Request r) => r.url.host == 'geocoding-api.open-meteo.com')
      .toList(growable: false);

  void clearRequests() {
    recordedRequests.clear();
  }

  Future<http.Response> _handleRequest(http.Request request) async {
    recordedRequests.add(request);

    if (request.url.host == 'api.open-meteo.com' &&
        request.url.path == '/v1/forecast') {
      if (weatherQueue.isNotEmpty) {
        return weatherQueue.removeFirst()(request);
      }
      final HttpRequestHandler? weatherHandler = onWeather;
      if (weatherHandler != null) {
        return weatherHandler(request);
      }
      return http.Response(weatherResponseBody(), 200);
    }

    if (request.url.host == 'geocoding-api.open-meteo.com' &&
        request.url.path == '/v1/search') {
      if (geocodingQueue.isNotEmpty) {
        return geocodingQueue.removeFirst()(request);
      }
      final HttpRequestHandler? geocodingHandler = onGeocoding;
      if (geocodingHandler != null) {
        return geocodingHandler(request);
      }
      return http.Response(geocodingResponseBody(<Map<String, dynamic>>[]), 200);
    }

    return http.Response(
      jsonEncode(<String, dynamic>{
        'error': true,
        'reason': 'Unexpected URI in E2E Mock: ${request.url}',
      }),
      404,
    );
  }
}

Map<String, dynamic> locationMap({
  required int id,
  required String name,
  required double latitude,
  required double longitude,
  String? country = 'Indonesia',
  String? admin1 = 'Jawa Barat',
  bool includeNullKeys = true,
}) {
  final Map<String, dynamic> map = <String, dynamic>{
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };
  if (country != null || includeNullKeys) {
    map['country'] = country;
  }
  if (admin1 != null || includeNullKeys) {
    map['admin1'] = admin1;
  }
  return map;
}

Map<String, dynamic> locationModelToGeocodingMap(LocationModel loc) {
  return locationMap(
    id: loc.id,
    name: loc.name,
    latitude: loc.latitude,
    longitude: loc.longitude,
    country: loc.country,
    admin1: loc.admin1,
  );
}

String geocodingResponseBody(List<Map<String, dynamic>> results) {
  return jsonEncode(<String, dynamic>{'results': results});
}

String weatherResponseBody({
  double latitude = -7.8014,
  double longitude = 110.3647,
  String timezone = 'Asia/Jakarta',
  double temperature2m = 31.0,
  int relativeHumidity2m = 78,
  double apparentTemperature = 35.0,
  double precipitation = 4.0,
  int weatherCode = 0,
  double windSpeed10m = 14.0,
  List<String> dailyTime = const <String>[
    '2026-11-27',
    '2026-11-28',
    '2026-11-29',
    '2026-11-30',
    '2026-12-01',
    '2026-12-02',
    '2026-12-03',
  ],
  List<double> dailyMax = const <double>[
    33.0,
    34.0,
    36.0,
    37.0,
    38.0,
    39.0,
    41.0,
  ],
  List<double> dailyMin = const <double>[
    24.0,
    23.0,
    22.0,
    21.0,
    19.0,
    18.0,
    17.0,
  ],
  List<int?> dailyPrecipProbMax = const <int?>[65, 55, 45, 75, 85, 95, 15],
}) {
  return jsonEncode(<String, dynamic>{
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'current': <String, dynamic>{
      'temperature_2m': temperature2m,
      'relative_humidity_2m': relativeHumidity2m,
      'apparent_temperature': apparentTemperature,
      'precipitation': precipitation,
      'weather_code': weatherCode,
      'wind_speed_10m': windSpeed10m,
    },
    'daily': <String, dynamic>{
      'time': dailyTime,
      'temperature_2m_max': dailyMax,
      'temperature_2m_min': dailyMin,
      'precipitation_probability_max': dailyPrecipProbMax,
    },
  });
}

void expectValidWeatherGetRequest(
  http.Request req, {
  required double expectedLat,
  required double expectedLon,
}) {
  expect(req.method, equals('GET'));
  expect(req.url.scheme, equals('https'));
  expect(req.url.host, equals('api.open-meteo.com'));
  expect(req.url.path, equals('/v1/forecast'));

  final Map<String, String> params = req.url.queryParameters;
  expect(params['latitude'], equals(expectedLat.toString()));
  expect(params['longitude'], equals(expectedLon.toString()));
  expect(params['timezone'], equals('auto'));

  final List<String> currentVars =
      (params['current'] ?? '').split(',').map((String s) => s.trim()).toList();
  expect(
    currentVars,
    containsAll(<String>[
      'temperature_2m',
      'relative_humidity_2m',
      'apparent_temperature',
      'precipitation',
      'weather_code',
      'wind_speed_10m',
    ]),
  );

  final List<String> dailyVars =
      (params['daily'] ?? '').split(',').map((String s) => s.trim()).toList();
  expect(
    dailyVars,
    containsAll(<String>[
      'temperature_2m_max',
      'temperature_2m_min',
      'precipitation_probability_max',
    ]),
  );
  expect(dailyVars, isNot(contains('weather_code')));
}

void expectValidGeocodingGetRequest(
  http.Request req, {
  required String expectedQuery,
}) {
  expect(req.method, equals('GET'));
  expect(req.url.scheme, equals('https'));
  expect(req.url.host, equals('geocoding-api.open-meteo.com'));
  expect(req.url.path, equals('/v1/search'));

  final Map<String, String> params = req.url.queryParameters;
  expect(params['name'], equals(expectedQuery.trim()));
  expect(params['format'], equals('json'));
  expect(params['language'], equals('id'));
  expect(params['count'], equals('10'));
}

Future<SharedPreferences> pumpWeatherApp(
  WidgetTester tester, {
  required http.Client httpClient,
  SharedPreferences? sharedPreferences,
  Map<String, Object>? initialPrefs,
  bool settle = true,
}) async {
  final SharedPreferences prefs;
  if (sharedPreferences != null) {
    prefs = sharedPreferences;
  } else {
    SharedPreferences.setMockInitialValues(
      initialPrefs ?? const <String, Object>{},
    );
    prefs = await SharedPreferences.getInstance();
  }

  await tester.pumpWidget(
    ResponsiWeatherApp(
      key: UniqueKey(),
      httpClient: httpClient,
      sharedPreferences: prefs,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return prefs;
}

Future<void> restartWeatherApp(
  WidgetTester tester, {
  required http.Client httpClient,
  required SharedPreferences sharedPreferences,
  bool settle = true,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ResponsiWeatherApp(
      key: UniqueKey(),
      httpClient: httpClient,
      sharedPreferences: sharedPreferences,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void setViewportSize(
  WidgetTester tester,
  Size logicalSize, {
  double devicePixelRatio = 1.0,
}) {
  tester.view.physicalSize = logicalSize * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
}

Future<void> withCompleterCleanup(
  WidgetTester tester,
  List<Completer<http.Response>> completers,
  Future<void> Function() body,
) async {
  try {
    await body();
  } finally {
    bool completedAny = false;
    for (final Completer<http.Response> completer in completers) {
      if (!completer.isCompleted) {
        completer.complete(http.Response('{}', 500));
        completedAny = true;
      }
    }
    if (completedAny) {
      await tester.pump();
    }
  }
}

Finder findVerticalScrollables() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is Scrollable) {
      return widget.axisDirection == AxisDirection.down ||
          widget.axisDirection == AxisDirection.up;
    }
    return false;
  });
}

Future<void> scrollUntilTargetVisible(
  WidgetTester tester,
  Finder target, {
  double delta = 200.0,
}) async {
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.first);
    await tester.pump();
    return;
  }
  final Finder verticalScrollables = findVerticalScrollables();
  final int count = verticalScrollables.evaluate().length;
  for (int i = 0; i < count; i++) {
    try {
      await tester.scrollUntilVisible(
        target,
        delta,
        scrollable: verticalScrollables.at(i),
      );
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target.first);
        await tester.pump();
        return;
      }
    } on StateError {
      if (i == count - 1) {
        rethrow;
      }
    }
  }
}

Future<void> ensureAndTap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> tapByKey(
  WidgetTester tester,
  String keyName, {
  bool settle = true,
}) async {
  final Finder finder = find.byKey(Key(keyName));
  if (finder.evaluate().isEmpty &&
      findVerticalScrollables().evaluate().isNotEmpty) {
    await scrollUntilTargetVisible(tester, finder);
  }
  await ensureAndTap(tester, finder.first, settle: settle);
}

Future<void> openSearchScreen(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tapByKey(tester, 'open_search_button', settle: settle);
}

Future<void> submitCitySearch(
  WidgetTester tester,
  String query, {
  bool settle = true,
}) async {
  final Finder field = find.byKey(const Key('search_input_field'));
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, query);
  await tester.pump();
  await tapByKey(tester, 'search_submit_button', settle: settle);
}

Future<void> selectSearchResult(
  WidgetTester tester,
  int locationId, {
  bool settle = true,
}) async {
  await tapByKey(tester, 'search_result_item_$locationId', settle: settle);
}

Finder findFavoriteToggle(int locationId) {
  final Finder scoped = find.descendant(
    of: find.byKey(Key('search_result_item_$locationId')),
    matching: find.byKey(Key('favorite_toggle_$locationId')),
  );
  if (scoped.evaluate().isNotEmpty) {
    return scoped.first;
  }
  return find.byKey(Key('favorite_toggle_$locationId')).first;
}

Future<void> toggleFavoriteForResult(
  WidgetTester tester,
  int locationId, {
  bool settle = true,
}) async {
  final Finder rawKeyFinder = find.byKey(Key('favorite_toggle_$locationId'));
  if (rawKeyFinder.evaluate().isEmpty &&
      findVerticalScrollables().evaluate().isNotEmpty) {
    await scrollUntilTargetVisible(tester, rawKeyFinder);
  }
  await ensureAndTap(tester, findFavoriteToggle(locationId), settle: settle);
}

Future<void> selectFavoriteItem(
  WidgetTester tester,
  int locationId, {
  bool settle = true,
}) async {
  await tapByKey(tester, 'favorite_item_$locationId', settle: settle);
}

Future<void> navigateBackToHome(WidgetTester tester) async {
  final Finder backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
    await tester.pumpAndSettle();
    return;
  }
  final Finder backTooltip = find.byTooltip('Back');
  if (backTooltip.evaluate().isNotEmpty) {
    await tester.tap(backTooltip.first);
    await tester.pumpAndSettle();
    return;
  }
  final Finder scaffolds = find.byType(Scaffold);
  if (scaffolds.evaluate().isNotEmpty) {
    await Navigator.of(tester.element(scaffolds.last)).maybePop();
    await tester.pumpAndSettle();
  }
}

Finder findSearchResultItems() {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('search_result_item_');
  });
}

Finder findFavoriteItems() {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('favorite_item_');
  });
}

Finder findProgressIndicators() {
  return find.byWidgetPredicate((Widget widget) => widget is ProgressIndicator);
}

Finder findDisplayedNumber(String numberStr) {
  final String escaped = RegExp.escape(numberStr);
  final RegExp pattern = RegExp('(^|[^0-9.-])$escaped([.,]0+)?([^0-9]|\$)');
  return find.byWidgetPredicate((Widget widget) {
    if (widget is Text) {
      final String content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      return pattern.hasMatch(content);
    }
    return false;
  });
}

Finder findDisplayedNumberPattern(String rawPattern) {
  final RegExp anchored = RegExp('(^|[^0-9.-])(?:$rawPattern)([^0-9]|\$)');
  return find.byWidgetPredicate((Widget widget) {
    if (widget is Text) {
      final String content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      return anchored.hasMatch(content);
    }
    return false;
  });
}

Finder findDisplayedPattern(RegExp pattern) {
  return findDisplayedNumberPattern(pattern.pattern);
}

bool isFrameworkRouteWrapper(Widget widget) {
  final String name = widget.runtimeType.toString();
  const Set<String> exactWrappers = <String>{
    'Semantics',
    'Builder',
    'RepaintBoundary',
    'IgnorePointer',
    'ListenableBuilder',
    'FractionalTranslation',
    'SlideTransition',
    'FadeTransition',
    'DualTransitionBuilder',
    'ColoredBox',
    'AnimatedBuilder',
    '_FadeForwardsPageTransition',
    '_PredictiveBackGestureDetector',
    '_FocusInheritedScope',
    '_FocusScopeWithExternalFocusNode',
    'PrimaryScrollController',
    '_ActionsScope',
    'Actions',
    'PageStorage',
    'Offstage',
    '_ModalScopeStatus',
    'UnmanagedRestorationScope',
    'RestorationScope',
    '_RenderTheaterMarker',
    '_EffectiveTickerMode',
    'TickerMode',
    '_OverlayEntryWidget',
    '_Theater',
    'Overlay',
    'Focus',
    'FocusTraversalGroup',
    'AbsorbPointer',
    'Listener',
    'HeroControllerScope',
    'Navigator',
    'CupertinoPageTransition',
    'ZoomPageTransition',
    'FadeUpwardsPageTransitionsBuilder',
    'MultiProvider',
    'SafeArea',
    'MediaQuery',
    'Theme',
    'AnimatedTheme',
    'Localizations',
    'Directionality',
    'ScrollConfiguration',
    'DefaultTextStyle',
    'IconTheme',
    'MaterialApp',
    'Scaffold',
  };
  if (exactWrappers.contains(name)) {
    return true;
  }
  const List<String> genericPrefixes = <String>[
    '_PageTransitionsThemeTransitions<',
    '_ModalScope<',
    'NotificationListener<',
    'Consumer<',
    'Consumer2<',
    'Selector<',
    'Provider<',
    'InheritedProvider<',
    'ChangeNotifierProvider<',
    'ProxyProvider<',
  ];
  for (final String prefix in genericPrefixes) {
    if (name.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

List<Widget> collectAppScaffoldAncestors(WidgetTester tester) {
  final Set<Widget> appWidgets = LinkedHashSet<Widget>.identity();
  for (final Element scaffoldElement
      in find.byType(Scaffold, skipOffstage: false).evaluate()) {
    scaffoldElement.visitAncestorElements((Element ancestor) {
      final Widget widget = ancestor.widget;
      if (!isFrameworkRouteWrapper(widget)) {
        appWidgets.add(widget);
      }
      return widget is! Navigator;
    });
  }
  return appWidgets.toList();
}

Set<String> collectAllDisplayedTexts(WidgetTester tester) {
  final Set<String> texts = <String>{};
  for (final Element element in find.byType(Text).evaluate()) {
    final Widget widget = element.widget;
    if (widget is Text) {
      final String content = (widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .trim();
      if (content.isNotEmpty) {
        texts.add(content);
      }
    }
  }
  return texts;
}

Set<IconData> collectAllDisplayedIcons(WidgetTester tester) {
  final Set<IconData> icons = <IconData>{};
  for (final Element element in find.byType(Icon).evaluate()) {
    final Widget widget = element.widget;
    if (widget is Icon && widget.icon != null) {
      icons.add(widget.icon!);
    }
  }
  return icons;
}
