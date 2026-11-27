import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location_model.dart';
import '../viewmodels/search_viewmodel.dart';
import '../viewmodels/weather_viewmodel.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _lastSubmittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch([String? overrideQuery]) {
    final String query = (overrideQuery ?? _searchController.text).trim();
    if (overrideQuery != null) {
      _searchController.text = overrideQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: overrideQuery.length,
      );
    }
    _lastSubmittedQuery = query;
    unawaited(context.read<SearchViewModel>().searchCities(query));
  }

  void _retrySearch() {
    final SearchViewModel viewModel = context.read<SearchViewModel>();
    final String currentText = _searchController.text.trim();
    final String query = currentText.isNotEmpty
        ? currentText
        : (_lastSubmittedQuery.isNotEmpty
              ? _lastSubmittedQuery
              : viewModel.lastQuery);
    _lastSubmittedQuery = query;
    unawaited(viewModel.searchCities(query));
  }

  void _selectLocation(LocationModel location) {
    unawaited(
      context.read<WeatherViewModel>().loadWeatherForLocation(location),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cari Lokasi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Consumer<SearchViewModel>(
        builder: (
          BuildContext context,
          SearchViewModel viewModel,
          Widget? child,
        ) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                  ) {
                    final bool isWide = constraints.maxWidth > 600.0;
                    final bool isCompactHeight = constraints.maxHeight < 180.0;
                    final Widget searchBar = Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: const Key('search_input_field'),
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _submitSearch(),
                            decoration: const InputDecoration(
                              hintText: 'Masukkan nama kota...',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        IconButton.filled(
                          key: const Key('search_submit_button'),
                          tooltip: 'Cari',
                          onPressed: () => _submitSearch(),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    );

                    if (isCompactHeight) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            searchBar,
                            const SizedBox(height: 16.0),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: _buildSearchResultsSection(
                                      context,
                                      viewModel,
                                    ),
                                  ),
                                  const SizedBox(width: 20.0),
                                  Expanded(
                                    child: _buildSecondaryColumn(
                                      context,
                                      viewModel,
                                      gapHeight: 16.0,
                                    ),
                                  ),
                                ],
                              )
                            else
                              _buildNarrowBodyColumn(context, viewModel),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        searchBar,
                        const SizedBox(height: 16.0),
                        Expanded(
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildSearchResultsSection(
                                          context,
                                          viewModel,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20.0),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildSecondaryColumn(
                                          context,
                                          viewModel,
                                          gapHeight: 16.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  child: _buildNarrowBodyColumn(
                                    context,
                                    viewModel,
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecondaryColumn(
    BuildContext context,
    SearchViewModel viewModel, {
    required double gapHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (viewModel.searchHistory.isNotEmpty) ...<Widget>[
          _buildHistorySection(context, viewModel),
          SizedBox(height: gapHeight),
        ],
        _buildFavoritesSection(context, viewModel),
      ],
    );
  }

  Widget _buildNarrowBodyColumn(
    BuildContext context,
    SearchViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSearchResultsSection(context, viewModel),
        if (viewModel.searchHistory.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20.0),
          _buildHistorySection(context, viewModel),
        ],
        const SizedBox(height: 20.0),
        _buildFavoritesSection(context, viewModel),
      ],
    );
  }

  Widget _buildSearchResultsSection(
    BuildContext context,
    SearchViewModel viewModel,
  ) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    switch (viewModel.state) {
      case ViewState.initial:
        return Text(
          'Ketik nama kota lalu tekan cari untuk mencari lokasi.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      case ViewState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(child: CircularProgressIndicator()),
        );
      case ViewState.empty:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Kota tidak ditemukan. Coba kata kunci lain.',
              style: textTheme.bodyMedium,
            ),
          ),
        );
      case ViewState.error:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        viewModel.errorMessage ??
                            'Gagal mencari lokasi. Silakan coba lagi.',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('retry_search_button'),
                    onPressed: _retrySearch,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ),
              ],
            ),
          ),
        );
      case ViewState.loaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Hasil Pencarian', style: textTheme.titleMedium),
            const SizedBox(height: 10.0),
            for (final LocationModel location in viewModel.results)
              _LocationRowTile(
                location: location,
                itemKey: Key('search_result_item_${location.id}'),
                toggleKey: Key('favorite_toggle_${location.id}'),
                isFavorite: viewModel.isFavorite(location.id),
                onTap: () => _selectLocation(location),
                onToggleFavorite: () =>
                    unawaited(viewModel.toggleFavorite(location)),
              ),
          ],
        );
    }
  }

  Widget _buildHistorySection(
    BuildContext context,
    SearchViewModel viewModel,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Riwayat Pencarian', style: textTheme.titleMedium),
        const SizedBox(height: 10.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: viewModel.searchHistory
              .map(
                (String query) => ActionChip(
                  label: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _submitSearch(query),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFavoritesSection(
    BuildContext context,
    SearchViewModel viewModel,
  ) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Lokasi Favorit', style: textTheme.titleMedium),
        const SizedBox(height: 10.0),
        if (viewModel.favorites.isEmpty)
          Text(
            'Belum ada lokasi favorit tersimpan.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final LocationModel location in viewModel.favorites)
            _LocationRowTile(
              location: location,
              itemKey: Key('favorite_item_${location.id}'),
              toggleKey: Key(
                viewModel.state == ViewState.loaded &&
                        viewModel.results.any(
                          (LocationModel r) => r.id == location.id,
                        )
                    ? 'favorite_saved_toggle_${location.id}'
                    : 'favorite_toggle_${location.id}',
              ),
              isFavorite: true,
              onTap: () => _selectLocation(location),
              onToggleFavorite: () =>
                  unawaited(viewModel.toggleFavorite(location)),
            ),
      ],
    );
  }
}

class _LocationRowTile extends StatelessWidget {
  const _LocationRowTile({
    required this.location,
    required this.itemKey,
    required this.toggleKey,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final LocationModel location;
  final Key itemKey;
  final Key toggleKey;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  String? _buildSubtitle() {
    final List<String> parts = <String>[
      if (location.admin1 != null && location.admin1!.trim().isNotEmpty)
        location.admin1!.trim(),
      if (location.country != null && location.country!.trim().isNotEmpty)
        location.country!.trim(),
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;
    final String? subtitle = _buildSubtitle();

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        key: itemKey,
        borderRadius: BorderRadius.circular(16.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14.0,
            vertical: 10.0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      location.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: toggleKey,
                tooltip: isFavorite ? 'Hapus dari favorit' : 'Simpan favorit',
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
