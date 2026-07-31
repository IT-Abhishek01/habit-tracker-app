# Habitly

Habitly is a complete Flutter habit tracker for planning daily routines, checking off habits, and reviewing weekly momentum.

## Features

- Create, edit, archive, restore, and permanently delete habits.
- Track habits across Morning, Afternoon, Evening, and Night routines.
- Pick weekly goals from 1 to 7 days per habit.
- Mark habits complete for any day in the current week.
- See daily progress, weekly completion, routine balance, best streak, and leading habit.
- Start quickly from built-in habit templates.
- Store habits and settings locally with `shared_preferences`.
- Toggle daily reminders, celebrations, and compact habit cards.

## Project Structure

- `lib/main.dart` contains the app UI, state management, persistence, habit model, templates, and analytics.
- `test/widget_test.dart` verifies that the app opens with mocked local storage.
- `android/app/build.gradle.kts` defines the Android package id: `com.habitly.tracker`.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
flutter test
```

This workspace is configured to use the Flutter SDK at `G:\flutter`.
