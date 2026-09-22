import 'package:flutter/material.dart';

import '../../core/constants/countries.dart';

/// Country search + scrollable list, matching edit profile location UX.
class CountryPickerSection extends StatefulWidget {
  const CountryPickerSection({
    super.key,
    required this.selectedCountryCode,
    required this.onCountrySelected,
    this.maxListHeight = 200,
    this.showSectionTitle = true,
  });

  final String? selectedCountryCode;
  final ValueChanged<String> onCountrySelected;
  final double maxListHeight;
  final bool showSectionTitle;

  @override
  State<CountryPickerSection> createState() => _CountryPickerSectionState();
}

class _CountryPickerSectionState extends State<CountryPickerSection> {
  String? _searchQuery;
  final ScrollController _listScrollController = ScrollController();

  static const double _estimatedTileHeight = 56;

  List<Map<String, String>> get _filteredCountries {
    if (_searchQuery == null || _searchQuery!.trim().isEmpty) {
      return countries;
    }
    final q = _searchQuery!.toLowerCase();
    return countries
        .where((c) =>
            c['name']!.toLowerCase().contains(q) ||
            c['code']!.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _scheduleScrollToSelected();
  }

  @override
  void didUpdateWidget(CountryPickerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCountryCode != widget.selectedCountryCode) {
      _scheduleScrollToSelected();
    }
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToSelected() {
    final code = widget.selectedCountryCode;
    if (code == null || code.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCountry(code);
    });
  }

  void _scrollToCountry(String code) {
    final index = _filteredCountries.indexWhere((c) => c['code'] == code);
    if (index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;

      final viewportHeight = _listScrollController.position.viewportDimension;
      final targetOffset = (index * _estimatedTileHeight) -
          (viewportHeight / 2) +
          (_estimatedTileHeight / 2);

      _listScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _listScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _onCountryTap(String code) {
    widget.onCountrySelected(code);
    _scrollToCountry(code);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedCode = widget.selectedCountryCode;
    final selectedCountryName = selectedCode == null || selectedCode.isEmpty
        ? null
        : countryCodeToName(selectedCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSectionTitle) ...[
          Text('Country', style: textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Row(
            children: [
              Icon(
                Icons.public,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCountryName == null
                      ? 'No country selected'
                      : '${countryCodeToFlag(selectedCode!)} $selectedCountryName',
                  style: textTheme.bodyMedium?.copyWith(
                    color: selectedCountryName == null
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontWeight: selectedCountryName == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search country',
            hintText: 'Type to search...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxListHeight),
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              controller: _listScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: ListView.builder(
                controller: _listScrollController,
                shrinkWrap: true,
                itemCount: _filteredCountries.length,
                itemBuilder: (context, index) {
                  final c = _filteredCountries[index];
                  final code = c['code']!;
                  final name = c['name']!;
                  final isSelected = selectedCode == code;
                  return Material(
                    color: isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                        : Colors.transparent,
                    child: ListTile(
                      leading: Text(
                        countryCodeToFlag(code),
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(name),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : null,
                      selected: isSelected,
                      onTap: () => _onCountryTap(code),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
