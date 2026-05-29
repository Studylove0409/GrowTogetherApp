# 任意日期打卡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户在「我的计划」列表页选择任意日期后，能通过完整打卡流程为该日期提交打卡（过去补打卡、未来预打卡）。

**Architecture:** `targetDate` 作为可选参数贯穿 `PlanDetailPage → CheckinPage → Store.saveCheckin → CheckinRepository`。后端新增 `upsert_checkin_for_date` RPC 并放开触发器对非今日 INSERT 的限制。所有现有的今日打卡入口（首页等）零改动。

**Tech Stack:** Flutter / Dart、Supabase PostgreSQL（RPC + trigger）、provider

---

## 文件改动一览

| 文件 | 类型 |
|------|------|
| `supabase/migrations/20260529120000_arbitrary_date_checkin.sql` | 新建 |
| `lib/data/models/plan.dart` | 修改 |
| `lib/data/store/store.dart` | 修改 |
| `lib/data/mock/mock_store.dart` | 修改 |
| `lib/data/supabase/checkin_repository.dart` | 修改 |
| `lib/data/supabase/supabase_store.dart` | 修改 |
| `lib/features/plans/plan_list_scaffold.dart` | 修改 |
| `lib/features/plans/my_plans_page.dart` | 修改 |
| `lib/features/plans/partner_plans_page.dart` | 修改 |
| `lib/features/plans/together_plans_page.dart` | 修改 |
| `lib/features/plans/plan_detail_page.dart` | 修改 |
| `lib/features/checkin/checkin_page.dart` | 修改 |
| `test/widget_test.dart` | 修改（新增测试） |

---

## Task 1: 后端 Migration

**Files:**
- Create: `supabase/migrations/20260529120000_arbitrary_date_checkin.sql`

- [ ] **Step 1: 创建 migration 文件**

内容如下（完整 SQL）：

