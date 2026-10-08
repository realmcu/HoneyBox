import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/jw/health/jw_health_goals.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('jw-goals-');
    file = File('${dir.path}/goals.json');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  // Break caught: defaults fabricated, device key omitted, or values not persisted.
  test('absent goals have no defaults and each device survives a fresh store',
      () async {
    final store = JwHealthGoalStore(file);
    expect((await store.read('a')).steps, isNull);
    await store.write('a',
        const JwHealthGoals(steps: 8000, sleepMinutes: 480, energyKcal: 120.5));
    await store.write('b', const JwHealthGoals(steps: 9000));
    final goals = await JwHealthGoalStore(file).read('a');
    expect(goals.steps, 8000);
    expect(goals.sleepMinutes, 480);
    expect(goals.energyKcal, 120.5);
    expect((await JwHealthGoalStore(file).read('b')).steps, 9000);
    expect((await store.read('c')).energyKcal, isNull);
  });
  test(
      'zero negative nonfinite and empty device are rejected before disk change',
      () async {
    final store = JwHealthGoalStore(file);
    await store.write('a', const JwHealthGoals(steps: 3));
    final before = await file.readAsString();
    for (final goals in [
      const JwHealthGoals(steps: 0),
      const JwHealthGoals(sleepMinutes: -1),
      const JwHealthGoals(energyKcal: double.nan),
      const JwHealthGoals(energyKcal: double.infinity)
    ]) {
      await expectLater(store.write('a', goals), throwsArgumentError);
    }
    await expectLater(
        store.write(' ', const JwHealthGoals(steps: 3)), throwsArgumentError);
    expect(await file.readAsString(), before);
  });
  test(
      'concurrent writes preserve both devices and clearing removes percentages',
      () async {
    final store = JwHealthGoalStore(file);
    await Future.wait([
      store.write('a', const JwHealthGoals(steps: 100)),
      store.write('b', const JwHealthGoals(steps: 200))
    ]);
    expect((await store.read('a')).steps, 100);
    expect((await store.read('b')).steps, 200);
    await store.write('a', const JwHealthGoals());
    expect((await store.read('a')).steps, isNull);
  });
  test('corrupt persisted goals fail honestly without overwriting evidence',
      () async {
    await file.writeAsString('{broken');
    await expectLater(JwHealthGoalStore(file).read('a'), throwsFormatException);
    expect(await file.readAsString(), '{broken');
  });
}
