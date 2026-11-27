// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location_model.dart';
import '../models/weather_model.dart';
import '../utils/weather_code_mapper.dart';
import '../viewmodels/weather_viewmodel.dart';
import 'location_search_screen.dart';

class WeatherHomeScreen extends StatelessWidget {
  const WeatherHomeScreen({super.key});

  void _openSearchScreen(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const LocationSearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherViewModel>(
      builder: (
        BuildContext context,
        WeatherViewModel viewModel,
        Widget? child,
      ) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Responsi Cuaca',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              IconButton(
                key: const Key('refresh_weather_button'),
                tooltip: 'Muat ulang cuaca',
                icon: const Icon(Icons.refresh),
                onPressed:
                    viewModel.selectedLocation == null ||
                        viewModel.state == ViewState.loading
                    ? null
                    : () => viewModel.refreshWeather(),
              ),
              IconButton(
                key: const Key('open_search_button'),
                tooltip: 'Cari lokasi',
                icon: const Icon(Icons.search),
                onPressed: () => _openSearchScreen(context),
              ),
            ],
          ),
          body: _buildBody(context, viewModel),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WeatherViewModel viewModel) {
    switch (viewModel.state) {
      case ViewState.initial:
        return const SizedBox.shrink();
      case ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewState.empty:
        return _EmptyWeatherView(
          onOpenSearch: () => _openSearchScreen(context),
        );
      case ViewState.error:
        return _ErrorWeatherView(
          message:
              viewModel.errorMessage ??
              'Gagal memuat data cuaca. Silakan coba lagi.',
          onRetry: () => viewModel.refreshWeather(),
          onOpenSearch: () => _openSearchScreen(context),
        );
      case ViewState.loaded:
        final LocationModel? location = viewModel.selectedLocation;
        final WeatherModel? weather = viewModel.weather;
        if (location == null || weather == null) {
          return _EmptyWeatherView(
            onOpenSearch: () => _openSearchScreen(context),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth > 600.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880.0),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _CurrentWeatherHeroCard(
                                    location: location,
                                    weather: weather,
                                  ),
                                  const SizedBox(height: 16.0),
                                  _CurrentMetricsSection(weather: weather),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20.0),
                            Expanded(
                              flex: 6,
                              child: _DailyForecastSection(
                                daily: weather.daily,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _CurrentWeatherHeroCard(
                              location: location,
                              weather: weather,
                            ),
                            const SizedBox(height: 16.0),
                            _CurrentMetricsSection(weather: weather),
                            const SizedBox(height: 20.0),
                            _DailyForecastSection(daily: weather.daily),
                          ],
                        ),
                ),
              ),
            );
          },
        );
    }
  }
}

