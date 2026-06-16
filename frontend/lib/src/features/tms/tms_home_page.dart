import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/ktms_mark.dart';
import 'dispatch_planning_page.dart';
import 'execution_tracking_page.dart';
import 'load_planning_page.dart';
import 'master_registration_page.dart';
import 'order_registration_page.dart';
import 'performance_settlement_page.dart';

class TmsHomePage extends StatefulWidget {
  const TmsHomePage({
    required this.displayName,
    required this.email,
    required this.onSignOut,
    super.key,
  });

  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  State<TmsHomePage> createState() => _TmsHomePageState();
}

class _TmsHomePageState extends State<TmsHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return _MobileShell(
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
            displayName: widget.displayName,
            email: widget.email,
            onSignOut: widget.onSignOut,
          );
        }

        return _DesktopShell(
          selectedIndex: _selectedIndex,
          onSelect: (index) => setState(() => _selectedIndex = index),
          displayName: widget.displayName,
          email: widget.email,
          onSignOut: widget.onSignOut,
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.onSelect,
    required this.displayName,
    required this.email,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.panel,
      body: Row(
        children: [
          _SideNavigation(
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            displayName: displayName,
            email: email,
            onSignOut: onSignOut,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  displayName: displayName,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                ),
                Expanded(
                  child: _WorkspaceContent(
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.onSelect,
    required this.displayName,
    required this.email,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.panel,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: const Row(
          children: [
            KtmsMark(size: 34),
            SizedBox(width: 10),
            Text(
              'KTMS',
              style: TextStyle(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _WorkspaceContent(
        selectedIndex: selectedIndex,
        compact: true,
        onSelect: onSelect,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, 4),
        onDestinationSelected: onSelect,
        height: 68,
        destinations: _mobileNavItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selectedIndex,
    required this.onSelect,
    required this.displayName,
    required this.email,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 274,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Row(
                children: [
                  const KtmsMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KTMS',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.graphite,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                        Text(
                          'Enterprise TMS',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.slate,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                children: [
                  _NavSection(
                    label: '운영',
                    items: _primaryNavItems,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                    offset: 0,
                  ),
                  const SizedBox(height: 20),
                  _NavSection(
                    label: '업무',
                    items: _businessNavItems,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                    offset: _primaryNavItems.length,
                  ),
                  const SizedBox(height: 20),
                  _NavSection(
                    label: '마스터',
                    items: _masterNavItems,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                    offset: _primaryNavItems.length + _businessNavItems.length,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _UserPanel(
                displayName: displayName,
                email: email,
                onSignOut: onSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.label,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.offset,
  });

  final String label;
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final int offset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < items.length; index++)
          _NavigationTile(
            item: items[index],
            selected: selectedIndex == index + offset,
            onTap: () => onSelect(index + offset),
          ),
      ],
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.teal.withValues(alpha: 0.09) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: selected ? AppTheme.teal : AppTheme.slate,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppTheme.teal : AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (item.badge != null)
                  _Badge(
                    label: item.badge!,
                    color: selected ? AppTheme.teal : AppTheme.slate,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.displayName,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String displayName;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final masterModule = _masterModuleForSelectedIndex(selectedIndex);
    final title = selectedIndex == 1
        ? '오더 등록'
        : selectedIndex == 2
        ? '편성/상차조합'
        : selectedIndex == 3
        ? '배정/배차'
        : selectedIndex == 4
        ? '실행 트래킹'
        : selectedIndex == 5
        ? '실적 확정'
        : selectedIndex == 6
        ? '정산 관리'
        : masterModule == null
        ? 'TMS 운영 관제'
        : masterModule == MasterModule.partner
        ? '마스터 등록'
        : masterModule.title;
    final subtitle = selectedIndex == 1
        ? '고객사, 화주, 상하차지, 품목, 운송조건, 청구운임'
        : selectedIndex == 2
        ? '미편성 오더를 상차조합으로 묶고 적재율, 시간창, SLA를 검토'
        : selectedIndex == 3
        ? '확정 조합을 운송사, 차량, 기사에 배정하고 배차지시 발행'
        : selectedIndex == 4
        ? '네이버 지도 기반 차량 위치, 운송 경로, 출발/도착 이벤트 관제'
        : selectedIndex == 5
        ? '운송 완료 실적, POD, 온도/도착 차이를 검토해 정산 기준 확정'
        : selectedIndex == 6
        ? '매출정산과 매입정산을 분리해 거래명세서와 지급 기준 생성'
        : masterModule == null
        ? '오더 등록부터 배차 실행, 실적 확정, 정산까지'
        : '고객사, 화주, 운송사, 배송처, 권역/노선, 차량, 기사, 창고/거점 기준정보';

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.graphite,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slate,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            _QuickCommandButton(
              icon: Icons.add_road_rounded,
              label: '오더 등록',
              filled: true,
              onPressed: () => onSelect(1),
            ),
            const SizedBox(width: 10),
            _QuickCommandButton(
              icon: Icons.alt_route_rounded,
              label: '상차조합',
              onPressed: () => onSelect(2),
            ),
            const SizedBox(width: 10),
            _QuickCommandButton(
              icon: Icons.local_shipping_rounded,
              label: '배차 생성',
              onPressed: () => onSelect(3),
            ),
            const SizedBox(width: 18),
            _IconAction(icon: Icons.search_rounded, tooltip: '검색'),
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.notifications_none_rounded,
              tooltip: '알림',
              badge: '7',
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.selectedIndex,
    required this.onSelect,
    this.compact = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final masterModule = _masterModuleForSelectedIndex(
      selectedIndex,
      compact: compact,
    );
    if (masterModule != null) {
      return MasterRegistrationPage(
        compact: compact,
        initialModule: masterModule,
      );
    }

    if (selectedIndex == 1) {
      return OrderRegistrationPage(compact: compact);
    }

    if (selectedIndex == 2) {
      return LoadPlanningPage(compact: compact);
    }

    if (selectedIndex == 3) {
      return DispatchPlanningPage(compact: compact);
    }

    if (selectedIndex == 4) {
      return ExecutionTrackingPage(compact: compact);
    }

    if (selectedIndex == 5) {
      return PerformanceSettlementPage(
        compact: compact,
        initialTab: SettlementWorkspaceTab.performance,
      );
    }

    if (selectedIndex == 6) {
      return PerformanceSettlementPage(
        compact: compact,
        initialTab: SettlementWorkspaceTab.revenue,
      );
    }

    return _ControlDashboard(compact: compact, onMasterSelect: onSelect);
  }
}

class _ControlDashboard extends StatelessWidget {
  const _ControlDashboard({required this.onMasterSelect, this.compact = false});

  final bool compact;
  final ValueChanged<int> onMasterSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 18 : 22,
        compact ? 16 : 24,
        compact ? 90 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            const _MobileHero(),
            const SizedBox(height: 16),
            _MobileActionRail(onSelect: onMasterSelect),
            const SizedBox(height: 16),
          ],
          const _MetricStrip(),
          const SizedBox(height: 18),
          const _WorkflowBoard(),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 1180;
              if (!twoColumn) {
                return Column(
                  children: [
                    const _OperationsBoard(),
                    const SizedBox(height: 18),
                    _TrackingPanel(onOpenTracking: () => onMasterSelect(4)),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 13, child: _OperationsBoard()),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 9,
                    child: _TrackingPanel(
                      onOpenTracking: () => onMasterSelect(4),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 1180;
              if (!twoColumn) {
                return Column(
                  children: [
                    const _SettlementPanel(),
                    const SizedBox(height: 18),
                    _MasterDirectory(onMasterSelect: onMasterSelect),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 10, child: _SettlementPanel()),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 12,
                    child: _MasterDirectory(onMasterSelect: onMasterSelect),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileHero extends StatelessWidget {
  const _MobileHero();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '운영 관제',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '오더, 편성, 배정, 배차, 실행, 정산을 한 화면에서 관리합니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.slate,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileActionRail extends StatelessWidget {
  const _MobileActionRail({required this.onSelect});

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ActionChipButton(
            icon: Icons.add_road_rounded,
            label: '오더 등록',
            selected: true,
            onTap: () => onSelect(1),
          ),
          _ActionChipButton(
            icon: Icons.alt_route_rounded,
            label: '상차조합',
            onTap: () => onSelect(2),
          ),
          _ActionChipButton(
            icon: Icons.assignment_ind_rounded,
            label: '배정',
            onTap: () => onSelect(3),
          ),
          _ActionChipButton(
            icon: Icons.map_rounded,
            label: '실행',
            onTap: () => onSelect(4),
          ),
          _ActionChipButton(
            icon: Icons.payments_rounded,
            label: '정산',
            onTap: () => onSelect(6),
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1240
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _metrics
              .map(
                (metric) => SizedBox(width: width, child: _MetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      height: 118,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  metric.delta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: metric.color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowBoard extends StatelessWidget {
  const _WorkflowBoard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.timeline_rounded,
            title: '운송 업무 흐름',
            subtitle: '오더 등록부터 정산 확정까지',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth >= 1180
                  ? (constraints.maxWidth - 88) / 9
                  : constraints.maxWidth >= 720
                  ? 148.0
                  : 132.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < _workflow.length; index++) ...[
                      SizedBox(
                        width: itemWidth,
                        child: _WorkflowStageTile(
                          stage: _workflow[index],
                          active: index <= 5,
                        ),
                      ),
                      if (index != _workflow.length - 1)
                        const SizedBox(
                          width: 11,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.muted,
                            size: 20,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkflowStageTile extends StatelessWidget {
  const _WorkflowStageTile({required this.stage, required this.active});

  final _WorkflowStage stage;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? stage.color : AppTheme.muted;
    return Container(
      height: 118,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.28) : AppTheme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stage.icon, color: color, size: 22),
          const Spacer(),
          Text(
            stage.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            stage.count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsBoard extends StatelessWidget {
  const _OperationsBoard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.view_kanban_rounded,
            title: '오늘 배차 운영',
            subtitle: '상차조합, 배정, 운송계획 진행 현황',
          ),
          const SizedBox(height: 16),
          for (final task in _planTasks) ...[
            _PlanTaskRow(task: task),
            if (task != _planTasks.last)
              const Divider(height: 20, color: AppTheme.line),
          ],
        ],
      ),
    );
  }
}

class _PlanTaskRow extends StatelessWidget {
  const _PlanTaskRow({required this.task});

  final _PlanTask task;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: task.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(task.icon, color: task.color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _Badge(label: task.status, color: task.color),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 7,
                  backgroundColor: AppTheme.line,
                  valueColor: AlwaysStoppedAnimation<Color>(task.color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.onOpenTracking});

  final VoidCallback onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '실행 트래킹 열기',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onOpenTracking,
          borderRadius: BorderRadius.circular(8),
          child: _Panel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeader(
                  icon: Icons.map_rounded,
                  title: '실행 트래킹',
                  subtitle: '출발, 도착, 완료 이벤트 모니터링',
                ),
                const SizedBox(height: 16),
                const _MapPreview(),
                const SizedBox(height: 16),
                for (final event in _routeEvents) ...[
                  _RouteEventRow(event: event),
                  if (event != _routeEvents.last)
                    const Divider(height: 18, color: AppTheme.line),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CustomPaint(
        painter: const _MapPreviewPainter(),
        child: Stack(
          children: [
            Positioned(
              left: 14,
              top: 14,
              child: _MapBadge(
                icon: Icons.gps_fixed_rounded,
                label: 'LIVE 42대',
                color: AppTheme.cyan,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: _MapBadge(
                icon: Icons.warning_amber_rounded,
                label: '지연 3건',
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteEventRow extends StatelessWidget {
  const _RouteEventRow({required this.event});

  final _RouteEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: event.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(event.icon, color: event.color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                event.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        Text(
          event.time,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SettlementPanel extends StatelessWidget {
  const _SettlementPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.receipt_long_rounded,
            title: '실적 확정 및 정산',
            subtitle: '매출/매입 거래명세서 생성 대기',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SettlementSummary(
                  label: '매출 예정',
                  value: '₩184.6M',
                  color: AppTheme.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SettlementSummary(
                  label: '매입 예정',
                  value: '₩129.8M',
                  color: AppTheme.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in _ledgerItems) ...[
            _LedgerRow(item: item),
            if (item != _ledgerItems.last)
              const Divider(height: 18, color: AppTheme.line),
          ],
        ],
      ),
    );
  }
}

class _SettlementSummary extends StatelessWidget {
  const _SettlementSummary({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.item});

  final _LedgerItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Badge(label: item.status, color: item.color),
      ],
    );
  }
}

class _MasterDirectory extends StatelessWidget {
  const _MasterDirectory({required this.onMasterSelect});

  final ValueChanged<int> onMasterSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.dataset_rounded,
            title: '마스터 등록',
            subtitle: '운영 기준정보와 권한 관리',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 2;
              final spacing = 10.0;
              final width =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _masterItems
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _MasterTile(
                          item: item,
                          onTap: item.navOffset == null
                              ? null
                              : () => onMasterSelect(
                                  _masterNavStartIndex + item.navOffset!,
                                ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  const _MasterTile({required this.item, required this.onTap});

  final _MasterItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 82,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, color: item.color, size: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.muted,
                      size: 18,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.graphite,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding, this.height});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

class _QuickCommandButton extends StatelessWidget {
  const _QuickCommandButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(minimumSize: const Size(118, 42)),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size(118, 42)),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(
          icon,
          color: selected ? Colors.white : AppTheme.teal,
          size: 18,
        ),
        label: Text(label),
        backgroundColor: selected ? AppTheme.teal : Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.graphite,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        side: BorderSide(color: selected ? AppTheme.teal : AppTheme.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.tooltip, this.badge});

  final IconData icon;
  final String tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            tooltip: tooltip,
            onPressed: () {},
            icon: Icon(icon, color: AppTheme.ink),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -1,
            top: -2,
            child: _Badge(label: badge!, color: const Color(0xFFDC2626)),
          ),
      ],
    );
  }
}

class _UserPanel extends StatelessWidget {
  const _UserPanel({
    required this.displayName,
    required this.email,
    required this.onSignOut,
  });

  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              displayName.isNotEmpty ? displayName.characters.first : 'K',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, color: AppTheme.slate),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF111827);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      background,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = size.width * 0.12; x < size.width; x += size.width * 0.16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = size.height * 0.18; y < size.height; y += size.height * 0.18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePaint = Paint()
      ..color = AppTheme.cyan
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route = Path()
      ..moveTo(size.width * 0.1, size.height * 0.72)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.48,
        size.width * 0.36,
        size.height * 0.78,
        size.width * 0.52,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.18,
        size.width * 0.78,
        size.height * 0.38,
        size.width * 0.9,
        size.height * 0.24,
      );
    canvas.drawPath(route, routePaint);

    final routeGlow = Paint()
      ..color = AppTheme.cyan.withValues(alpha: 0.18)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routeGlow);

    for (final marker in <({Offset point, Color color})>[
      (
        point: Offset(size.width * 0.1, size.height * 0.72),
        color: AppTheme.teal,
      ),
      (
        point: Offset(size.width * 0.52, size.height * 0.44),
        color: AppTheme.amber,
      ),
      (
        point: Offset(size.width * 0.9, size.height * 0.24),
        color: const Color(0xFF22C55E),
      ),
    ]) {
      canvas.drawCircle(
        marker.point,
        8,
        Paint()..color = marker.color.withValues(alpha: 0.2),
      );
      canvas.drawCircle(marker.point, 4.5, Paint()..color = marker.color);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) => false;
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? badge;
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;
}

class _WorkflowStage {
  const _WorkflowStage({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;
}

class _PlanTask {
  const _PlanTask({
    required this.title,
    required this.description,
    required this.status,
    required this.progress,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final String status;
  final double progress;
  final IconData icon;
  final Color color;
}

class _RouteEvent {
  const _RouteEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;
}

class _LedgerItem {
  const _LedgerItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color color;
}

class _MasterItem {
  const _MasterItem({
    required this.label,
    required this.icon,
    required this.color,
    this.navOffset,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int? navOffset;
}

int get _masterNavStartIndex =>
    _primaryNavItems.length + _businessNavItems.length;

MasterModule? _masterModuleForSelectedIndex(
  int selectedIndex, {
  bool compact = false,
}) {
  final relativeIndex = selectedIndex - _masterNavStartIndex;
  return switch (relativeIndex) {
    0 => MasterModule.partner,
    1 => MasterModule.deliveryDestination,
    2 => MasterModule.routeZone,
    3 => MasterModule.vehicle,
    4 => MasterModule.driver,
    5 => MasterModule.warehouseHub,
    6 => MasterModule.item,
    7 => MasterModule.freightContract,
    8 => MasterModule.userAccess,
    9 => MasterModule.commonCode,
    _ => null,
  };
}

const _primaryNavItems = [
  _NavItem(
    label: '관제 대시보드',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    badge: 'LIVE',
  ),
  _NavItem(
    label: '오더 등록',
    icon: Icons.add_road_outlined,
    selectedIcon: Icons.add_road_rounded,
  ),
  _NavItem(
    label: '편성/상차조합',
    icon: Icons.alt_route_outlined,
    selectedIcon: Icons.alt_route_rounded,
    badge: '18',
  ),
  _NavItem(
    label: '배정/배차',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
  ),
  _NavItem(
    label: '실행 트래킹',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map_rounded,
  ),
];

const _businessNavItems = [
  _NavItem(
    label: '실적 확정',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check_rounded,
  ),
  _NavItem(
    label: '정산 관리',
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
  ),
  _NavItem(
    label: '거래명세서',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  _NavItem(
    label: '리포트',
    icon: Icons.query_stats_outlined,
    selectedIcon: Icons.query_stats_rounded,
  ),
];

const _masterNavItems = [
  _NavItem(
    label: '마스터 등록',
    icon: Icons.dataset_outlined,
    selectedIcon: Icons.dataset_rounded,
  ),
  _NavItem(
    label: '배송처 마스터',
    icon: Icons.store_mall_directory_outlined,
    selectedIcon: Icons.store_mall_directory_rounded,
  ),
  _NavItem(
    label: '권역/노선 마스터',
    icon: Icons.alt_route_outlined,
    selectedIcon: Icons.alt_route_rounded,
  ),
  _NavItem(
    label: '차량 마스터',
    icon: Icons.fire_truck_outlined,
    selectedIcon: Icons.fire_truck_rounded,
  ),
  _NavItem(
    label: '기사 마스터',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge_rounded,
  ),
  _NavItem(
    label: '창고/거점 마스터',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse_rounded,
  ),
  _NavItem(
    label: '품목 마스터',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
  ),
  _NavItem(
    label: '운임/계약 마스터',
    icon: Icons.request_quote_outlined,
    selectedIcon: Icons.request_quote_rounded,
  ),
  _NavItem(
    label: '사용자/권한',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings_rounded,
  ),
  _NavItem(
    label: '공통코드 마스터',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune_rounded,
  ),
  _NavItem(
    label: '시스템 설정',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune_rounded,
  ),
];

const _mobileNavItems = [
  _NavItem(
    label: '관제',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  _NavItem(
    label: '오더',
    icon: Icons.add_road_outlined,
    selectedIcon: Icons.add_road_rounded,
  ),
  _NavItem(
    label: '편성',
    icon: Icons.alt_route_outlined,
    selectedIcon: Icons.alt_route_rounded,
  ),
  _NavItem(
    label: '배차',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
  ),
  _NavItem(
    label: '실행',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map_rounded,
  ),
];

const _metrics = [
  _Metric(
    label: '오늘 오더',
    value: '286',
    delta: '+32 신규',
    icon: Icons.playlist_add_check_rounded,
    color: AppTheme.teal,
  ),
  _Metric(
    label: '배차 진행',
    value: '142',
    delta: '계획 대비 83%',
    icon: Icons.local_shipping_rounded,
    color: AppTheme.cyan,
  ),
  _Metric(
    label: '실행 중',
    value: '64',
    delta: '지연 3건',
    icon: Icons.route_rounded,
    color: Color(0xFF2563EB),
  ),
  _Metric(
    label: '정산 대기',
    value: '₩184.6M',
    delta: '확정 51건',
    icon: Icons.receipt_long_rounded,
    color: AppTheme.amber,
  ),
];

const _workflow = [
  _WorkflowStage(
    label: '오더 등록',
    count: '286건',
    icon: Icons.add_road_rounded,
    color: AppTheme.teal,
  ),
  _WorkflowStage(
    label: '편성',
    count: '92건',
    icon: Icons.alt_route_rounded,
    color: AppTheme.cyan,
  ),
  _WorkflowStage(
    label: '배정',
    count: '74건',
    icon: Icons.assignment_ind_rounded,
    color: Color(0xFF2563EB),
  ),
  _WorkflowStage(
    label: '배차계획',
    count: '68건',
    icon: Icons.event_note_rounded,
    color: Color(0xFF7C3AED),
  ),
  _WorkflowStage(
    label: '출발',
    count: '42건',
    icon: Icons.flag_rounded,
    color: Color(0xFF16A34A),
  ),
  _WorkflowStage(
    label: '도착',
    count: '21건',
    icon: Icons.pin_drop_rounded,
    color: AppTheme.amber,
  ),
  _WorkflowStage(
    label: '완료',
    count: '18건',
    icon: Icons.task_alt_rounded,
    color: Color(0xFF059669),
  ),
  _WorkflowStage(
    label: '실적확정',
    count: '51건',
    icon: Icons.fact_check_rounded,
    color: Color(0xFF0891B2),
  ),
  _WorkflowStage(
    label: '정산',
    count: '34건',
    icon: Icons.payments_rounded,
    color: Color(0xFFB45309),
  ),
];

const _planTasks = [
  _PlanTask(
    title: '상차조합 자동 편성',
    description: '수도권 냉장 18오더를 7대 차량으로 조합 중',
    status: '편성',
    progress: 0.72,
    icon: Icons.alt_route_rounded,
    color: AppTheme.cyan,
  ),
  _PlanTask(
    title: '운송사 배정 검토',
    description: '장거리 간선 12건 SLA 단가와 가용 차량 비교',
    status: '배정',
    progress: 0.58,
    icon: Icons.assignment_ind_rounded,
    color: Color(0xFF2563EB),
  ),
  _PlanTask(
    title: '배차 운송계획 확정',
    description: '부산 RDC 출발 23:00 이전 출발 가능 차량 확인',
    status: '확정대기',
    progress: 0.86,
    icon: Icons.event_available_rounded,
    color: AppTheme.teal,
  ),
];

const _routeEvents = [
  _RouteEvent(
    title: 'KT-20260606-0814 출발',
    subtitle: '안산 물류센터 → 대전 허브',
    time: '09:12',
    icon: Icons.flag_rounded,
    color: Color(0xFF16A34A),
  ),
  _RouteEvent(
    title: 'KT-20260606-0772 도착',
    subtitle: '인천 CY → 이천 RDC',
    time: '08:56',
    icon: Icons.pin_drop_rounded,
    color: AppTheme.amber,
  ),
  _RouteEvent(
    title: 'KT-20260606-0698 완료',
    subtitle: 'POD 서명 및 온도 로그 수신',
    time: '08:31',
    icon: Icons.task_alt_rounded,
    color: AppTheme.teal,
  ),
];

const _ledgerItems = [
  _LedgerItem(
    title: '매출 거래명세서 생성',
    subtitle: '화주 14개사 / 51건 실적 확정',
    status: '대기',
    color: AppTheme.teal,
  ),
  _LedgerItem(
    title: '매입 거래명세서 검증',
    subtitle: '운송사 9개사 / 유류할증 3건 확인',
    status: '검증',
    color: AppTheme.amber,
  ),
  _LedgerItem(
    title: '정산 차이 조정',
    subtitle: '하차대기료 2건, 회차비 1건',
    status: '이슈',
    color: Color(0xFFDC2626),
  ),
];

const _masterItems = [
  _MasterItem(
    label: '고객사',
    icon: Icons.business_rounded,
    color: AppTheme.teal,
    navOffset: 0,
  ),
  _MasterItem(
    label: '화주',
    icon: Icons.apartment_rounded,
    color: AppTheme.cyan,
    navOffset: 0,
  ),
  _MasterItem(
    label: '배송처',
    icon: Icons.store_mall_directory_rounded,
    color: Color(0xFF2563EB),
    navOffset: 1,
  ),
  _MasterItem(
    label: '운송사',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFF7C3AED),
    navOffset: 0,
  ),
  _MasterItem(
    label: '차량',
    icon: Icons.fire_truck_rounded,
    color: AppTheme.amber,
    navOffset: 3,
  ),
  _MasterItem(
    label: '기사',
    icon: Icons.badge_rounded,
    color: Color(0xFF16A34A),
    navOffset: 4,
  ),
  _MasterItem(
    label: '권역/노선',
    icon: Icons.map_rounded,
    color: AppTheme.cyan,
    navOffset: 2,
  ),
  _MasterItem(
    label: '품목',
    icon: Icons.inventory_2_rounded,
    color: AppTheme.teal,
    navOffset: 6,
  ),
  _MasterItem(
    label: '운임/계약',
    icon: Icons.request_quote_rounded,
    color: AppTheme.amber,
    navOffset: 7,
  ),
  _MasterItem(
    label: '창고/거점',
    icon: Icons.warehouse_rounded,
    color: Color(0xFF2563EB),
    navOffset: 5,
  ),
  _MasterItem(
    label: '사용자/권한',
    icon: Icons.admin_panel_settings_rounded,
    color: Color(0xFF7C3AED),
    navOffset: 8,
  ),
  _MasterItem(
    label: '공통코드',
    icon: Icons.tune_rounded,
    color: Color(0xFF2563EB),
    navOffset: 9,
  ),
];