```sql
-- ============================================================
-- 1. 扩展 can_checkin_plan：接受可选 p_date 参数
--    默认 null = 今天（保持向后兼容）
-- ============================================================
create or replace function private.can_checkin_plan(
  p_plan_id uuid,
  p_user_id uuid,
  p_date date default null
)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.plans p
    join public.couples c on c.id = p.couple_id
    where p.id = p_plan_id
      and p.status = 'active'
      and c.status = 'active'
      and private.is_plan_available_on_date(
        p.repeat_type,
        p.has_date_range,
        p.start_date,
        p.end_date,
        coalesce(p_date, private.current_checkin_date())
      )
      and p_user_id in (c.user_a_id, c.user_b_id)
      and (
        p.plan_type = 'shared'
        or (p.plan_type = 'personal' and p.creator_id = p_user_id)
      )
  );
$$;

-- ============================================================
-- 2. 修改 validate_checkin_write 触发器：
--    - 用 new.checkin_date 校验计划调度窗口（而非硬编码今天）
--    - UPDATE 仍只允许修改当日打卡
--    - INSERT 允许任意日期（由 RPC 层保证范围合法）
-- ============================================================
create or replace function private.validate_checkin_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_couple_id uuid;
begin
  new.created_at = coalesce(new.created_at, now());
  new.updated_at = coalesce(new.updated_at, now());

  select p.couple_id
  into plan_couple_id
  from public.plans p
  where p.id = new.plan_id;

  if plan_couple_id is null then
    raise exception 'plan does not exist';
  end if;

  if new.couple_id <> plan_couple_id then
    raise exception 'checkin couple_id must match plan';
  end if;

  -- 用 checkin 自身的日期（不再硬编码今天）来校验权限
  if not private.can_checkin_plan(new.plan_id, new.user_id, new.checkin_date) then
    raise exception 'user cannot check in this plan';
  end if;

  -- UPDATE：只能在当天修改
  if tg_op = 'UPDATE' and new.checkin_date <> private.current_checkin_date() then
    raise exception 'checkins can only be changed during the current checkin day';
  end if;

  if tg_op = 'UPDATE' and (
    new.id <> old.id
    or new.plan_id <> old.plan_id
    or new.user_id <> old.user_id
    or new.couple_id <> old.couple_id
    or new.checkin_date <> old.checkin_date
    or new.created_at <> old.created_at
  ) then
    raise exception 'checkin identity fields cannot be changed';
  end if;

  return new;
end;
$$;

-- ============================================================
-- 3. 新 RPC：upsert_checkin_for_date
--    过去日期：INSERT only（DO NOTHING 不覆盖已有）
--    今天/未来：UPSERT（允许覆盖）
-- ============================================================
create or replace function private.upsert_checkin_for_date(
  p_plan_id uuid,
  p_date date,
  p_status text,
  p_mood text default null,
  p_note text default null
)
returns public.checkins
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  plan_row public.plans%rowtype;
  checkin_row public.checkins%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select * into plan_row from public.plans p where p.id = p_plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  if not private.is_plan_available_on_date(
    plan_row.repeat_type, plan_row.has_date_range,
    plan_row.start_date, plan_row.end_date, p_date
  ) then
    raise exception 'plan is not scheduled on this date';
  end if;

  if not exists (
    select 1 from public.couples c
    where c.id = plan_row.couple_id and c.status = 'active'
      and current_user_id in (c.user_a_id, c.user_b_id)
      and (plan_row.plan_type = 'shared'
           or (plan_row.plan_type = 'personal'
               and plan_row.creator_id = current_user_id))
  ) then
    raise exception 'user cannot check in this plan';
  end if;

  if p_date < private.current_checkin_date() then
    -- 过去：只插入，不覆盖已有记录
    insert into public.checkins (
      plan_id, user_id, couple_id, checkin_date, status, mood, note
    )
    values (
      p_plan_id, current_user_id, plan_row.couple_id, p_date,
      p_status, p_mood, nullif(trim(p_note), '')
    )
    on conflict (plan_id, user_id, checkin_date) do nothing
    returning * into checkin_row;
  else
    -- 今天/未来：允许覆盖
    insert into public.checkins (
      plan_id, user_id, couple_id, checkin_date, status, mood, note
    )
    values (
      p_plan_id, current_user_id, plan_row.couple_id, p_date,
      p_status, p_mood, nullif(trim(p_note), '')
    )
    on conflict (plan_id, user_id, checkin_date) do update
      set status = excluded.status,
          mood = excluded.mood,
          note = excluded.note,
          updated_at = now()
    returning * into checkin_row;
  end if;

  return checkin_row;
end;
$$;

create or replace function public.upsert_checkin_for_date(
  p_plan_id uuid,
  p_date date,
  p_status text,
  p_mood text default null,
  p_note text default null
)
returns public.checkins
language sql
security invoker
set search_path = public, private
as $$
  select private.upsert_checkin_for_date(p_plan_id, p_date, p_status, p_mood, p_note);
$$;

grant execute on function public.upsert_checkin_for_date(uuid, date, text, text, text)
  to authenticated;
```

- [ ] **Step 2: 应用 migration**

使用 Supabase MCP 工具（`mcp__supabase__apply_migration`）把上述 SQL 应用到远端项目，或运行：

```bash
supabase db push
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260529120000_arbitrary_date_checkin.sql
git commit -m "feat(backend): add upsert_checkin_for_date RPC and relax write trigger"
```

---

## Task 2: Plan 模型 — 新增 `canCurrentUserCheckinOn`

