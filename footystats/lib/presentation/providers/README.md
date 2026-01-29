# Providers

This directory contains Riverpod providers for state management.

## Structure

- `navigation_provider.dart` - Manages navigation state (selected tab index)
- `home_provider.dart` - Manages home page specific state (selected team, etc.)

## Usage

Providers follow Riverpod best practices:
- Use `StateProvider` for simple state
- Use `StateNotifierProvider` for complex state with business logic
- Use `FutureProvider` or `StreamProvider` for async data

## Example

```dart
// Reading a provider
final selectedTeam = ref.watch(selectedTeamProvider);

// Updating a provider
ref.read(selectedTeamProvider.notifier).state = 'Lefters';
```
