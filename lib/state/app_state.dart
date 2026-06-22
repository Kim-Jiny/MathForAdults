import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/content_repository.dart';
import '../models/concept_card.dart';
import '../models/curriculum_index.dart';
import '../models/math_problem.dart';
import '../models/user_stats.dart';
import '../services/notification_service.dart';

// ───────────────────────── 영속화 ─────────────────────────

/// main()에서 override 됨.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('main에서 override 필요'),
);

const _kStatsKey = 'user_stats_v1';
const _kSettingsKey = 'settings_v1';

// ───────────────────────── 콘텐츠 ─────────────────────────

final contentRepositoryProvider = Provider<ContentRepository>(
  (_) => ContentRepository(),
);

/// 메타데이터 인덱스 (시작 시 1회 로드). 탐색 화면이 watch.
final curriculumIndexProvider = FutureProvider<CurriculumIndex>(
  (ref) => ref.watch(contentRepositoryProvider).loadIndex(),
);

/// 개념 카드 맵 (키: "과목|단원|세부단원").
final conceptsProvider = FutureProvider<Map<String, ConceptCard>>(
  (ref) => ref.watch(contentRepositoryProvider).loadConcepts(),
);

// ───────────────────────── 사용자 상태 ─────────────────────────

class StatsNotifier extends StateNotifier<UserStats> {
  final SharedPreferences? _prefs;

  StatsNotifier([this._prefs]) : super(_load(_prefs));

  static UserStats _load(SharedPreferences? prefs) {
    final raw = prefs?.getString(_kStatsKey);
    if (raw == null || raw.isEmpty) return UserStats.empty();
    try {
      return UserStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserStats.empty();
    }
  }

  void _persist() {
    _prefs?.setString(_kStatsKey, jsonEncode(state.toJson()));
  }

  /// 문제 풀이 결과 반영.
  void recordAnswer(MathProblem problem, {required bool correct}) {
    final wrong = Map<String, MathProblem>.from(state.wrongProblems);
    if (correct) {
      wrong.remove(problem.id); // 맞히면 다시 풀 문제에서 제거
    } else {
      wrong[problem.id] = problem;
    }

    // 처음 푸는 문제면 단원별 진행 카운트를 +1 (정답 여부와 무관, 고유 집계).
    final newlySolved = !state.solvedIds.contains(problem.id);
    final byChapter = Map<String, int>.from(state.solvedByChapter);
    if (newlySolved) {
      final key = '${problem.subject}|${problem.chapter}';
      byChapter[key] = (byChapter[key] ?? 0) + 1;
    }

    final recent = <RecentRecord>[
      RecentRecord(
        problemId: problem.id,
        subject: problem.subject,
        lesson: problem.lesson,
        correct: correct,
        dateLabel: '오늘',
      ),
      ...state.recent,
    ];
    if (recent.length > 20) recent.removeRange(20, recent.length);

    final solved =
        newlySolved ? {...state.solvedIds, problem.id} : state.solvedIds;

    state = state.copyWith(
      totalSolved: state.totalSolved + 1,
      totalCorrect: state.totalCorrect + (correct ? 1 : 0),
      weeklySolved: state.weeklySolved + 1,
      wrongProblems: wrong,
      solvedByChapter: byChapter,
      recent: recent,
      solvedIds: solved,
    );
    _persist();
  }

  /// 'yyyy-MM-dd' 키
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 오늘 출석 체크. 연속 출석일(streak) 재계산 후 저장.
  void checkIn(DateTime day) {
    final key = dateKey(day);
    if (state.attendance.contains(key)) return; // 이미 출석
    final att = {...state.attendance, key};
    state = state.copyWith(attendance: att, streakDays: _streak(att, day));
    _persist();
  }