**Files:**
- Modify: `lib/data/models/plan.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: 写失败测试**

在 `test/widget_test.dart` 中，找到 `_testPlan` helper 附近，添加：

```dart
void main() {
  // … 已有测试 …

  group('Plan.canCurrentUserCheckinOn', () {
    final today = _todayOnly();
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    test('returns true for today on a daily plan', () {
      final plan = _testPlan(
        startDate: today.subtract(const Duration(days: 3)),
        endDate: today.add(const Duration(days: 10)),
        repeatType: PlanRepeatType.daily,
      );
      expect(plan.canCurrentUserCheckinOn(today), isTrue);
    });

    test('returns true for yesterday on a daily plan', () {
      final plan = _testPlan(
        startDate: yesterday.subtract(const Duration(days: 3)),
        endDate: today.add(const Duration(days: 10)),
        repeatType: PlanRepeatType.daily,
      );
      expect(plan.canCurrentUserCheckinOn(yesterday), isTrue);
    });

    test('returns true for tomorrow on a daily plan', () {
      final plan = _testPlan(
        startDate: today,
        endDate: today.add(const Duration(days: 10)),
        repeatType: PlanRepeatType.daily,
      );
      expect(plan.canCurrentUserCheckinOn(tomorrow), isTrue);
    });

    test('returns false when date is outside plan range', () {
      final plan = _testPlan(
        startDate: today,
        endDate: today.add(const Duration(days: 5)),
        repeatType: PlanRepeatType.daily,
      );
      expect(
        plan.canCurrentUserCheckinOn(today.add(const Duration(days: 10))),
        isFalse,
      );
    });

    test('returns false for partner plan', () {
      final plan = Plan(
        id: 'p',
        title: 'T',
        subtitle: 'S',
        owner: PlanOwner.partner,
        iconKey: PlanIconMapper.defaultKey,
        minutes: 20,
        completedDays: 0,
        totalDays: 7,
        doneToday: false,
        color: Colors.pink,
        dailyTask: 'T',
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
        reminderTime: null,
        repeatType: PlanRepeatType.daily,
      );
      expect(plan.canCurrentUserCheckinOn(today), isFalse);
    });
  });
}
```

- [ ] **Step 2: 确认测试失败**

```bash
flutter test test/widget_test.dart --name "canCurrentUserCheckinOn"
```

预期：编译错误（方法不存在）。

- [ ] **Step 3: 在 Plan 模型中新增方法**

在 `lib/data/models/plan.dart` 的 `canCurrentUserCheckin` getter 下方添加：

```dart
bool canCurrentUserCheckinOn(DateTime date) =>
    owner != PlanOwner.partner && isScheduledOnDate(date) && !isEnded;
```

- [ ] **Step 4: 确认测试通过**

```bash
flutter test test/widget_test.dart --name "canCurrentUserCheckinOn"
```

预期：全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/plan.dart test/widget_test.dart
git commit -m "feat(model): add canCurrentUserCheckinOn(date) to Plan"
```

---

## Task 3: Store 接口 & MockStore — `saveCheckin` 新增 `date` 参数

**Files:**
- Modify: `lib/data/store/store.dart`
- Modify: `lib/data/mock/mock_store.dart`

- [ ] **Step 1: 更新 Store 抽象接口**

在 `lib/data/store/store.dart` 中，把 `saveCheckin` 签名改为：

```dart
Future<void> saveCheckin({
  required String planId,
  required bool completed,
  required CheckinMood mood,
  required String note,
  DateTime? date,
});
```

- [ ] **Step 2: 更新 MockStore 实现**

在 `lib/data/mock/mock_store.dart` 中，找到第 236 行附近的 `saveCheckin`，更新签名并忽略 `date`（MockStore 始终操作今天）：

```dart
@override
Future<void> saveCheckin({
  required String planId,
  required bool completed,
  required CheckinMood mood,
  required String note,
  DateTime? date,
}) async {
  final index = _plans.indexWhere((plan) => plan.id == planId);
  if (index == -1) return;

  final plan = _plans[index];
  // MockStore 只操作今天状态，忽略 date 参数
  if (!plan.canCurrentUserCheckin) return;

  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final checkins = [
    CheckinRecord(
      date: todayOnly,
      completed: completed,
      mood: mood,
      note: note.trim(),
      actor: CheckinActor.me,
    ),
    ...plan.checkins.where(
      (record) =>
          record.actor != CheckinActor.me ||
          !_isSameDate(record.date, todayOnly),
    ),
  ];

  final wasDoneToday = plan.doneToday;
  final completedDays = completed && !wasDoneToday
      ? plan.completedDays + 1
      : !completed && wasDoneToday
      ? (plan.completedDays - 1).clamp(0, plan.totalDays)
      : plan.completedDays;

  _plans[index] = plan.copyWith(
    doneToday: completed,
    completedDays: completedDays,
    checkins: checkins,
  );
  _finishOncePlanIfComplete(index);
  notifyListeners();
}
```

- [ ] **Step 3: 确认编译通过**

