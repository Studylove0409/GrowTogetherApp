import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../models/profile.dart';
import '../models/reminder.dart';

/// 统一数据门面接口。
///
/// UI 层只依赖这个接口，不感知数据来自 mock 还是 Supabase。
/// 顶层通过 `Provider<Store>` 注入具体实现。
abstract class Store extends ChangeNotifier {
  // ========================= Profile =========================

  Profile getProfile();
  Future<void> refreshProfile();

  // ========================= 刷新 =========================

  Future<void> refreshPlans() async {}

  Future<void> refreshReminders() async {}

  Future<void> refreshAll() async {
    await Future.wait([refreshProfile(), refreshPlans(), refreshReminders()]);
  }

  // ========================= Plan 读 =========================

  List<Plan> getPlans();
  List<Plan> getPlansByOwner(PlanOwner owner);
  List<Plan> getTodayFocusPlans();
  List<Plan> getAllPlans();
  Plan? getPlanById(String id);

  // ========================= Plan 写 =========================

  Future<Plan> createPlan({
    required String title,
    required bool isShared,
    required String dailyTask,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay? reminderTime,
    PlanRepeatType repeatType = PlanRepeatType.once,
    bool hasDateRange = true,
    String iconKey,
  });

  Future<void> updatePlan({
    required String planId,
    String? title,
    String? dailyTask,
    String? iconKey,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    PlanRepeatType? repeatType,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasDateRange,
  });

  Future<void> endPlan(String planId);

  // ========================= Checkin =========================

  List<CheckinRecord> getCheckinRecords(String planId);

  Future<void> saveCheckin({
    required String planId,
    required bool completed,
    required CheckinMood mood,
    required String note,
  });

  Future<void> updatePlanStatus(String planId, {required bool doneToday});

  // ========================= Reminder =========================

  List<Reminder> getReminders();

  int get unreadReminderCount;

  Future<void> sendReminder({
    required String planId,
    required ReminderType type,
    required String content,
  });

  Future<void> markReceivedRemindersRead();
}
