# Ballo - Clean Architecture Structure

This project follows **Clean Architecture** principles with **Riverpod** for state management and **Supabase** for backend services.

## 📁 Folder Structure

```
lib/
├── core/                    # Core functionality shared across the app
│   ├── constants/          # App-wide constants
│   │   ├── app_assets.dart      # Asset path constants
│   │   └── app_constants.dart   # App-wide constants
│   ├── theme/              # Theme configuration
│   │   └── theme.dart
│   ├── utils/              # Utility functions
│   │   └── util.dart
│   └── widgets/            # Reusable widgets
│       └── progress_ring.dart
│
├── data/                   # Data layer (external data sources)
│   ├── models/             # Data models (DTOs)
│   ├── repositories/        # Repository implementations
│   └── datasources/        # Data sources
│       ├── local/          # Local storage (Hive, SharedPreferences, etc.)
│       └── remote/         # Remote APIs (Supabase)
│           └── supabase_client.dart
│
├── domain/                 # Business logic layer
│   ├── entities/          # Domain entities (business objects)
│   ├── repositories/      # Repository interfaces (contracts)
│   └── usecases/          # Business logic use cases
│
├── presentation/          # UI layer
│   ├── pages/             # Screen pages
│   │   ├── home_page.dart
│   │   ├── matches.dart
│   │   ├── leaderboard.dart
│   │   ├── explore.dart
│   │   ├── profile.dart
│   │   └── settings.dart
│   ├── widgets/          # UI widgets
│   │   └── home/         # Home page specific widgets
│   │       ├── challenge_widget.dart
│   │       ├── gameweek_header.dart
│   │       ├── match_card.dart
│   │       ├── performance_chart.dart
│   │       └── team_chip.dart
│   └── providers/        # Riverpod providers
│       ├── navigation_provider.dart
│       └── home_provider.dart
│
└── main.dart              # App entry point
```

## 🎯 Architecture Layers

### 1. **Core Layer** (`core/`)
Contains shared utilities, constants, themes, and reusable widgets that don't depend on business logic.

### 2. **Data Layer** (`data/`)
- **Models**: Data Transfer Objects (DTOs) that match API responses
- **Repositories**: Implementations of domain repository interfaces
- **Data Sources**: 
  - **Remote**: Supabase client and API calls
  - **Local**: Local storage (caching, preferences)

### 3. **Domain Layer** (`domain/`)
- **Entities**: Pure business objects (no dependencies on Flutter or external packages)
- **Repository Interfaces**: Contracts that define data operations
- **Use Cases**: Business logic operations (e.g., `GetUserStats`, `CreateMatch`)

### 4. **Presentation Layer** (`presentation/`)
- **Pages**: Full screen widgets (screens)
- **Widgets**: Reusable UI components
- **Providers**: Riverpod state management

## 📦 Assets Organization

Assets are organized by type:
```
lib/assets/
├── icons/          # SVG icons
│   ├── badges/
│   ├── match control icons/
│   └── stats table/
├── images/         # PNG, JPG images
│   ├── avatars/
│   ├── team logos/
│   └── trophies/
└── videos/         # Video files
```

## 🔄 Data Flow

1. **UI** → Calls **Provider** (Riverpod)
2. **Provider** → Calls **Use Case** (Domain)
3. **Use Case** → Calls **Repository Interface** (Domain)
4. **Repository Implementation** (Data) → Calls **Data Source** (Supabase/Local)
5. Data flows back: **Data Source** → **Repository** → **Use Case** → **Provider** → **UI**

## 🚀 Getting Started

### 1. Initialize Supabase

In `main.dart`, uncomment and configure Supabase:

```dart
await SupabaseClient.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 2. Create Domain Entities

Define your business entities in `domain/entities/`:

```dart
// domain/entities/match.dart
class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  // ...
}
```

### 3. Create Repository Interfaces

Define contracts in `domain/repositories/`:

```dart
// domain/repositories/match_repository.dart
abstract class MatchRepository {
  Future<List<Match>> getMatches();
  Future<Match> getMatchById(String id);
}
```

### 4. Implement Repositories

Implement in `data/repositories/`:

```dart
// data/repositories/match_repository_impl.dart
class MatchRepositoryImpl implements MatchRepository {
  final SupabaseClient _supabase;
  
  @override
  Future<List<Match>> getMatches() async {
    // Supabase implementation
  }
}
```

### 5. Create Use Cases

Business logic in `domain/usecases/`:

```dart
// domain/usecases/get_matches.dart
class GetMatches {
  final MatchRepository _repository;
  
  Future<Either<Failure, List<Match>>> call() async {
    // Business logic
  }
}
```

### 6. Create Providers

State management in `presentation/providers/`:

```dart
// presentation/providers/match_provider.dart
final matchesProvider = FutureProvider<List<Match>>((ref) async {
  final getMatches = GetMatches(ref.read(matchRepositoryProvider));
  return getMatches();
});
```

## 📝 Best Practices

1. **Dependency Rule**: Inner layers don't know about outer layers
   - Domain doesn't import Data or Presentation
   - Data doesn't import Presentation

2. **Single Responsibility**: Each class/widget has one job

3. **Use Constants**: Always use `AppAssets` for asset paths

4. **Provider Naming**: Use descriptive names ending with `Provider`

5. **Widget Extraction**: Extract reusable widgets to `presentation/widgets/`

6. **Error Handling**: Use `Either<Failure, T>` or `Result<T>` for error handling

## 🔧 Adding New Features

1. Create domain entity
2. Create repository interface
3. Implement repository with Supabase
4. Create use case
5. Create provider
6. Create UI widgets/pages
7. Wire everything together

## 📚 Resources

- [Riverpod Documentation](https://riverpod.dev/)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
