# 任意日期打卡设计文档

**日期**：2026-05-29  
**范围**：`我的计划` 列表页已有日期选择器，当前只能打卡今天。本功能扩展为支持任意日期（过去补打卡、未来预打卡）。

---

## 背景与目标

`PlanListScaffold` 已有日期选择器（`_PlanDateFilterCard`），可切换到任意日期查看计划列表。但打卡能力被限制在"今天"：

- `_quickStatusTapFor` 有 `if (!_isToday(_selectedDate)) return null` 守卫
- `Plan.canCurrentUserCheckin` 内部调用 `isAvailableToday`（只检查今天）
- `CheckinPage` 不接受目标日期参数
- 后端 `validate_checkin_write` 触发器拒绝任何非今日 `checkin_date`

目标：让用户在切换到任意日期后，能通过完整打卡流程为该日期提交打卡记录。

---

## 不在本次范围内

- 修改打卡历史记录页（`CheckinRecordPage`）的展示逻辑
- 补打卡对「连续天数」等统计数据的影响（统计逻辑不在本次改动范围内，由现有派生逻辑自然处理）
- Partner Plans 页和 Together Plans 页的日期选择器（本次只改 My Plans，但架构支持后续扩展）

---

## 日期上下文传播路径

```
PlanListScaffold(_selectedDate)
  └─ onTapPlan(plan, selectedDate) → PlanDetailPage(planId, targetDate)
       └─ _DateActionCard(date) → CheckinPage(planId, targetDate)
            └─ store.saveCheckin(planId, date, ...)
                 └─ CheckinRepository.upsertCheckinForDate(planId, date, ...)
                      └─ Supabase RPC: upsert_checkin_for_date
```

`targetDate` 贯穿整条调用链。所有新参数均为可选（`DateTime? targetDate`，默认 `null` 表示今天），不传日期的入口（首页今日计划卡等）零改动。

---

## 各层改动说明

### Plan 模型（`lib/data/models/plan.dart`）

新增：

```dart
bool canCurrentUserCheckinOn(DateTime date) =>
    owner != PlanOwner.partner && isScheduledOnDate(date) && !isEnded;
```

现有 `canCurrentUserCheckin` 保持不变（内部调用 `isAvailableToday`，由今天的入口继续使用）。

---

### Store 接口（`lib/data/store/store.dart`）

`saveCheckin` 新增可选参数 `DateTime? date`，默认 `null` 表示今天：

```dart
Future<void> saveCheckin({
  required String planId,
  required bool completed,
  required CheckinMood mood,
  required String note,
  DateTime? date,          // 新增
});
```

`MockStore` 实现忽略该参数（只影响今天的本地状态），`SupabaseStore` 根据 `date` 选择调用哪个 RPC：
- `date == null || isToday(date)` → 原有 `upsertTodayCheckin`
- 其他 → 新的 `upsertCheckinForDate`

---

### CheckinRepository（`lib/data/supabase/checkin_repository.dart`）

新增方法：

```dart
Future<void> upsertCheckinForDate({
  required String planId,
  required DateTime date,
  required bool completed,
  required CheckinMood mood,
  required String note,
}) async {
  await _supabase.rpc('upsert_checkin_for_date', params: {
    'p_plan_id': planId,
    'p_date': DateFormat('yyyy-MM-dd').format(date),
    'p_status': completed ? 'completed' : 'uncompleted',
    'p_mood': _fromMood(mood),
    'p_note': note.isEmpty ? null : note,
  });
}
```

---

### PlanListScaffold（`lib/features/plans/plan_list_scaffold.dart`）

**`onTapPlan` 签名变更**：

```dart
// 旧
final ValueChanged<Plan> onTapPlan;
// 新
final void Function(Plan plan, DateTime selectedDate) onTapPlan;
```

**`_quickStatusTapFor` 改动**：
- 移除 `if (!_isToday(_selectedDate)) return null`
- 改为：过去日期不提供快速打卡（保留完整流程入口）；今天和未来日期均可快速打卡
- 条件：`!_isPast(_selectedDate) && plan.canCurrentUserCheckinOn(_selectedDate)`

**`MyPlansPage` / `TogetherPlansPage` / `PartnerPlansPage`**：
- 更新 `onTapPlan` 回调，把 `selectedDate` 透传给 `PlanDetailPage`

---

### PlanDetailPage（`lib/features/plans/plan_detail_page.dart`）

构造函数新增参数：

```dart
const PlanDetailPage({super.key, required this.planId, this.targetDate});
final DateTime? targetDate;
```

**AppBar 副标题**：当 `targetDate` 不为 null 且不是今天时，在标题下方显示日期说明（如「5月31日」）。

**`_TodayActionCard` → `_DateActionCard(date)`**：
- 打卡按钮文案根据日期动态显示：
  - 今天 → 「打卡」
  - 过去 → 「补打卡」
  - 未来 → 「提前打卡」
- `canCheckin` 判断改为 `plan.canCurrentUserCheckinOn(date)`
- 跳转 `CheckinPage` 时传入 `targetDate`

---

### CheckinPage（`lib/features/checkin/checkin_page.dart`）

构造函数新增参数：

```dart
const CheckinPage({super.key, required this.planId, this.targetDate});
final DateTime? targetDate;
```

- AppBar 标题：今天→「每日打卡」，其他日期→「X月X日打卡」
- `canCheckin` 改用 `plan.canCurrentUserCheckinOn(targetDate ?? DateTime.now())`
- `_cannotCheckinText` 增加对未来/过去日期的说明
- `_saveCheckin` 调用 `store.saveCheckin(..., date: targetDate)`

