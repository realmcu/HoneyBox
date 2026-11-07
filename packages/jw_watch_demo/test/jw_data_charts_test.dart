import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_demo/src/jw_data_catalog.dart';
import 'package:jw_watch_demo/src/jw_data_charts.dart';
import 'package:jw_watch_demo/src/jw_data_units.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

void main() {
  test('units match HL pedometer wire (m / cal)', () {
    expect(jwDataMetersToKm(1500), 1.5);
    expect(jwDataCalToKcal(42000), 42);
    expect(jwDataFormatKm(700), '0.70');
    expect(jwDataFormatKcal(40500), '41');
  });

  test('heart rate day stats build line chart', () {
    final day = DateTime(2026, 11, 6);
    final records = [
      JWHeartRate(time: day.add(const Duration(hours: 8)), heartRate: 72),
      JWHeartRate(time: day.add(const Duration(hours: 12)), heartRate: 90),
      JWHeartRate(time: day.add(const Duration(hours: 18)), heartRate: 80),
    ];
    final stats = jwDataBuildDayStats(
      id: JwDataTypeId.heartRate,
      records: records,
    );
    expect(stats, isNotNull);
    expect(stats!.primary.contains('平均'), isTrue);
    expect(stats.secondary.any((e) => e.contains('最高')), isTrue);
    expect(stats.chart, isA<JwLineChart>());
  });

  test('activity day stats use km/kcal and half-hour bars', () {
    final day = DateTime(2026, 11, 6);
    final records = [
      JWActivity(
        time: day.add(const Duration(hours: 9)),
        steps: 1000,
        distance: 700,
        energy: 40000,
        activeTime: 15,
        mode: 0,
      ),
      JWActivity(
        time: day.add(const Duration(hours: 18)),
        steps: 500,
        distance: 350,
        energy: 20000,
        activeTime: 15,
        mode: 0,
      ),
    ];
    final stats = jwDataBuildDayStats(
      id: JwDataTypeId.activity,
      records: records,
    );
    expect(stats, isNotNull);
    expect(stats!.primary, '1500 步');
    expect(stats.secondary.any((e) => e.contains('1.05 km')), isTrue);
    expect(stats.secondary.any((e) => e.contains('60 kcal')), isTrue);
    expect(stats.chart, isA<JwBarChart>());
  });

  test('blood pressure builds dual-line chart', () {
    final day = DateTime(2026, 11, 6);
    final records = [
      JWBloodPressure(
        time: day.add(const Duration(hours: 8)),
        systolic: 120,
        diastolic: 80,
      ),
      JWBloodPressure(
        time: day.add(const Duration(hours: 20)),
        systolic: 130,
        diastolic: 85,
      ),
    ];
    final stats = jwDataBuildDayStats(
      id: JwDataTypeId.bloodPressure,
      records: records,
    );
    expect(stats!.primary.contains('125/'), isTrue);
    expect(stats.primary.contains('mmHg'), isTrue);
    expect(stats.chart, isA<JwLineChart>());
  });

  test('sleep summarizes light/deep minutes', () {
    final day = DateTime(2026, 11, 6, 22);
    final records = [
      JWSleep(time: day, mode: 1),
      JWSleep(time: day.add(const Duration(hours: 2)), mode: 2),
      JWSleep(time: day.add(const Duration(hours: 5)), mode: 3),
    ];
    final stats = jwDataBuildDayStats(
      id: JwDataTypeId.sleep,
      records: records,
    );
    expect(stats!.primary.contains('5 小时'), isTrue);
    expect(stats.secondary.any((e) => e.contains('浅睡')), isTrue);
    expect(stats.chart, isA<JwSleepStageChart>());
  });

  test('spo2 / temperature / sport also build charts', () {
    final day = DateTime(2026, 11, 6);
    expect(
      jwDataBuildDayStats(
        id: JwDataTypeId.bloodOxygen,
        records: [
          JWBloodOxygen(time: day.add(const Duration(hours: 9)), value: 97),
          JWBloodOxygen(time: day.add(const Duration(hours: 21)), value: 95),
        ],
      )?.chart,
      isA<JwLineChart>(),
    );
    expect(
      jwDataBuildDayStats(
        id: JwDataTypeId.temperature,
        records: [
          JWTemperature(
            time: day.add(const Duration(hours: 9)),
            skinTemperature: 36.5,
            heatStress: 0,
            worn: true,
            compensated: true,
          ),
        ],
      )?.chart,
      isA<JwLineChart>(),
    );
    expect(
      jwDataBuildDayStats(
        id: JwDataTypeId.sport,
        records: [
          JWSport(
            time: day.add(const Duration(hours: 7)),
            mode: 2,
            duration: 1800,
            pauseCount: 0,
            pauseDuration: 0,
            steps: 3000,
            distance: 2500,
            energy: 180000,
          ),
        ],
      )?.chart,
      isA<JwBarChart>(),
    );
  });

  testWidgets('line chart paints without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: JwLineChart(
              points: [
                JwChartPoint(x: 0.2, y: 70),
                JwChartPoint(x: 0.5, y: 95),
                JwChartPoint(x: 0.8, y: 80),
              ],
              yMin: 40,
              yMax: 120,
              lineColor: Color(0xFFFF2D55),
              fillColor: Color(0x33FF2D55),
              xLabels: ['0', '6', '12', '18', '24'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(JwLineChart), findsOneWidget);
  });
}