```bash
flutter analyze
```

预期：无错误（SupabaseStore 还没更新，会有一个 override 参数不匹配错误，下一 task 修复）。

---

## Task 4: CheckinRepository & SupabaseStore

**Files:**
- Modify: `lib/data/supabase/checkin_repository.dart`
- Modify: `lib/data/supabase/supabase_store.dart`

- [ ] **Step 1: 在 CheckinRepository 新增 `upsertCheckinForDate`**

在 `lib/data/supabase/checkin_repository.dart` 末尾（`_fromMood` 前）添加：

```dart
/// 为任意日期（过去或未来）提交打卡，调用 upsert_checkin_for_date RPC。
Future<void> upsertCheckinForDate({
  required String planId,
  required DateTime date,
  required bool completed,
  required CheckinMood mood,
  required String note,
}) async {
  // yyyy-MM-dd 格式，不依赖 intl 包
  final dateStr =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  await _supabase.rpc('upsert_checkin_for_date', params: {
    'p_plan_id': planId,
    'p_date': dateStr,
    'p_status': completed ? 'completed' : 'uncompleted',
    'p_mood': _fromMood(mood),
    'p_note': note.isEmpty ? null : note,
  });
}
```

- [ ] **Step 2: 更新 SupabaseStore.saveCheckin 签名并路由**

在 `lib/data/supabase/supabase_store.dart` 中，找到第 822 行附近的 `saveCheckin` 方法，更新为：

```dart
@override
Future<void> saveCheckin({
  required String planId,
  required bool completed,
  required CheckinMood mood,
  required String note,
  DateTime? date,
}) async {
  final index = _plans.indexWhere((plan) => plan.id == planId);
  if (index == -1) return;

  final previousPlan = _plans[index];

  // 根据日期选择权限判断方式
  final isToday = date == null || _isSameDate(date, DateTime.now());
  final canCheckin = isToday
      ? previousPlan.canCurrentUserCheckin
      : previousPlan.canCurrentUserCheckinOn(date!);
  if (!canCheckin) return;

  // 今天：乐观更新本地缓存；非今天：直接走网络
  if (isToday) {
    _locallyDirtyPlanIds.add(planId);
    _plans[index] = _planWithTodayCheckin(
      previousPlan,
      completed: completed,
      mood: mood,
      note: note,
    );
    await _writePlanCache();
    notifyListeners();
  }

  try {
    if (isToday) {
      await _checkinRepo.upsertTodayCheckin(
        planId: planId,
        completed: completed,
        mood: mood,
        note: note.trim(),
      );
    } else {
      await _checkinRepo.upsertCheckinForDate(
        planId: planId,
        date: date!,
        completed: completed,
        mood: mood,
        note: note.trim(),
      );
    }
    await _finishOncePlanIfCompleteFromLocal(planId);
    await _refreshPlansFromRemote();
  } catch (_) {
    if (isToday) {
      _locallyDirtyPlanIds.remove(planId);
      final rollbackIndex = _plans.indexWhere((plan) => plan.id == planId);
      if (rollbackIndex != -1) {
        _plans[rollbackIndex] = previousPlan;
        await _writePlanCache();
        notifyListeners();
      }
    }
    rethrow;
  }
}
```

在文件顶部或底部添加辅助函数（如果不存在）：

```dart
bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
```

- [ ] **Step 3: 确认编译通过**

```bash
flutter analyze
```

预期：无错误。

- [ ] **Step 4: Commit**

```bash
git add lib/data/supabase/checkin_repository.dart lib/data/supabase/supabase_store.dart \
        lib/data/store/store.dart lib/data/mock/mock_store.dart
git commit -m "feat(data): wire saveCheckin date param through store and repository"
```

---

## Task 5: PlanListScaffold — `onTapPlan` 签名 & 快速打卡守卫

**Files:**
- Modify: `lib/features/plans/plan_list_scaffold.dart`

- [ ] **Step 1: 更新 `onTapPlan` 签名**

在 `PlanListScaffold` 的字段声明处，把：

```dart
final ValueChanged<Plan> onTapPlan;
```

改为：

```dart
final void Function(Plan plan, DateTime selectedDate) onTapPlan;
```