---

## 后端改动（新 migration）

### 新 RPC：`upsert_checkin_for_date`

```sql
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

  -- 验证计划在指定日期内有效
  if not private.is_plan_available_on_date(
    plan_row.repeat_type, plan_row.has_date_range,
    plan_row.start_date, plan_row.end_date, p_date
  ) then
    raise exception 'plan is not scheduled on this date';
  end if;

  -- 验证用户有权限打卡（属于该 couple，且为 personal plan 的 creator 或 shared plan 成员）
  if not exists (
    select 1 from public.couples c
    where c.id = plan_row.couple_id and c.status = 'active'
      and current_user_id in (c.user_a_id, c.user_b_id)
      and (plan_row.plan_type = 'shared'
           or (plan_row.plan_type = 'personal' and plan_row.creator_id = current_user_id))
  ) then
    raise exception 'user cannot check in this plan';
  end if;

  -- 过去日期：只允许 INSERT（不覆盖已有记录）
  -- 今天/未来：允许 UPSERT
  if p_date < private.current_checkin_date() then
    insert into public.checkins (plan_id, user_id, couple_id, checkin_date, status, mood, note)
    values (p_plan_id, current_user_id, plan_row.couple_id, p_date,
            p_status, p_mood, nullif(trim(p_note), ''))
    on conflict (plan_id, user_id, checkin_date) do nothing
    returning * into checkin_row;
  else
    insert into public.checkins (plan_id, user_id, couple_id, checkin_date, status, mood, note)
    values (p_plan_id, current_user_id, plan_row.couple_id, p_date,
            p_status, p_mood, nullif(trim(p_note), ''))
    on conflict (plan_id, user_id, checkin_date) do update
      set status = excluded.status, mood = excluded.mood,
          note = excluded.note, updated_at = now()
    returning * into checkin_row;
  end if;

  return checkin_row;
end;
$$;

-- 对外暴露的包装函数
create or replace function public.upsert_checkin_for_date(
  p_plan_id uuid, p_date date, p_status text,
  p_mood text default null, p_note text default null
)
returns public.checkins
language sql security invoker
set search_path = public, private
as $$
  select private.upsert_checkin_for_date(p_plan_id, p_date, p_status, p_mood, p_note);
$$;

grant execute on function public.upsert_checkin_for_date(uuid, date, text, text, text) to authenticated;
```

### 修改 `validate_checkin_write` 触发器

将原有的硬性日期检查：

```sql
-- 旧：拒绝任何非今日 checkin_date
if new.checkin_date <> private.current_checkin_date() then
  raise exception 'checkins can only be changed during the current checkin day';
end if;
```

改为：

```sql
-- 新：只对 UPDATE 限制"只能改当天"；INSERT 允许任意日期（由 RPC 层验证范围）
if tg_op = 'UPDATE' and new.checkin_date <> private.current_checkin_date() then
  raise exception 'checkins can only be changed during the current checkin day';
end if;
```

**影响说明**：
- 过去日期 INSERT → 允许（RPC 用 `ON CONFLICT DO NOTHING`，不覆盖已有记录）
- 今天 INSERT/UPDATE → 允许（原有行为不变）
- 未来日期 INSERT → 允许（RPC 用 `ON CONFLICT DO UPDATE`，可覆盖预打卡）
- 未来/过去日期 UPDATE → 拒绝（必须走 RPC，不能直接改表）

---

## 边界情况

| 场景 | 行为 |
|------|------|
| 过去某天已有打卡记录，再次提交 | RPC 用 `DO NOTHING`，静默忽略，UI 显示已打卡状态 |
| 未来某天预打卡，当天再改 | 当天走 `upsert_today_checkin`，允许覆盖 |
| 选择的日期不在计划调度窗口内 | 前端 `canCurrentUserCheckinOn` 返回 false，不渲染打卡按钮；后端兜底报错 |
| Partner 的计划 | `canCurrentUserCheckinOn` 对 `PlanOwner.partner` 返回 false，不变 |
| 已结束的计划 | `isEnded` 为 true，`canCurrentUserCheckinOn` 返回 false |

---

## 文件改动清单

| 文件 | 变更类型 |
|------|---------|
| `lib/data/models/plan.dart` | 新增 `canCurrentUserCheckinOn(date)` |
| `lib/data/store/store.dart` | `saveCheckin` 新增 `date?` 参数 |
| `lib/data/mock/mock_store.dart` | 同步更新 `saveCheckin` 签名 |
| `lib/data/supabase/supabase_store.dart` | `saveCheckin` 路由到对应 RPC |
| `lib/data/supabase/checkin_repository.dart` | 新增 `upsertCheckinForDate` |
| `lib/features/plans/plan_list_scaffold.dart` | `onTapPlan` 签名、快速打卡守卫 |
| `lib/features/plans/my_plans_page.dart` | 更新 `onTapPlan` 回调 |
| `lib/features/plans/partner_plans_page.dart` | 更新 `onTapPlan` 回调（签名变更的编译修复） |
| `lib/features/plans/together_plans_page.dart` | 更新 `onTapPlan` 回调（签名变更的编译修复） |
| `lib/features/plans/plan_detail_page.dart` | 接收 `targetDate`，动态按钮文案 |
| `lib/features/checkin/checkin_page.dart` | 接收 `targetDate`，动态标题和逻辑 |
| `supabase/migrations/<timestamp>_arbitrary_date_checkin.sql` | 新 RPC + 触发器修改 |
