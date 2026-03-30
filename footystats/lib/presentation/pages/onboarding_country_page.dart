import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/countries.dart';
import '../../data/repositories/user_profile_repository.dart';
import 'home_page.dart';

class OnboardingCountryPage extends StatefulWidget {
  const OnboardingCountryPage({
    super.key,
    required this.email,
    required this.username,
    this.position,
    this.imageUrl,
  });

  final String email;
  final String username;
  final String? position;
  final String? imageUrl;

  @override
  State<OnboardingCountryPage> createState() => _OnboardingCountryPageState();
}

class _OnboardingCountryPageState extends State<OnboardingCountryPage> {
  String? _selectedCountryCode;
  String? _searchQuery;

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

  void _onNext() {
    if (_selectedCountryCode == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingPlayerNamePage(
          email: widget.email,
          username: widget.username,
          position: widget.position,
          imageUrl: widget.imageUrl,
          country: _selectedCountryCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Image.asset(AppAssets.onboardingBg, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Your location',
                            style: textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select your country. This helps connect you with local leagues and players.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Search country',
                              hintText: 'Type to search...',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredCountries.length,
                              itemBuilder: (context, index) {
                                final c = _filteredCountries[index];
                                final code = c['code']!;
                                final name = c['name']!;
                                final isSelected = _selectedCountryCode == code;
                                return ListTile(
                                  leading: Text(
                                    countryCodeToFlag(code),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(name),
                                  selected: isSelected,
                                  onTap: () {
                                    setState(() => _selectedCountryCode = code);
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _selectedCountryCode != null ? _onNext : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPlayerNamePage extends StatefulWidget {
  const OnboardingPlayerNamePage({
    super.key,
    required this.email,
    required this.username,
    this.position,
    this.imageUrl,
    this.country,
  });

  final String email;
  final String username;
  final String? position;
  final String? imageUrl;
  final String? country;

  @override
  State<OnboardingPlayerNamePage> createState() => _OnboardingPlayerNamePageState();
}

class _OnboardingPlayerNamePageState extends State<OnboardingPlayerNamePage> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  bool _isSubmitting = false;
  final _profileRepository = UserProfileRepository();

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await _profileRepository.upsertCurrentProfile(
        username: widget.username,
        playerName: _playerNameController.text.trim(),
        position: widget.position,
        imageUrl: widget.imageUrl,
        country: widget.country,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Image.asset(AppAssets.onboardingBg, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Player name', style: textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              'Give us the name you want on your FootyStats card.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _playerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Player name',
                                hintText: 'e.g. Gareth Munroe',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your player name';
                                if (v.trim().length < 2) return 'At least 2 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _onSubmit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Finish and view dashboard'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
