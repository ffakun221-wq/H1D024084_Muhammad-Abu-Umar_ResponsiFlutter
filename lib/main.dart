// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/geocoding_api_service.dart';
import 'services/local_storage_service.dart';
import 'services/weather_api_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/weather_viewmodel.dart';
import 'views/weather_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(ResponsiWeatherApp(sharedPreferences: prefs));
}

class ResponsiWeatherApp extends StatelessWidget {
  const ResponsiWeatherApp({
    super.key,
    this.httpClient,
    this.sharedPreferences,
    this.sharedPreferencesLoader,
  });

  final http.Client? httpClient;
  final SharedPreferences? sharedPreferences;
  final Future<SharedPreferences> Function()? sharedPreferencesLoader;

  @override
  Widget build(BuildContext context) {
    final SharedPreferences? injectedPrefs = sharedPreferences;
    if (injectedPrefs != null) {
      return _buildApp(injectedPrefs);
    }

    return _SharedPreferencesBootstrap(
      loader: sharedPreferencesLoader,
      builder: _buildApp,
    );
  }

  Widget _buildApp(SharedPreferences prefs) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>(
          create: (_) => LocalStorageService(prefs),
        ),
        Provider<WeatherApiService>(
          create: (_) => WeatherApiService(client: httpClient),
          dispose: (_, WeatherApiService service) => service.dispose(),
        ),
        Provider<GeocodingApiService>(
          create: (_) => GeocodingApiService(client: httpClient),
          dispose: (_, GeocodingApiService service) => service.dispose(),
        ),
        ChangeNotifierProvider<WeatherViewModel>(
          lazy: false,
          create: (BuildContext context) => WeatherViewModel(
            weatherService: context.read<WeatherApiService>(),
            storageService: context.read<LocalStorageService>(),
          )..initialize(),
        ),
        ChangeNotifierProvider<SearchViewModel>(
          lazy: false,
          create: (BuildContext context) => SearchViewModel(
            geocodingService: context.read<GeocodingApiService>(),
            storageService: context.read<LocalStorageService>(),
          )..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'Responsi Cuaca',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const WeatherHomeScreen(),
      ),
    );
  }
}

class _SharedPreferencesBootstrap extends StatefulWidget {
  const _SharedPreferencesBootstrap({
    required this.loader,
    required this.builder,
  });

  final Future<SharedPreferences> Function()? loader;
  final Widget Function(SharedPreferences prefs) builder;

  @override
  State<_SharedPreferencesBootstrap> createState() =>
      _SharedPreferencesBootstrapState();
}

class _SharedPreferencesBootstrapState
    extends State<_SharedPreferencesBootstrap> {
  late Future<SharedPreferences> _prefsFuture;

  @override
  void initState() {
    super.initState();
    _prefsFuture = (widget.loader ?? SharedPreferences.getInstance)();
  }

  @override
  void didUpdateWidget(covariant _SharedPreferencesBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loader != oldWidget.loader) {
      _prefsFuture = (widget.loader ?? SharedPreferences.getInstance)();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _prefsFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<SharedPreferences> snapshot,
      ) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Gagal memuat penyimpanan lokal. Silakan muat ulang aplikasi.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }
        final SharedPreferences? resolvedPrefs = snapshot.data;
        if (resolvedPrefs == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return widget.builder(resolvedPrefs);
      },
    );
  }
}
