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
      filterOptions: const ['全部', '待打卡', '未完成', '已完成'],
      plans: allPlans,
      planCountLabel: '共 ${allPlans.length} 个计划',
      owner: PlanOwner.me,
      onRefresh: context.read<Store>().refreshPlans,
      isInitialLoading:
          store.isInitialPlansLoading && !store.hasHydratedPlanCache,
      isSyncing: store.isRefreshingPlans && store.hasHydratedPlanCache,
      syncErrorMessage: store.planSyncErrorMessage,
      onDeletePlan: (plan) => context.read<Store>().deletePlan(plan.id),
      onQuickCheckin: (plan) => context.read<Store>().saveCheckin(
        planId: plan.id,
        completed: true,
        mood: CheckinMood.happy,
        note: '',
      ),
      onAdd: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CreatePlanPage(defaultOwner: PlanOwner.me),
          ),
        );
      },
      onTapPlan: (plan) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlanDetailPage(planId: plan.id),
          ),
        );
      },
    );
  }
}
