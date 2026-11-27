// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responsi_flutter/main.dart';
import 'package:responsi_flutter/views/location_search_screen.dart';
import 'package:responsi_flutter/views/weather_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'ResponsiWeatherApp mounts WeatherHomeScreen and navigates to LocationSearchScreen',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient mockClient = MockClient(
        (http.Request request) async => http.Response('{}', 200),
      );

      await tester.pumpWidget(
        ResponsiWeatherApp(
          httpClient: mockClient,
          sharedPreferences: prefs,
        ),
      );
      await tester.pumpAndSettle();

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.theme?.useMaterial3, isTrue);
      expect(find.byType(WeatherHomeScreen), findsOneWidget);
      expect(find.byKey(const Key('open_search_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_search_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchScreen), findsOneWidget);
      expect(find.byKey(const Key('search_input_field')), findsOneWidget);
      expect(find.byKey(const Key('search_submit_button')), findsOneWidget);
    },
  );
}