- [ ] **Step 2: 更新所有 `onTapPlan` 调用处**

在 `_PlanListScaffoldState._buildPlanTile` 和其他调用 `widget.onTapPlan(plan)` 的地方，改为：

```dart
widget.onTapPlan(plan, _selectedDate)
```

全文搜索 `widget.onTapPlan(plan)` 确认替换完毕（共 3 处：together 分支、isEnded 分支、默认分支）。

- [ ] **Step 3: 修改 `_quickStatusTapFor`**

快速打卡（单击状态图标一键完成）仍仅支持今日，非今日通过点击计划卡片走完整 `CheckinPage`（可填写备注和心情）。原逻辑基本不变，只把 `canCurrentUserCheckin` 改为 `canCurrentUserCheckinOn` 以复用新方法：

```dart
VoidCallback? _quickStatusTapFor(Plan plan) {
  if (widget.onQuickCheckin == null) return null;
  if (_quickCheckingPlanIds.contains(plan.id)) return null;
  if (_optimisticDonePlanIds.contains(plan.id)) return null;
  if (!_isToday(_selectedDate)) return null;          // 快速打卡今日限定
  if (!plan.canCurrentUserCheckinOn(_selectedDate)) return null;
  if (plan.hasCurrentUserCheckinOn(_selectedDate)) return null;
  return () => _quickCheckin(plan);
}
```

- [ ] **Step 4: 确认编译（此时 My/Partner/Together pages 还没更新，会报错）**

```bash
flutter analyze 2>&1 | grep "onTapPlan"
```

预期：看到 3 个 `onTapPlan` 参数不匹配的错误，下一 task 修复。

---

## Task 6: 三个 Plans 页更新 `onTapPlan`

**Files:**
- Modify: `lib/features/plans/my_plans_page.dart`
- Modify: `lib/features/plans/partner_plans_page.dart`
- Modify: `lib/features/plans/together_plans_page.dart`

- [ ] **Step 1: 更新 `my_plans_page.dart`**

找到 `onTapPlan` 回调，改为接收 `selectedDate` 并传给 `PlanDetailPage`：

```dart
onTapPlan: (plan, selectedDate) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlanDetailPage(
        planId: plan.id,
        targetDate: selectedDate,
      ),
    ),
  );
},
```

- [ ] **Step 2: 更新 `partner_plans_page.dart`**

```dart
onTapPlan: (plan, selectedDate) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlanDetailPage(
        planId: plan.id,
        targetDate: selectedDate,
      ),
    ),
  );
},
```

- [ ] **Step 3: 更新 `together_plans_page.dart`**

找到 `onTapPlan` 回调（格式相同），改为：

```dart
onTapPlan: (plan, selectedDate) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlanDetailPage(
        planId: plan.id,
        targetDate: selectedDate,
      ),
    ),
  );
},
```

- [ ] **Step 4: 确认编译通过**

```bash
flutter analyze
```

预期：无错误。

- [ ] **Step 5: Commit**

```bash
git add lib/features/plans/plan_list_scaffold.dart \
        lib/features/plans/my_plans_page.dart \
        lib/features/plans/partner_plans_page.dart \
        lib/features/plans/together_plans_page.dart
git commit -m "feat(plans): pass selectedDate through onTapPlan to PlanDetailPage"
```

---

## Task 7: PlanDetailPage — 支持 `targetDate`

**Files:**
- Modify: `lib/features/plans/plan_detail_page.dart`

- [ ] **Step 1: 添加 `targetDate` 构造参数**

在 `PlanDetailPage` 类顶部：

```dart
class PlanDetailPage extends StatelessWidget {
  const PlanDetailPage({super.key, required this.planId, this.targetDate});

  final String planId;
  final DateTime? targetDate;     // ← 新增
```

- [ ] **Step 2: 更新 AppBar 标题，非今日时显示日期标签**

把现有的：

```dart
appBar: AppBar(
  title: const Text('计划详情', style: AppTextStyles.section),
```

改为：

```dart
appBar: AppBar(
  title: _buildAppBarTitle(),
```

在 `PlanDetailPage` 中添加方法：