  /// today(또는 attended면 today, 아니면 yesterday)에서 거슬러 연속 출석일 계산.
  static int _streak(Set<String> att, DateTime today) {
    var cursor = today;
    if (!att.contains(dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (att.contains(dateKey(cursor))) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// 이어서 풀 위치 갱신
  void setContinue(ContinueInfo info) {
    state = state.copyWith(continueFrom: info);
    _persist();
  }

  /// 전체 상태 교체 (클라우드 동기화 병합 결과 반영).
  void replaceAll(UserStats next) {
    state = next;
    _persist();
  }

  /// '다시 풀 문제'에 수동 저장/해제
  void toggleReview(MathProblem problem) {
    final wrong = Map<String, MathProblem>.from(state.wrongProblems);
    if (wrong.containsKey(problem.id)) {
      wrong.remove(problem.id);
    } else {
      wrong[problem.id] = problem;
    }
    state = state.copyWith(wrongProblems: wrong);
    _persist();
  }

  bool isInReview(String problemId) =>
      state.wrongProblems.containsKey(problemId);
}

final statsProvider = StateNotifierProvider<StatsNotifier, UserStats>(
  (ref) => StatsNotifier(ref.watch(sharedPreferencesProvider)),
);

/// 다시 풀 문제(틀린 문제) 목록
final wrongProblemsProvider = Provider<List<MathProblem>>((ref) {
  return ref.watch(statsProvider).wrongProblems.values.toList();
});

/// 과목명 → 실제 진행률(0..1) = 고유 푼 문제 / 전체 문제.
/// 인덱스가 아직 로드되지 않았으면 빈 맵을 돌려준다.
final subjectProgressProvider = Provider<Map<String, double>>((ref) {
  final stats = ref.watch(statsProvider);
  final index = ref.watch(curriculumIndexProvider).valueOrNull;
  if (index == null) return const {};
  final out = <String, double>{};
  for (final s in index.subjects) {
    final total = s.chapters.fold<int>(0, (a, c) => a + c.count);
    if (total == 0) continue;
    out[s.name] = (stats.solvedInSubject(s.name) / total).clamp(0.0, 1.0);
  }
  return out;
});

// ───────────────────────── 설정 ─────────────────────────

enum DailyGoal { one, three, five, free }

extension DailyGoalInfo on DailyGoal {
  String get label => switch (this) {
        DailyGoal.one => '하루 1문제',
        DailyGoal.three => '하루 3문제',
        DailyGoal.five => '하루 5문제',
        DailyGoal.free => '자유롭게',
      };
}

class Settings {
  final bool notificationsOn;
  final int reminderHour; // 학습 리마인더 시각(시)
  final int reminderMinute; // 학습 리마인더 시각(분)
  final DailyGoal dailyGoal;
  final ThemeMode themeMode;

  const Settings({
    this.notificationsOn = false, // 권한 필요 — 기본 꺼짐(옵트인)
    this.reminderHour = 18, // 기본 저녁 6시
    this.reminderMinute = 0,
    this.dailyGoal = DailyGoal.three,
    this.themeMode = ThemeMode.system,
  });

  Settings copyWith({
    bool? notificationsOn,
    int? reminderHour,
    int? reminderMinute,
    DailyGoal? dailyGoal,
    ThemeMode? themeMode,
  }) =>
      Settings(
        notificationsOn: notificationsOn ?? this.notificationsOn,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        themeMode: themeMode ?? this.themeMode,
      );

  Map<String, dynamic> toJson() => {
        'notificationsOn': notificationsOn,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'dailyGoal': dailyGoal.name,
        'themeMode': themeMode.name,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        notificationsOn: j['notificationsOn'] as bool? ?? false,
        reminderHour: j['reminderHour'] as int? ?? 18,
        reminderMinute: j['reminderMinute'] as int? ?? 0,
        dailyGoal: DailyGoal.values.firstWhere(
          (g) => g.name == j['dailyGoal'],
          orElse: () => DailyGoal.three,
        ),
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.system,
        ),
      );
}

class SettingsNotifier extends StateNotifier<Settings> {
  final SharedPreferences? _prefs;

  SettingsNotifier([this._prefs]) : super(_load(_prefs)) {
    // 앱 시작 시 켜져 있으면 예약 재설정(재부팅·업데이트 대비).
    if (state.notificationsOn) {
      NotificationService.scheduleDaily(state.reminderHour, state.reminderMinute);
    }
  }

  static Settings _load(SharedPreferences? prefs) {
    final raw = prefs?.getString(_kSettingsKey);
    if (raw == null || raw.isEmpty) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Settings();
    }
  }

  void _persist() {
    _prefs?.setString(_kSettingsKey, jsonEncode(state.toJson()));
  }

  void toggleNotifications(bool v) {
    state = state.copyWith(notificationsOn: v);
    _persist();
    if (v) {
      NotificationService.scheduleDaily(state.reminderHour, state.reminderMinute);
    } else {
      NotificationService.cancelDaily();
    }
  }

  void setReminderTime(int hour, int minute) {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    _persist();
    if (state.notificationsOn) {
      NotificationService.scheduleDaily(hour, minute);
    }
  }

  void setGoal(DailyGoal g) {
    state = state.copyWith(dailyGoal: g);
    _persist();
  }

  void setThemeMode(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    _persist();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
  (ref) => SettingsNotifier(ref.watch(sharedPreferencesProvider)),
);
