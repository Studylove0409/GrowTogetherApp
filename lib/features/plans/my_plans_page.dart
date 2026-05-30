import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import 'create_plan_page.dart';
import 'plan_detail_page.dart';
import 'plan_list_scaffold.dart';

class MyPlansPage extends StatelessWidget {
  const MyPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final allPlans = store.getPlansByOwner(PlanOwner.me);
    return PlanListScaffold(
      title: '我的计划',
      filterOptions: const ['全部', '待打卡', '已完成'],
      plans: allPlans,
      planCountLabel: '共 ${allPlans.length} 个计划',
      owner: PlanOwner.me,
      onRefresh: context.read<Store>().refreshPlans,
      isInitialLoading:
          store.isInitialPlansLoading && !store.hasHydratedPlanCache,
      isSyncing: store.isRefreshingPlans && store.hasHydratedPlanCache,
      syncErrorMessage: store.planSyncErrorMessage,
      onDeletePlan: (plan) => context.read<Store>().deletePlan(plan.id),
      onQuickCheckin: (plan, selectedDate, completed) =>
          context.read<Store>().saveCheckin(
            planId: plan.id,
            completed: completed,
            mood: CheckinMood.happy,
            note: '',
            date: selectedDate,
          ),
      onAdd: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CreatePlanPage(defaultOwner: PlanOwner.me),
          ),
        );
      },
      onTapPlan: (plan, selectedDate) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PlanDetailPage(planId: plan.id, targetDate: selectedDate),
          ),
        );
      },
    );
  }
}
