import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'common_code_master_page.dart';
import 'delivery_destination_master_page.dart';
import 'driver_master_page.dart';
import 'freight_contract_master_page.dart';
import 'item_master_page.dart';
import 'partner_master_page.dart';
import 'route_zone_master_page.dart';
import 'user_access_master_page.dart';
import 'vehicle_master_page.dart';
import 'warehouse_hub_master_page.dart';

enum MasterModule {
  partner,
  deliveryDestination,
  routeZone,
  vehicle,
  driver,
  warehouseHub,
  item,
  freightContract,
  userAccess,
  commonCode;

  String get label => switch (this) {
    MasterModule.partner => '거래처',
    MasterModule.deliveryDestination => '배송처',
    MasterModule.routeZone => '권역/노선',
    MasterModule.vehicle => '차량',
    MasterModule.driver => '기사',
    MasterModule.warehouseHub => '창고/거점',
    MasterModule.item => '품목',
    MasterModule.freightContract => '운임/계약',
    MasterModule.userAccess => '사용자/권한',
    MasterModule.commonCode => '공통코드',
  };

  String get title => switch (this) {
    MasterModule.partner => '거래처 마스터',
    MasterModule.deliveryDestination => '배송처 마스터',
    MasterModule.routeZone => '권역/노선 마스터',
    MasterModule.vehicle => '차량 마스터',
    MasterModule.driver => '기사 마스터',
    MasterModule.warehouseHub => '창고/거점 마스터',
    MasterModule.item => '품목 마스터',
    MasterModule.freightContract => '운임/계약 마스터',
    MasterModule.userAccess => '사용자/권한 마스터',
    MasterModule.commonCode => '공통코드 마스터',
  };

  String get subtitle => switch (this) {
    MasterModule.partner => '고객사, 화주, 운송사',
    MasterModule.deliveryDestination => '납품처, 하차지, 시간창',
    MasterModule.routeZone => '권역, 허브, 대표 노선',
    MasterModule.vehicle => '차량번호, 톤급, 제원, 가용상태',
    MasterModule.driver => '기사, 면허, 안전, 근무상태',
    MasterModule.warehouseHub => '창고, 허브, RDC, 야드',
    MasterModule.item => 'SKU, 규격, 온도, 위험물',
    MasterModule.freightContract => '매출/매입 운임, 계약, 할증',
    MasterModule.userAccess => '사용자, 역할, 권한',
    MasterModule.commonCode => '상태, 유형, 채널, 시스템 코드',
  };

  IconData get icon => switch (this) {
    MasterModule.partner => Icons.business_rounded,
    MasterModule.deliveryDestination => Icons.store_mall_directory_rounded,
    MasterModule.routeZone => Icons.alt_route_rounded,
    MasterModule.vehicle => Icons.fire_truck_rounded,
    MasterModule.driver => Icons.badge_rounded,
    MasterModule.warehouseHub => Icons.warehouse_rounded,
    MasterModule.item => Icons.inventory_2_rounded,
    MasterModule.freightContract => Icons.request_quote_rounded,
    MasterModule.userAccess => Icons.admin_panel_settings_rounded,
    MasterModule.commonCode => Icons.tune_rounded,
  };

  Color get color => switch (this) {
    MasterModule.partner => AppTheme.teal,
    MasterModule.deliveryDestination => const Color(0xFF2563EB),
    MasterModule.routeZone => AppTheme.cyan,
    MasterModule.vehicle => AppTheme.amber,
    MasterModule.driver => const Color(0xFF16A34A),
    MasterModule.warehouseHub => const Color(0xFF0891B2),
    MasterModule.item => AppTheme.teal,
    MasterModule.freightContract => AppTheme.amber,
    MasterModule.userAccess => const Color(0xFF7C3AED),
    MasterModule.commonCode => const Color(0xFF2563EB),
  };
}

class MasterRegistrationPage extends StatefulWidget {
  const MasterRegistrationPage({
    required this.initialModule,
    super.key,
    this.compact = false,
  });

  final MasterModule initialModule;
  final bool compact;

  @override
  State<MasterRegistrationPage> createState() => _MasterRegistrationPageState();
}

class _MasterRegistrationPageState extends State<MasterRegistrationPage> {
  late MasterModule _selectedModule;

  @override
  void initState() {
    super.initState();
    _selectedModule = widget.initialModule;
  }

  @override
  void didUpdateWidget(covariant MasterRegistrationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialModule != widget.initialModule) {
      _selectedModule = widget.initialModule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_selectedModule) {
      MasterModule.partner => PartnerMasterPage(compact: widget.compact),
      MasterModule.deliveryDestination => DeliveryDestinationMasterPage(
        compact: widget.compact,
      ),
      MasterModule.routeZone => RouteZoneMasterPage(compact: widget.compact),
      MasterModule.vehicle => VehicleMasterPage(compact: widget.compact),
      MasterModule.driver => DriverMasterPage(compact: widget.compact),
      MasterModule.warehouseHub => WarehouseHubMasterPage(
        compact: widget.compact,
      ),
      MasterModule.item => ItemMasterPage(compact: widget.compact),
      MasterModule.freightContract => FreightContractMasterPage(
        compact: widget.compact,
      ),
      MasterModule.userAccess => UserAccessMasterPage(compact: widget.compact),
      MasterModule.commonCode => CommonCodeMasterPage(compact: widget.compact),
    };

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 16 : 24,
            widget.compact ? 16 : 20,
            widget.compact ? 16 : 24,
            0,
          ),
          child: _MasterModuleSelector(
            selectedModule: _selectedModule,
            onSelect: (module) => setState(() => _selectedModule = module),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _MasterModuleSelector extends StatelessWidget {
  const _MasterModuleSelector({
    required this.selectedModule,
    required this.onSelect,
  });

  final MasterModule selectedModule;
  final ValueChanged<MasterModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          if (compact) {
            return Column(
              children: MasterModule.values
                  .map(
                    (module) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ModuleButton(
                        module: module,
                        selected: selectedModule == module,
                        onTap: () => onSelect(module),
                      ),
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: MasterModule.values
                .map(
                  (module) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _ModuleButton(
                        module: module,
                        selected: selectedModule == module,
                        onTap: () => onSelect(module),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final MasterModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? module.color.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? module.color : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                module.icon,
                size: 20,
                color: selected ? module.color : AppTheme.slate,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected ? module.color : AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.subtitle,
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
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: module.color),
            ],
          ),
        ),
      ),
    );
  }
}
