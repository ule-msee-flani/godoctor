// Self-care practices (grid, topics, the practice player, breathing) and the
// new feelings in the mood check-in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/features/patient/home/mood_check_in.dart';
import 'package:godoctor_app/features/selfcare/selfcare_content.dart';
import 'package:godoctor_app/features/selfcare/selfcare_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  await _pump(tester);
}

void main() {
  group('content', () {
    test('every practice has an id of its own, steps and a time', () {
      final ids = <String>{};
      for (final t in kCareTopics) {
        expect(t.items, isNotEmpty, reason: t.id);
        for (final i in t.items) {
          expect(ids.add(i.id), isTrue, reason: 'duplicate ${i.id}');
          expect(i.steps, isNotEmpty, reason: i.id);
          expect(i.minutes, greaterThan(0), reason: i.id);
          if (i.breathing case final b?) {
            expect(b.inhale, greaterThan(0));
            expect(b.exhale, greaterThan(0));
            expect(b.rounds, greaterThan(0));
          }
        }
      }
      expect(careItem('box-breathing')?.$1.id, 'regulate-emotions');
      expect(careTopic('healthy-sleep')?.countLabel, '5 practices');
      expect(careTopic('water')?.countLabel, '4 tips');
      expect(careTopic('blood-pressure')?.countLabel, '5 sections');
    });

    test('what Home suggests: by feeling, then by the time of day', () {
      final evening = DateTime(2026, 10, 1, 21);
      final oddMidday = DateTime(2026, 1, 2, 12); // day 1 of the year
      final evenMorning = DateTime(2026, 1, 3, 8); // day 2
      expect(
        suggestPractice(oddMidday, mood: 'anxious')?.$2.id,
        'calm-breathing',
      );
      expect(suggestPractice(oddMidday, mood: 'angry')?.$2.id, 'cool-down');
      expect(suggestPractice(evening)?.$2.id, 'wind-down');
      expect(suggestPractice(oddMidday), isNull, reason: 'not every day');
      expect(suggestPractice(evenMorning)?.$2.id, 'morning-light');
    });

    test('moods: saved names, including the first set', () {
      expect(Mood.underTheWeather.key, 'under_the_weather');
      expect(moodFromKey('under_the_weather'), Mood.underTheWeather);
      expect(moodFromKey('great'), Mood.happy);
      expect(moodFromKey('low'), Mood.sad);
      expect(moodFromKey('unwell'), Mood.underTheWeather);
      expect(moodFromKey('nonsense'), isNull);
    });
  });

  testWidgets('every feeling draws its shape', (tester) async {
    await _host(
      tester,
      Scaffold(
        body: Wrap(children: [for (final m in Mood.values) MoodGlyph(mood: m)]),
      ),
    );
    expect(find.byType(MoodGlyph), findsNWidgets(Mood.values.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('self-care: grid, the featured card, and filters', (
    tester,
  ) async {
    await _host(tester, const SelfCareScreen());
    expect(find.text('Self-care practices'), findsOneWidget);
    for (final chip in ['All', 'Practices', 'Tips', 'Guides']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('Regulate your emotions'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Healthy sleep'), findsOneWidget);
    expect(find.text('5 practices'), findsWidgets);

    await tester.ensureVisible(find.text('Guides'));
    await tester.tap(find.text('Guides'));
    await _pump(tester);
    expect(find.text('Managing stress'), findsOneWidget);
    expect(find.text('Healthy sleep'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a topic lists its practices, with a link where it helps', (
    tester,
  ) async {
    await _host(tester, const SelfCareTopicScreen(topicId: 'blood-pressure'));
    expect(find.text('Living with high blood pressure'), findsOneWidget);
    expect(find.text('Log your blood pressure'), findsOneWidget);
    expect(find.text('Know your numbers'), findsOneWidget);
    expect(find.textContaining('min · Read'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a practice goes a step at a time, then "nicely done"', (
    tester,
  ) async {
    await _host(tester, const PracticeScreen(itemId: 'name-it'));
    expect(find.text('Name it to tame it'), findsOneWidget);
    expect(
      find.text('Pause and notice what you feel in your body.'),
      findsOneWidget,
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await _pump(tester, 5);
    }
    expect(find.textContaining('feelings rise and fall'), findsOneWidget);
    await tester.tap(find.text('I did it'));
    await _pump(tester);
    expect(find.text('Nicely done.'), findsOneWidget);
    expect(find.text('Next: Pause and cool down'), findsOneWidget);
    final log = await SelfCareLog.load();
    expect(log.doneIds, contains('name-it'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('breathing: the circle leads you in and out', (tester) async {
    await _host(tester, const PracticeScreen(itemId: 'calm-breathing'));
    expect(find.text('Ready when you are'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Carry on'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