```dart
Widget _buildAppBarTitle() {
  final effective = _effectiveDate;
  final isToday = _isSameDateStatic(effective, DateTime.now());
  if (isToday) return const Text('计划详情', style: AppTextStyles.section);

  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final d = DateTime(effective.year, effective.month, effective.day);
  final tag = d.isBefore(today) ? '补打卡' : '提前打卡';

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('计划详情', style: AppTextStyles.section),
      Text(
        '${effective.month}月${effective.day}日 · $tag',
        style: AppTextStyles.caption.copyWith(color: AppColors.deepPink),
      ),
    ],
  );
}

DateTime get _effectiveDate {
  if (targetDate == null) return DateTime.now();
  return DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
}

static bool _isSameDateStatic(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
```

- [ ] **Step 3: 更新 `_buildBottomButton` — 非今日走新分支**

在 `_buildBottomButton` 方法最开头插入：

```dart
Widget _buildBottomButton(BuildContext context, Plan plan) {
  final effective = _effectiveDate;
  final isEffectiveToday = _isSameDateStatic(effective, DateTime.now());

  // 非今日：使用简化的日期打卡按钮
  if (!isEffectiveToday) {
    return _buildDateSpecificButton(context, plan, effective);
  }

  // 以下为原有今日逻辑，不变 ↓
  if (plan.isEnded && !plan.isCompletedOnceToday) {
  // … （原有代码保持不动）
```

- [ ] **Step 4: 在文件中添加 `_buildDateSpecificButton` 方法**

在 `_buildBottomButton` 后面添加：

```dart
Widget _buildDateSpecificButton(BuildContext context, Plan plan, DateTime date) {
  if (plan.owner == PlanOwner.partner) {
    return const _MutedActionPill(
      label: 'TA 的计划',
      icon: Icons.visibility_rounded,
    );
  }

  if (plan.isEnded) {
    return const _MutedActionPill(
      label: '已结束',
      icon: Icons.event_available_rounded,
    );
  }

  if (!plan.isScheduledOnDate(date)) {
    return const _MutedActionPill(
      label: '该日不在计划期内',
      icon: Icons.event_busy_rounded,
    );
  }

  if (plan.hasCurrentUserCheckinOn(date)) {
    return const _CompletedActionPill(
      label: '已打卡',
      icon: Icons.check_circle_rounded,
    );
  }

  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final d = DateTime(date.year, date.month, date.day);
  final isPast = d.isBefore(today);

  return PrimaryButton(
    label: isPast ? '补打卡' : '提前打卡',
    icon: Icons.check_circle_rounded,
    onPressed: () => _openCheckinPage(context, plan, date),
  );
}
```

- [ ] **Step 5: 更新 `_openCheckinPage` 接受可选 date**

把：

```dart
void _openCheckinPage(BuildContext context, Plan plan) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CheckinPage(planId: plan.id)),
  );
}
```

改为：

```dart
void _openCheckinPage(BuildContext context, Plan plan, [DateTime? date]) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CheckinPage(planId: plan.id, targetDate: date),
    ),
  );
}
```

将文件内所有 `_openCheckinPage(context, plan)` 调用（今日分支）保持不变，新增的 `_buildDateSpecificButton` 传入 `date`。

- [ ] **Step 6: 确认编译通过**

```bash
flutter analyze
```

预期：无错误。

- [ ] **Step 7: Commit**

```bash
git add lib/features/plans/plan_detail_page.dart
git commit -m "feat(ui): PlanDetailPage supports targetDate for date-specific checkin"
```

---

## Task 8: CheckinPage — 支持 `targetDate`

**Files:**
- Modify: `lib/features/checkin/checkin_page.dart`

- [ ] **Step 1: 添加 `targetDate` 构造参数**

```dart
class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key, required this.planId, this.targetDate});

  final String planId;
  final DateTime? targetDate;     // ← 新增
```

- [ ] **Step 2: 在 State 中添加辅助 getter**

在 `_CheckinPageState` 中添加：

```dart
DateTime get _effectiveDate {
  final t = widget.targetDate;
  if (t == null) return DateTime.now();
  return DateTime(t.year, t.month, t.day);
}

bool get _isEffectiveToday {
  final d = _effectiveDate;
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}
```

