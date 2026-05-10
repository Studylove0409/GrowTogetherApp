import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store/store.dart';
import '../../data/models/plan.dart';
import 'plan_detail_page.dart';
import 'plan_list_scaffold.dart';

class PartnerPlansPage extends StatelessWidget {
  const PartnerPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final allPlans = store.getPlansByOwner(PlanOwner.partner);
    return PlanListScaffold(
      title: 'TA 的计划',
      filterOptions: const ['全部', '待打卡', '未完成', '已完成'],
      plans: allPlans,
      planCountLabel: '共 ${allPlans.length} 个计划',
      owner: PlanOwner.partner,
      showAddButton: false,
      onRefresh: context.read<Store>().refreshPlans,
      onAdd: () {},
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