class _EmptyWeatherView extends StatelessWidget {
  const _EmptyWeatherView({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.location_searching,
                size: 56.0,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16.0),
              Text(
                'Belum ada lokasi dipilih',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Cari dan pilih kota untuk menampilkan informasi cuaca terkini dari Open-Meteo.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20.0),
              FilledButton.icon(
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search),
                label: const Text('Cari Lokasi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorWeatherView extends StatelessWidget {
  const _ErrorWeatherView({
    required this.message,
    required this.onRetry,
    required this.onOpenSearch,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.cloud_off,
                    size: 56.0,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20.0),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12.0,
                    runSpacing: 12.0,
                    children: <Widget>[
                      FilledButton.icon(
                        key: const Key('retry_weather_button'),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Ganti Lokasi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentWeatherHeroCard extends StatelessWidget {
  const _CurrentWeatherHeroCard({
    required this.location,
    required this.weather,
  });

  final LocationModel location;
  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;
    final WeatherCodeInfo codeInfo = WeatherCodeMapper.map(
      weather.current.weatherCode,
    );

    final List<String> regionParts = <String>[
      if (location.admin1 != null && location.admin1!.trim().isNotEmpty)
        location.admin1!.trim(),
      if (location.country != null && location.country!.trim().isNotEmpty)
        location.country!.trim(),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              location.name,
              style: textTheme.headlineSmall,
            ),
            if (regionParts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4.0),
              Text(
                regionParts.join(', '),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16.0),
            Row(
              children: <Widget>[
                Icon(
                  codeInfo.icon,
                  size: 52.0,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Text(
                    '${_formatNumber(weather.current.temperature2m)}°C',
                    style: textTheme.displayMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Text(
              codeInfo.description,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 4.0),
            Text(
              'Terasa seperti ${_formatNumber(weather.current.apparentTemperature)}°C',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _CurrentMetricsSection extends StatelessWidget {
  const _CurrentMetricsSection({required this.weather});

  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<_MetricItem> items = <_MetricItem>[
      _MetricItem(
        icon: Icons.water_drop_outlined,
        label: 'Kelembapan',
        value: '${weather.current.relativeHumidity2m}%',
      ),
      _MetricItem(
        icon: Icons.air,
        label: 'Kecepatan Angin',
        value: '${_formatNumber(weather.current.windSpeed10m)} km/h',
      ),
      _MetricItem(
        icon: Icons.grain,
        label: 'Curah Hujan',
        value: '${_formatNumber(weather.current.precipitation)} mm',
      ),
      if (weather.daily.isNotEmpty)
        _MetricItem(
          icon: Icons.umbrella_outlined,
          label: 'Peluang Hujan',
          value: '${weather.daily.first.precipitationProbabilityMax}%',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Detail Cuaca Saat Ini', style: textTheme.titleMedium),
        const SizedBox(height: 10.0),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 340.0 ? 2 : 1;
            final double itemWidth = columns == 2
                ? (constraints.maxWidth - 12.0) / 2.0
                : constraints.maxWidth;
            return Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: items
                  .map(
                    (_MetricItem item) => SizedBox(
                      width: itemWidth,
                      child: _MetricCard(item: item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 18.0,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    item.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              item.value,
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyForecastSection extends StatelessWidget {
  const _DailyForecastSection({required this.daily});

  final List<DailyForecast> daily;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Perkiraan Cuaca Harian', style: textTheme.titleMedium),
        const SizedBox(height: 10.0),
        if (daily.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Data perkiraan harian tidak tersedia.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (int index = 0; index < daily.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 8.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double textScale = MediaQuery.textScalerOf(
                    context,
                  ).scale(1.0);
                  final bool stackCompact =
                      constraints.maxWidth < 220.0 ||
                      (textScale > 1.2 && constraints.maxWidth < 340.0);

                  final Widget dateText = Text(
                    _formatForecastDate(daily[index].date),
                    style: textTheme.bodyLarge,
                  );
                  final Widget rainRow = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.water_drop_outlined,
                        size: 16.0,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          'Hujan ${daily[index].precipitationProbabilityMax}%',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                  final Widget tempText = Text(
                    '${_formatNumber(daily[index].temperature2mMin)}° / ${_formatNumber(daily[index].temperature2mMax)}°',
                    style: textTheme.titleMedium,
                    textAlign: stackCompact ? TextAlign.start : TextAlign.end,
                  );

                  if (stackCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        dateText,
                        const SizedBox(height: 2.0),
                        rainRow,
                        const SizedBox(height: 6.0),
                        tempText,
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            dateText,
                            const SizedBox(height: 2.0),
                            rainRow,
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: tempText,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatNumber(double value) {
  if (value.abs() < 0.05) {
    return '0';
  }
  if (value.truncateToDouble() == value) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _formatForecastDate(String isoDate) {
  final DateTime? parsed = DateTime.tryParse(isoDate);
  if (parsed == null) {
    return isoDate;
  }

  const List<String> weekdays = <String>[
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  return '${weekdays[parsed.weekday - 1]}, ${parsed.day} ${months[parsed.month - 1]}';
}