- [ ] **Step 3: 更新 AppBar 标题**

把：

```dart
appBar: AppBar(title: const Text('每日打卡')),
```

改为：

```dart
appBar: AppBar(
  title: Text(
    _isEffectiveToday
        ? '每日打卡'
        : '${_effectiveDate.month}月${_effectiveDate.day}日打卡',
  ),
),
```

- [ ] **Step 4: 更新 `canCheckin` 判断**

在 `build` 方法中，把：

```dart
final canCheckin = plan?.canCurrentUserCheckin ?? false;
```

改为：

```dart
final canCheckin = plan?.canCurrentUserCheckinOn(_effectiveDate) ?? false;
```

- [ ] **Step 5: 更新 `_saveCheckin` 调用**

在 `_saveCheckin` 方法中，把：

```dart
final saveFuture = store.saveCheckin(
  planId: widget.planId,
  completed: _completed,
  mood: _mood,
  note: _noteController.text,
);
```

改为：

```dart
final saveFuture = store.saveCheckin(
  planId: widget.planId,
  completed: _completed,
  mood: _mood,
  note: _noteController.text,
  date: widget.targetDate,
);
```

- [ ] **Step 6: 更新 `_cannotCheckinText` 提示文案**

把：

```dart
String _cannotCheckinText(Plan? plan) {
  if (plan == null) return '这个计划今天不在可打卡时间内啦';
  if (plan.owner == PlanOwner.partner) return 'TA 的计划只能查看，不能代替 TA 打卡。';
  if (plan.isEnded) return '这个计划已经结束啦，不需要再打卡。';
  if (plan.isNotStartedYet) return '这个计划还没开始，到了开始日期再打卡。';
  return '这个计划今天不在可打卡时间内啦';
}
```

改为：

```dart
String _cannotCheckinText(Plan? plan) {
  if (plan == null) return '这个计划在这一天不在可打卡时间内啦';
  if (plan.owner == PlanOwner.partner) return 'TA 的计划只能查看，不能代替 TA 打卡。';
  if (plan.isEnded) return '这个计划已经结束啦，不需要再打卡。';
  final d = _effectiveDate;
  if (!plan.isScheduledOnDate(d)) {
    return '这个计划在 ${d.month}月${d.day}日 不在可打卡时间内啦';
  }
  return '这个计划在这一天不在可打卡时间内啦';
}
```

- [ ] **Step 7: 确认编译通过**

```bash
flutter analyze
```

预期：无错误（0 issues）。

- [ ] **Step 8: 运行全量测试**

```bash
flutter test
```

预期：全部 PASS。

- [ ] **Step 9: Commit**

```bash
git add lib/features/checkin/checkin_page.dart
git commit -m "feat(ui): CheckinPage supports targetDate for arbitrary-date checkin"
```

---

## Task 9: 手动验证

- [ ] **Step 1: 启动 App**

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://kmeuuwqcngxhcfeevzsy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

- [ ] **Step 2: 验证未来打卡**

1. 进入「我的计划」
2. 点击日期选择器，选择明天
3. 确认有「待打卡」状态的每日计划显示
4. 点击计划卡片 → 进入「计划详情」，确认 AppBar 显示「X月X日 · 提前打卡」
5. 点击「提前打卡」→ 进入 `CheckinPage`，标题为「X月X日打卡」
6. 提交 → 确认成功并返回，详情页显示「已打卡」

- [ ] **Step 3: 验证过去补打卡**

1. 选择昨天（或更早，确保当天没有打卡记录）
2. 进入计划详情，确认 AppBar 显示「X月X日 · 补打卡」
3. 点击「补打卡」→ 提交 → 确认成功
4. 再次进入同一天，确认显示「已打卡」（Supabase `DO NOTHING` 静默忽略重复提交）

- [ ] **Step 4: 确认今日入口不受影响**

1. 回到今日（点「今天」按钮）
2. 确认今日打卡流程正常（标题仍为「每日打卡」，按钮仍为「去打卡」）
3. 首页打卡卡片功能正常（不传 `targetDate`，走原有路径）
