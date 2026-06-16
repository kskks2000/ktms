import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class RouteZoneMasterPage extends StatefulWidget {
  const RouteZoneMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<RouteZoneMasterPage> createState() => _RouteZoneMasterPageState();
}

class _RouteZoneMasterPageState extends State<RouteZoneMasterPage> {
  final _zoneCodeController = TextEditingController();
  final _zoneNameController = TextEditingController();
  final _parentZoneController = TextEditingController();
  final _regionManagerController = TextEditingController();
  final _hubController = TextEditingController();
  final _cutoffController = TextEditingController();
  final _zoneMemoController = TextEditingController();
  final _routeCodeController = TextEditingController();
  final _routeNameController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _routeZoneController = TextEditingController();
  final _serviceLevelController = TextEditingController();
  final _distanceController = TextEditingController();
  final _leadTimeController = TextEditingController();
  final _baseFareController = TextEditingController();
  final _vehicleLimitController = TextEditingController();
  final _routeMemoController = TextEditingController();

  late final List<_ZoneRecord> _zones;
  late final List<_RouteRecord> _routes;
  _RouteMasterMode _mode = _RouteMasterMode.zone;
  String _query = '';
  String _statusFilter = 'ALL';
  int? _selectedZoneId;
  int? _selectedRouteId;
  bool _zoneActive = true;
  bool _routeActive = true;
  bool _appointmentRequired = false;
  bool _tollIncluded = true;
  bool _temperatureControl = false;

  @override
  void initState() {
    super.initState();
    _zones = List<_ZoneRecord>.from(_seedZones);
    _routes = List<_RouteRecord>.from(_seedRoutes);
    _selectZone(_zones.first, notify: false);
  }

  @override
  void dispose() {
    _zoneCodeController.dispose();
    _zoneNameController.dispose();
    _parentZoneController.dispose();
    _regionManagerController.dispose();
    _hubController.dispose();
    _cutoffController.dispose();
    _zoneMemoController.dispose();
    _routeCodeController.dispose();
    _routeNameController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _routeZoneController.dispose();
    _serviceLevelController.dispose();
    _distanceController.dispose();
    _leadTimeController.dispose();
    _baseFareController.dispose();
    _vehicleLimitController.dispose();
    _routeMemoController.dispose();
    super.dispose();
  }

  List<_ZoneRecord> get _filteredZones {
    final normalizedQuery = _query.trim().toLowerCase();
    return _zones.where((zone) {
      final matchesStatus =
          _statusFilter == 'ALL' || zone.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          zone.zoneCode.toLowerCase().contains(normalizedQuery) ||
          zone.zoneName.toLowerCase().contains(normalizedQuery) ||
          zone.parentZone.toLowerCase().contains(normalizedQuery) ||
          zone.regionManager.toLowerCase().contains(normalizedQuery) ||
          zone.hubName.toLowerCase().contains(normalizedQuery);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  List<_RouteRecord> get _filteredRoutes {
    final normalizedQuery = _query.trim().toLowerCase();
    return _routes.where((route) {
      final matchesStatus =
          _statusFilter == 'ALL' || route.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          route.routeCode.toLowerCase().contains(normalizedQuery) ||
          route.routeName.toLowerCase().contains(normalizedQuery) ||
          route.originName.toLowerCase().contains(normalizedQuery) ||
          route.destinationName.toLowerCase().contains(normalizedQuery) ||
          route.zoneName.toLowerCase().contains(normalizedQuery);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  _ZoneRecord? get _selectedZone {
    for (final zone in _zones) {
      if (zone.id == _selectedZoneId) {
        return zone;
      }
    }
    return null;
  }

  _RouteRecord? get _selectedRoute {
    for (final route in _routes) {
      if (route.id == _selectedRouteId) {
        return route;
      }
    }
    return null;
  }

  void _selectMode(_RouteMasterMode mode) {
    setState(() {
      _mode = mode;
      _query = '';
      _statusFilter = 'ALL';
      if (mode == _RouteMasterMode.zone) {
        _selectZone(_selectedZone ?? _zones.first, notify: false);
      } else {
        _selectRoute(_selectedRoute ?? _routes.first, notify: false);
      }
    });
  }

  void _selectZone(_ZoneRecord zone, {bool notify = true}) {
    void apply() {
      _selectedZoneId = zone.id;
      _zoneCodeController.text = zone.zoneCode;
      _zoneNameController.text = zone.zoneName;
      _parentZoneController.text = zone.parentZone;
      _regionManagerController.text = zone.regionManager;
      _hubController.text = zone.hubName;
      _cutoffController.text = zone.cutoffTime;
      _zoneMemoController.text = zone.memo;
      _zoneActive = zone.isActive;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _selectRoute(_RouteRecord route, {bool notify = true}) {
    void apply() {
      _selectedRouteId = route.id;
      _routeCodeController.text = route.routeCode;
      _routeNameController.text = route.routeName;
      _originController.text = route.originName;
      _destinationController.text = route.destinationName;
      _routeZoneController.text = route.zoneName;
      _serviceLevelController.text = route.serviceLevel;
      _distanceController.text = route.distanceKm.toString();
      _leadTimeController.text = route.leadTimeHours.toString();
      _baseFareController.text = route.baseFare.replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      _vehicleLimitController.text = route.vehicleLimit;
      _routeMemoController.text = route.memo;
      _routeActive = route.isActive;
      _appointmentRequired = route.appointmentRequired;
      _tollIncluded = route.tollIncluded;
      _temperatureControl = route.temperatureControl;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _startCreate() {
    setState(() {
      if (_mode == _RouteMasterMode.zone) {
        _selectedZoneId = null;
        _zoneCodeController.text =
            'ZONE${(_zones.length + 1).toString().padLeft(3, '0')}';
        _zoneNameController.clear();
        _parentZoneController.text = '전국';
        _regionManagerController.text = '운영1팀';
        _hubController.clear();
        _cutoffController.text = '17:00';
        _zoneMemoController.clear();
        _zoneActive = true;
      } else {
        _selectedRouteId = null;
        _routeCodeController.text =
            'RTE${(_routes.length + 1).toString().padLeft(4, '0')}';
        _routeNameController.clear();
        _originController.clear();
        _destinationController.clear();
        _routeZoneController.text = _zones.first.zoneName;
        _serviceLevelController.text = '익일';
        _distanceController.text = '0';
        _leadTimeController.text = '0';
        _baseFareController.text = '0';
        _vehicleLimitController.text = '11톤 이하';
        _routeMemoController.clear();
        _routeActive = true;
        _appointmentRequired = false;
        _tollIncluded = true;
        _temperatureControl = false;
      }
    });
  }

  void _saveZone() async {
    final zoneName = _zoneNameController.text.trim();
    if (zoneName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('권역명을 입력하세요.')));
      return;
    }

    final record = _ZoneRecord(
      id: _selectedZoneId ?? _nextZoneId(),
      zoneCode: _zoneCodeController.text.trim(),
      zoneName: zoneName,
      parentZone: _parentZoneController.text.trim(),
      regionManager: _regionManagerController.text.trim(),
      hubName: _hubController.text.trim(),
      cutoffTime: _cutoffController.text.trim(),
      destinationCount: _selectedZone?.destinationCount ?? 0,
      activeRouteCount: _selectedZone?.activeRouteCount ?? 0,
      todayOrderCount: _selectedZone?.todayOrderCount ?? 0,
      statusCode: _zoneActive ? 'ACTIVE' : 'INACTIVE',
      isActive: _zoneActive,
      memo: _zoneMemoController.text.trim(),
    );

    setState(() {
      final index = _zones.indexWhere((item) => item.id == record.id);
      if (index == -1) {
        _zones.insert(0, record);
      } else {
        _zones[index] = record;
      }
      _selectedZoneId = record.id;
    });

    final result = await MasterApi.instance.saveGeoZone(record.toApiPayload());
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.zoneName} 권역 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.zoneName} 권역이 반영되었습니다.',
        ),
      ),
    );
  }

  void _saveRoute() async {
    final routeName = _routeNameController.text.trim();
    if (routeName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('노선명을 입력하세요.')));
      return;
    }

    final record = _RouteRecord(
      id: _selectedRouteId ?? _nextRouteId(),
      routeCode: _routeCodeController.text.trim(),
      routeName: routeName,
      originName: _originController.text.trim(),
      destinationName: _destinationController.text.trim(),
      zoneName: _routeZoneController.text.trim(),
      serviceLevel: _serviceLevelController.text.trim(),
      distanceKm: int.tryParse(_distanceController.text.trim()) ?? 0,
      leadTimeHours: int.tryParse(_leadTimeController.text.trim()) ?? 0,
      baseFare: _baseFareController.text.trim(),
      vehicleLimit: _vehicleLimitController.text.trim(),
      todayOrderCount: _selectedRoute?.todayOrderCount ?? 0,
      onTimeRate: _selectedRoute?.onTimeRate ?? 98.0,
      statusCode: _routeActive ? 'ACTIVE' : 'INACTIVE',
      isActive: _routeActive,
      appointmentRequired: _appointmentRequired,
      tollIncluded: _tollIncluded,
      temperatureControl: _temperatureControl,
      memo: _routeMemoController.text.trim(),
    );

    setState(() {
      final index = _routes.indexWhere((item) => item.id == record.id);
      if (index == -1) {
        _routes.insert(0, record);
      } else {
        _routes[index] = record;
      }
      _selectedRouteId = record.id;
    });

    final result = await MasterApi.instance.saveTransportRoute(
      record.toApiPayload(),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.routeName} 노선 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.routeName} 노선이 반영되었습니다.',
        ),
      ),
    );
  }

  int _nextZoneId() {
    return _zones.map((zone) => zone.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  int _nextRouteId() {
    return _routes.map((route) => route.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final filteredZones = _filteredZones;
    final filteredRoutes = _filteredRoutes;
    final selectedZone = _selectedZone;
    final selectedRoute = _selectedRoute;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 16 : 24,
        widget.compact ? 18 : 22,
        widget.compact ? 16 : 24,
        widget.compact ? 90 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RouteZoneHeader(
            mode: _mode,
            totalCount: _mode == _RouteMasterMode.zone
                ? filteredZones.length
                : filteredRoutes.length,
            activeCount: _mode == _RouteMasterMode.zone
                ? filteredZones.where((zone) => zone.isActive).length
                : filteredRoutes.where((route) => route.isActive).length,
            onCreate: _startCreate,
          ),
          const SizedBox(height: 16),
          _ModeSelector(
            selectedMode: _mode,
            zoneCount: _zones.length,
            routeCount: _routes.length,
            onSelect: _selectMode,
          ),
          const SizedBox(height: 16),
          _RouteZoneStats(zones: filteredZones, routes: filteredRoutes),
          const SizedBox(height: 16),
          _RouteZoneToolbar(
            mode: _mode,
            query: _query,
            statusFilter: _statusFilter,
            onQueryChanged: (value) => setState(() => _query = value),
            onStatusChanged: (value) =>
                setState(() => _statusFilter = value ?? 'ALL'),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180 && !widget.compact;
              if (!wide) {
                return Column(
                  children: [
                    _NetworkPanel(
                      selectedRoute: selectedRoute,
                      routes: filteredRoutes,
                    ),
                    const SizedBox(height: 16),
                    _RouteZoneDirectoryPanel(
                      mode: _mode,
                      zones: filteredZones,
                      routes: filteredRoutes,
                      selectedZoneId: _selectedZoneId,
                      selectedRouteId: _selectedRouteId,
                      onSelectZone: _selectZone,
                      onSelectRoute: _selectRoute,
                    ),
                    const SizedBox(height: 16),
                    _RouteZoneEditorPanel(
                      mode: _mode,
                      selectedZone: selectedZone,
                      selectedRoute: selectedRoute,
                      zoneCodeController: _zoneCodeController,
                      zoneNameController: _zoneNameController,
                      parentZoneController: _parentZoneController,
                      regionManagerController: _regionManagerController,
                      hubController: _hubController,
                      cutoffController: _cutoffController,
                      zoneMemoController: _zoneMemoController,
                      routeCodeController: _routeCodeController,
                      routeNameController: _routeNameController,
                      originController: _originController,
                      destinationController: _destinationController,
                      routeZoneController: _routeZoneController,
                      serviceLevelController: _serviceLevelController,
                      distanceController: _distanceController,
                      leadTimeController: _leadTimeController,
                      baseFareController: _baseFareController,
                      vehicleLimitController: _vehicleLimitController,
                      routeMemoController: _routeMemoController,
                      zoneActive: _zoneActive,
                      routeActive: _routeActive,
                      appointmentRequired: _appointmentRequired,
                      tollIncluded: _tollIncluded,
                      temperatureControl: _temperatureControl,
                      onZoneActiveChanged: (value) =>
                          setState(() => _zoneActive = value),
                      onRouteActiveChanged: (value) =>
                          setState(() => _routeActive = value),
                      onAppointmentChanged: (value) =>
                          setState(() => _appointmentRequired = value),
                      onTollChanged: (value) =>
                          setState(() => _tollIncluded = value),
                      onTemperatureChanged: (value) =>
                          setState(() => _temperatureControl = value),
                      onSaveZone: _saveZone,
                      onSaveRoute: _saveRoute,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 13,
                    child: Column(
                      children: [
                        _NetworkPanel(
                          selectedRoute: selectedRoute,
                          routes: filteredRoutes,
                        ),
                        const SizedBox(height: 16),
                        _RouteZoneDirectoryPanel(
                          mode: _mode,
                          zones: filteredZones,
                          routes: filteredRoutes,
                          selectedZoneId: _selectedZoneId,
                          selectedRouteId: _selectedRouteId,
                          onSelectZone: _selectZone,
                          onSelectRoute: _selectRoute,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: _RouteZoneEditorPanel(
                      mode: _mode,
                      selectedZone: selectedZone,
                      selectedRoute: selectedRoute,
                      zoneCodeController: _zoneCodeController,
                      zoneNameController: _zoneNameController,
                      parentZoneController: _parentZoneController,
                      regionManagerController: _regionManagerController,
                      hubController: _hubController,
                      cutoffController: _cutoffController,
                      zoneMemoController: _zoneMemoController,
                      routeCodeController: _routeCodeController,
                      routeNameController: _routeNameController,
                      originController: _originController,
                      destinationController: _destinationController,
                      routeZoneController: _routeZoneController,
                      serviceLevelController: _serviceLevelController,
                      distanceController: _distanceController,
                      leadTimeController: _leadTimeController,
                      baseFareController: _baseFareController,
                      vehicleLimitController: _vehicleLimitController,
                      routeMemoController: _routeMemoController,
                      zoneActive: _zoneActive,
                      routeActive: _routeActive,
                      appointmentRequired: _appointmentRequired,
                      tollIncluded: _tollIncluded,
                      temperatureControl: _temperatureControl,
                      onZoneActiveChanged: (value) =>
                          setState(() => _zoneActive = value),
                      onRouteActiveChanged: (value) =>
                          setState(() => _routeActive = value),
                      onAppointmentChanged: (value) =>
                          setState(() => _appointmentRequired = value),
                      onTollChanged: (value) =>
                          setState(() => _tollIncluded = value),
                      onTemperatureChanged: (value) =>
                          setState(() => _temperatureControl = value),
                      onSaveZone: _saveZone,
                      onSaveRoute: _saveRoute,
                    ),
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

class _RouteZoneHeader extends StatelessWidget {
  const _RouteZoneHeader({
    required this.mode,
    required this.totalCount,
    required this.activeCount,
    required this.onCreate,
  });

  final _RouteMasterMode mode;
  final int totalCount;
  final int activeCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final titleBlock = Row(
            children: [
              _IconBox(icon: mode.icon, color: mode.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '권역/노선 마스터',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.graphite,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '권역, 허브, 대표 노선, 리드타임과 운송 조건 기준정보',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

          final actions = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InlineMetric(label: '조회', value: '$totalCount'),
              _InlineMetric(label: '활성', value: '$activeCount'),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text('${mode.label} 등록'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(134, 42),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.selectedMode,
    required this.zoneCount,
    required this.routeCount,
    required this.onSelect,
  });

  final _RouteMasterMode selectedMode;
  final int zoneCount;
  final int routeCount;
  final ValueChanged<_RouteMasterMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = {
      _RouteMasterMode.zone: zoneCount,
      _RouteMasterMode.route: routeCount,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: _RouteMasterMode.values.map((mode) {
            final selected = selectedMode == mode;
            return SizedBox(
              width: tileWidth,
              child: Material(
                color: selected
                    ? mode.color.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelect(mode),
                  child: Container(
                    height: 76,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? mode.color : AppTheme.line,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _IconBox(icon: mode.icon, color: mode.color, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                mode.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: AppTheme.graphite,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                mode.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        _CountBadge(
                          value: '${counts[mode] ?? 0}',
                          color: selected ? mode.color : AppTheme.slate,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _RouteZoneStats extends StatelessWidget {
  const _RouteZoneStats({required this.zones, required this.routes});

  final List<_ZoneRecord> zones;
  final List<_RouteRecord> routes;

  @override
  Widget build(BuildContext context) {
    final activeRoutes = routes.where((route) => route.isActive).length;
    final orders = routes.fold<int>(
      0,
      (sum, route) => sum + route.todayOrderCount,
    );
    final avgLeadTime = routes.isEmpty
        ? 0
        : (routes.fold<int>(0, (sum, route) => sum + route.leadTimeHours) /
                  routes.length)
              .round();
    final restricted = routes
        .where(
          (route) =>
              route.appointmentRequired ||
              route.temperatureControl ||
              !route.tollIncluded,
        )
        .length;

    final metrics = [
      _Metric(
        label: '활성 권역',
        value: '${zones.where((zone) => zone.isActive).length}',
        icon: Icons.map_rounded,
        color: AppTheme.teal,
      ),
      _Metric(
        label: '활성 노선',
        value: '$activeRoutes',
        icon: Icons.alt_route_rounded,
        color: AppTheme.cyan,
      ),
      _Metric(
        label: '오늘 오더',
        value: '$orders',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF2563EB),
      ),
      _Metric(
        label: '평균 리드타임',
        value: '${avgLeadTime}h',
        icon: Icons.schedule_rounded,
        color: AppTheme.amber,
      ),
      _Metric(
        label: '제약 노선',
        value: '$restricted',
        icon: Icons.rule_rounded,
        color: const Color(0xFF7C3AED),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(width: width, child: _MetricTile(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _RouteZoneToolbar extends StatelessWidget {
  const _RouteZoneToolbar({
    required this.mode,
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final _RouteMasterMode mode;
  final String query;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: '${mode.label} 검색',
              hintText: mode == _RouteMasterMode.zone
                  ? '권역 코드, 권역명, 허브, 담당팀'
                  : '노선 코드, 노선명, 출발지, 도착지, 권역',
            ),
          );

          final filter = DropdownButtonFormField<String>(
            initialValue: statusFilter,
            onChanged: onStatusChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.filter_list_rounded),
              labelText: '상태',
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('전체')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('활성')),
              DropdownMenuItem(value: 'INACTIVE', child: Text('비활성')),
            ],
          );

          if (compact) {
            return Column(
              children: [search, const SizedBox(height: 10), filter],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: search),
              const SizedBox(width: 12),
              SizedBox(width: 210, child: filter),
              const SizedBox(width: 12),
              _ToolbarButton(icon: Icons.download_rounded, label: '내보내기'),
              const SizedBox(width: 8),
              _ToolbarButton(icon: Icons.upload_file_rounded, label: '업로드'),
            ],
          );
        },
      ),
    );
  }
}

class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel({required this.routes, required this.selectedRoute});

  final List<_RouteRecord> routes;
  final _RouteRecord? selectedRoute;

  @override
  Widget build(BuildContext context) {
    final route = selectedRoute ?? (routes.isNotEmpty ? routes.first : null);
    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.route_rounded,
            title: '노선 네트워크',
            subtitle: '권역별 출발지-도착지 운영 흐름',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 158,
            width: double.infinity,
            child: CustomPaint(
              painter: _RouteNetworkPainter(
                color: route?.color ?? AppTheme.cyan,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    _NetworkNode(
                      label: '출발',
                      value: route?.originName ?? '미선택',
                      color: AppTheme.teal,
                    ),
                    const Spacer(),
                    _NetworkNode(
                      label: '도착',
                      value: route?.destinationName ?? '미선택',
                      color: AppTheme.amber,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyInfo(
                icon: Icons.confirmation_number_rounded,
                label: route?.routeCode ?? '노선 코드',
              ),
              _TinyInfo(
                icon: Icons.map_rounded,
                label: route?.zoneName ?? '권역',
              ),
              _TinyInfo(
                icon: Icons.speed_rounded,
                label: route == null
                    ? '거리'
                    : '${route.distanceKm}km / ${route.leadTimeHours}h',
              ),
              _TinyInfo(
                icon: Icons.verified_rounded,
                label: route == null ? '정시율' : '${route.onTimeRate}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteZoneDirectoryPanel extends StatelessWidget {
  const _RouteZoneDirectoryPanel({
    required this.mode,
    required this.zones,
    required this.routes,
    required this.selectedZoneId,
    required this.selectedRouteId,
    required this.onSelectZone,
    required this.onSelectRoute,
    this.dense = false,
  });

  final _RouteMasterMode mode;
  final List<_ZoneRecord> zones;
  final List<_RouteRecord> routes;
  final int? selectedZoneId;
  final int? selectedRouteId;
  final ValueChanged<_ZoneRecord> onSelectZone;
  final ValueChanged<_RouteRecord> onSelectRoute;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final empty = mode == _RouteMasterMode.zone
        ? zones.isEmpty
        : routes.isEmpty;
    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: mode.icon,
            title: '${mode.label} 목록',
            subtitle: mode == _RouteMasterMode.zone
                ? 'transport_zones'
                : 'transport_routes',
          ),
          const SizedBox(height: 14),
          if (empty)
            const _EmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 860 || !dense) {
                  return Column(
                    children: mode == _RouteMasterMode.zone
                        ? zones
                              .map(
                                (zone) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ZoneListTile(
                                    zone: zone,
                                    selected: selectedZoneId == zone.id,
                                    onTap: () => onSelectZone(zone),
                                  ),
                                ),
                              )
                              .toList()
                        : routes
                              .map(
                                (route) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RouteListTile(
                                    route: route,
                                    selected: selectedRouteId == route.id,
                                    onTap: () => onSelectRoute(route),
                                  ),
                                ),
                              )
                              .toList(),
                  );
                }

                if (mode == _RouteMasterMode.zone) {
                  return _ZoneTable(
                    zones: zones,
                    selectedId: selectedZoneId,
                    onSelect: onSelectZone,
                  );
                }
                return _RouteTable(
                  routes: routes,
                  selectedId: selectedRouteId,
                  onSelect: onSelectRoute,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ZoneTable extends StatelessWidget {
  const _ZoneTable({
    required this.zones,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_ZoneRecord> zones;
  final int? selectedId;
  final ValueChanged<_ZoneRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 58,
          dataRowMaxHeight: 64,
          columnSpacing: 28,
          horizontalMargin: 14,
          columns: const [
            DataColumn(label: Text('권역 코드')),
            DataColumn(label: Text('권역명')),
            DataColumn(label: Text('상위 권역')),
            DataColumn(label: Text('허브')),
            DataColumn(label: Text('노선')),
            DataColumn(label: Text('상태')),
          ],
          rows: zones.map((zone) {
            return DataRow(
              selected: selectedId == zone.id,
              onSelectChanged: (_) => onSelect(zone),
              cells: [
                DataCell(_StrongText(zone.zoneCode)),
                DataCell(_BoundedText(zone.zoneName, width: 160)),
                DataCell(Text(zone.parentZone)),
                DataCell(_BoundedText(zone.hubName, width: 150)),
                DataCell(Text('${zone.activeRouteCount}개')),
                DataCell(_StatusPill(active: zone.isActive)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RouteTable extends StatelessWidget {
  const _RouteTable({
    required this.routes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_RouteRecord> routes;
  final int? selectedId;
  final ValueChanged<_RouteRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 58,
          dataRowMaxHeight: 64,
          columnSpacing: 28,
          horizontalMargin: 14,
          columns: const [
            DataColumn(label: Text('노선 코드')),
            DataColumn(label: Text('노선명')),
            DataColumn(label: Text('권역')),
            DataColumn(label: Text('출발지')),
            DataColumn(label: Text('도착지')),
            DataColumn(label: Text('거리/시간')),
            DataColumn(label: Text('상태')),
          ],
          rows: routes.map((route) {
            return DataRow(
              selected: selectedId == route.id,
              onSelectChanged: (_) => onSelect(route),
              cells: [
                DataCell(_StrongText(route.routeCode)),
                DataCell(_BoundedText(route.routeName, width: 190)),
                DataCell(Text(route.zoneName)),
                DataCell(_BoundedText(route.originName, width: 150)),
                DataCell(_BoundedText(route.destinationName, width: 150)),
                DataCell(
                  Text('${route.distanceKm}km / ${route.leadTimeHours}h'),
                ),
                DataCell(_StatusPill(active: route.isActive)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ZoneListTile extends StatelessWidget {
  const _ZoneListTile({
    required this.zone,
    required this.selected,
    required this.onTap,
  });

  final _ZoneRecord zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RecordTile(
      selected: selected,
      color: AppTheme.teal,
      onTap: onTap,
      icon: Icons.map_rounded,
      title: zone.zoneName,
      subtitle: '${zone.zoneCode} · ${zone.parentZone}',
      active: zone.isActive,
      details: [
        _TinyInfo(icon: Icons.hub_rounded, label: zone.hubName),
        _TinyInfo(
          icon: Icons.alt_route_rounded,
          label: '${zone.activeRouteCount}개 노선',
        ),
        _TinyInfo(
          icon: Icons.inventory_rounded,
          label: '${zone.destinationCount}개 배송처',
        ),
      ],
    );
  }
}

class _RouteListTile extends StatelessWidget {
  const _RouteListTile({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final _RouteRecord route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RecordTile(
      selected: selected,
      color: route.color,
      onTap: onTap,
      icon: Icons.alt_route_rounded,
      title: route.routeName,
      subtitle:
          '${route.routeCode} · ${route.originName} → ${route.destinationName}',
      active: route.isActive,
      details: [
        _TinyInfo(icon: Icons.map_rounded, label: route.zoneName),
        _TinyInfo(icon: Icons.speed_rounded, label: '${route.distanceKm}km'),
        _TinyInfo(
          icon: Icons.schedule_rounded,
          label: '${route.leadTimeHours}h',
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.details,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBox(icon: icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.graphite,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  _StatusPill(active: active),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: details),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteZoneEditorPanel extends StatelessWidget {
  const _RouteZoneEditorPanel({
    required this.mode,
    required this.selectedZone,
    required this.selectedRoute,
    required this.zoneCodeController,
    required this.zoneNameController,
    required this.parentZoneController,
    required this.regionManagerController,
    required this.hubController,
    required this.cutoffController,
    required this.zoneMemoController,
    required this.routeCodeController,
    required this.routeNameController,
    required this.originController,
    required this.destinationController,
    required this.routeZoneController,
    required this.serviceLevelController,
    required this.distanceController,
    required this.leadTimeController,
    required this.baseFareController,
    required this.vehicleLimitController,
    required this.routeMemoController,
    required this.zoneActive,
    required this.routeActive,
    required this.appointmentRequired,
    required this.tollIncluded,
    required this.temperatureControl,
    required this.onZoneActiveChanged,
    required this.onRouteActiveChanged,
    required this.onAppointmentChanged,
    required this.onTollChanged,
    required this.onTemperatureChanged,
    required this.onSaveZone,
    required this.onSaveRoute,
  });

  final _RouteMasterMode mode;
  final _ZoneRecord? selectedZone;
  final _RouteRecord? selectedRoute;
  final TextEditingController zoneCodeController;
  final TextEditingController zoneNameController;
  final TextEditingController parentZoneController;
  final TextEditingController regionManagerController;
  final TextEditingController hubController;
  final TextEditingController cutoffController;
  final TextEditingController zoneMemoController;
  final TextEditingController routeCodeController;
  final TextEditingController routeNameController;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final TextEditingController routeZoneController;
  final TextEditingController serviceLevelController;
  final TextEditingController distanceController;
  final TextEditingController leadTimeController;
  final TextEditingController baseFareController;
  final TextEditingController vehicleLimitController;
  final TextEditingController routeMemoController;
  final bool zoneActive;
  final bool routeActive;
  final bool appointmentRequired;
  final bool tollIncluded;
  final bool temperatureControl;
  final ValueChanged<bool> onZoneActiveChanged;
  final ValueChanged<bool> onRouteActiveChanged;
  final ValueChanged<bool> onAppointmentChanged;
  final ValueChanged<bool> onTollChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final VoidCallback onSaveZone;
  final VoidCallback onSaveRoute;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: mode.icon,
            title: '${mode.label} 상세',
            subtitle: mode == _RouteMasterMode.zone
                ? selectedZone?.zoneCode ?? 'transport_zones'
                : selectedRoute?.routeCode ?? 'transport_routes',
          ),
          const SizedBox(height: 16),
          if (mode == _RouteMasterMode.zone)
            _ZoneEditorFields(
              selectedZone: selectedZone,
              codeController: zoneCodeController,
              nameController: zoneNameController,
              parentZoneController: parentZoneController,
              regionManagerController: regionManagerController,
              hubController: hubController,
              cutoffController: cutoffController,
              memoController: zoneMemoController,
              active: zoneActive,
              onActiveChanged: onZoneActiveChanged,
              onSave: onSaveZone,
            )
          else
            _RouteEditorFields(
              selectedRoute: selectedRoute,
              codeController: routeCodeController,
              nameController: routeNameController,
              originController: originController,
              destinationController: destinationController,
              zoneController: routeZoneController,
              serviceLevelController: serviceLevelController,
              distanceController: distanceController,
              leadTimeController: leadTimeController,
              baseFareController: baseFareController,
              vehicleLimitController: vehicleLimitController,
              memoController: routeMemoController,
              active: routeActive,
              appointmentRequired: appointmentRequired,
              tollIncluded: tollIncluded,
              temperatureControl: temperatureControl,
              onActiveChanged: onRouteActiveChanged,
              onAppointmentChanged: onAppointmentChanged,
              onTollChanged: onTollChanged,
              onTemperatureChanged: onTemperatureChanged,
              onSave: onSaveRoute,
            ),
        ],
      ),
    );
  }
}

class _ZoneEditorFields extends StatelessWidget {
  const _ZoneEditorFields({
    required this.selectedZone,
    required this.codeController,
    required this.nameController,
    required this.parentZoneController,
    required this.regionManagerController,
    required this.hubController,
    required this.cutoffController,
    required this.memoController,
    required this.active,
    required this.onActiveChanged,
    required this.onSave,
  });

  final _ZoneRecord? selectedZone;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController parentZoneController;
  final TextEditingController regionManagerController;
  final TextEditingController hubController;
  final TextEditingController cutoffController;
  final TextEditingController memoController;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditorSummary(
          color: AppTheme.teal,
          items: [
            _TinyInfo(
              icon: Icons.store_mall_directory_rounded,
              label: '${selectedZone?.destinationCount ?? 0}개 배송처',
            ),
            _TinyInfo(
              icon: Icons.alt_route_rounded,
              label: '${selectedZone?.activeRouteCount ?? 0}개 노선',
            ),
            _TinyInfo(
              icon: Icons.local_shipping_rounded,
              label: '${selectedZone?.todayOrderCount ?? 0}건 오늘',
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 620;
            final fieldWidth = twoColumn
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: codeController,
                    label: '권역 코드',
                    icon: Icons.tag_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: nameController,
                    label: '권역명',
                    icon: Icons.map_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: parentZoneController,
                    label: '상위 권역',
                    icon: Icons.account_tree_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: regionManagerController,
                    label: '담당 조직',
                    icon: Icons.groups_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: hubController,
                    label: '대표 허브',
                    icon: Icons.hub_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: cutoffController,
                    label: '마감 시간',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _TextInput(
                    controller: memoController,
                    label: '관리 메모',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _SwitchRow(
          title: '신규 오더 사용',
          subtitle: active ? 'is_active = true' : 'is_active = false',
          value: active,
          onChanged: onActiveChanged,
        ),
        const SizedBox(height: 14),
        _EditorActions(onSave: onSave),
      ],
    );
  }
}

class _RouteEditorFields extends StatelessWidget {
  const _RouteEditorFields({
    required this.selectedRoute,
    required this.codeController,
    required this.nameController,
    required this.originController,
    required this.destinationController,
    required this.zoneController,
    required this.serviceLevelController,
    required this.distanceController,
    required this.leadTimeController,
    required this.baseFareController,
    required this.vehicleLimitController,
    required this.memoController,
    required this.active,
    required this.appointmentRequired,
    required this.tollIncluded,
    required this.temperatureControl,
    required this.onActiveChanged,
    required this.onAppointmentChanged,
    required this.onTollChanged,
    required this.onTemperatureChanged,
    required this.onSave,
  });

  final _RouteRecord? selectedRoute;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final TextEditingController zoneController;
  final TextEditingController serviceLevelController;
  final TextEditingController distanceController;
  final TextEditingController leadTimeController;
  final TextEditingController baseFareController;
  final TextEditingController vehicleLimitController;
  final TextEditingController memoController;
  final bool active;
  final bool appointmentRequired;
  final bool tollIncluded;
  final bool temperatureControl;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onAppointmentChanged;
  final ValueChanged<bool> onTollChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditorSummary(
          color: selectedRoute?.color ?? AppTheme.cyan,
          items: [
            _TinyInfo(
              icon: Icons.speed_rounded,
              label: '${selectedRoute?.distanceKm ?? 0}km',
            ),
            _TinyInfo(
              icon: Icons.schedule_rounded,
              label: '${selectedRoute?.leadTimeHours ?? 0}h',
            ),
            _TinyInfo(
              icon: Icons.verified_rounded,
              label: '${selectedRoute?.onTimeRate ?? 0}%',
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 620;
            final fieldWidth = twoColumn
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: codeController,
                    label: '노선 코드',
                    icon: Icons.tag_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: nameController,
                    label: '노선명',
                    icon: Icons.alt_route_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: originController,
                    label: '출발 거점',
                    icon: Icons.trip_origin_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: destinationController,
                    label: '도착 거점',
                    icon: Icons.location_on_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: zoneController,
                    label: '권역',
                    icon: Icons.map_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: serviceLevelController,
                    label: '서비스 레벨',
                    icon: Icons.workspace_premium_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: distanceController,
                    label: '거리 km',
                    icon: Icons.speed_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: leadTimeController,
                    label: '리드타임 h',
                    icon: Icons.schedule_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: baseFareController,
                    label: '기준 운임',
                    icon: Icons.payments_rounded,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _TextInput(
                    controller: vehicleLimitController,
                    label: '차량 제한',
                    icon: Icons.local_shipping_rounded,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _TextInput(
                    controller: memoController,
                    label: '운영 메모',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _SwitchRow(
          title: '신규 배차 사용',
          subtitle: active ? 'is_active = true' : 'is_active = false',
          value: active,
          onChanged: onActiveChanged,
        ),
        const SizedBox(height: 10),
        _SwitchRow(
          title: '예약 필수',
          subtitle: '상차/하차 시간창 관리',
          value: appointmentRequired,
          onChanged: onAppointmentChanged,
        ),
        const SizedBox(height: 10),
        _SwitchRow(
          title: '통행료 포함',
          subtitle: '정산 기준 운임에 포함',
          value: tollIncluded,
          onChanged: onTollChanged,
        ),
        const SizedBox(height: 10),
        _SwitchRow(
          title: '온도 관리',
          subtitle: '냉장/냉동 품목 운송 가능',
          value: temperatureControl,
          onChanged: onTemperatureChanged,
        ),
        const SizedBox(height: 14),
        _EditorActions(onSave: onSave),
      ],
    );
  }
}

class _RouteNetworkPainter extends CustomPainter {
  const _RouteNetworkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.teal.withValues(alpha: 0.10),
          AppTheme.cyan.withValues(alpha: 0.08),
        ],
      ).createShader(Offset.zero & size);
    final border = Paint()
      ..color = AppTheme.line
      ..style = PaintingStyle.stroke;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..strokeWidth = 1;
    final routePaint = Paint()
      ..color = color
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shadowPaint = Paint()
      ..color = AppTheme.graphite.withValues(alpha: 0.10)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final radius = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(radius, background);
    canvas.drawRRect(radius, border);

    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 12), Offset(x - 40, size.height - 12), grid);
    }
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y - 24), grid);
    }

    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.70)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.18,
        size.width * 0.56,
        size.height * 0.88,
        size.width * 0.86,
        size.height * 0.30,
      );
    canvas.drawPath(path.shift(const Offset(8, 10)), shadowPaint);
    canvas.drawPath(path, routePaint);

    final nodePaint = Paint()..color = Colors.white;
    final innerPaint = Paint()..color = AppTheme.graphite;
    for (final point in [
      Offset(size.width * 0.14, size.height * 0.70),
      Offset(size.width * 0.50, size.height * 0.51),
      Offset(size.width * 0.86, size.height * 0.30),
    ]) {
      canvas.drawCircle(point, 13, nodePaint);
      canvas.drawCircle(point, 7, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteNetworkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NetworkNode extends StatelessWidget {
  const _NetworkNode({
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
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
        _IconBox(icon: icon, color: AppTheme.graphite),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.metric);

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IconBox(icon: metric.icon, color: metric.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
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

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.teal : AppTheme.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? '활성' : '비활성',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TinyInfo extends StatelessWidget {
  const _TinyInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.slate),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size(112, 52)),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: KtmsNumericInputFormatters.forKeyboardType(
        keyboardType,
        label: label,
      ),
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}

class _StrongText extends StatelessWidget {
  const _StrongText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.graphite,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _BoundedText extends StatelessWidget {
  const _BoundedText(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _EditorSummary extends StatelessWidget {
  const _EditorSummary({required this.color, required this.items});

  final Color color;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: items),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('변경이력'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('저장'),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Text(
        '조회된 기준정보가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _RouteMasterMode {
  zone,
  route;

  String get label => switch (this) {
    _RouteMasterMode.zone => '권역',
    _RouteMasterMode.route => '노선',
  };

  String get description => switch (this) {
    _RouteMasterMode.zone => '운영 구역, 허브, 마감 기준',
    _RouteMasterMode.route => '출발지-도착지 운송 경로',
  };

  IconData get icon => switch (this) {
    _RouteMasterMode.zone => Icons.map_rounded,
    _RouteMasterMode.route => Icons.alt_route_rounded,
  };

  Color get color => switch (this) {
    _RouteMasterMode.zone => AppTheme.teal,
    _RouteMasterMode.route => AppTheme.cyan,
  };
}

class _ZoneRecord {
  const _ZoneRecord({
    required this.id,
    required this.zoneCode,
    required this.zoneName,
    required this.parentZone,
    required this.regionManager,
    required this.hubName,
    required this.cutoffTime,
    required this.destinationCount,
    required this.activeRouteCount,
    required this.todayOrderCount,
    required this.statusCode,
    required this.isActive,
    required this.memo,
  });

  final int id;
  final String zoneCode;
  final String zoneName;
  final String parentZone;
  final String regionManager;
  final String hubName;
  final String cutoffTime;
  final int destinationCount;
  final int activeRouteCount;
  final int todayOrderCount;
  final String statusCode;
  final bool isActive;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'zone_code': zoneCode,
      'zone_name': zoneName,
      'zone_type': 'REGION',
      'description': memo,
      'is_active': isActive,
      'metadata': {
        'parent_zone': parentZone,
        'region_manager': regionManager,
        'hub_name': hubName,
        'cutoff_time': cutoffTime,
        'destination_count': destinationCount,
        'active_route_count': activeRouteCount,
        'today_order_count': todayOrderCount,
        'status': statusCode,
      },
    };
  }
}

class _RouteRecord {
  const _RouteRecord({
    required this.id,
    required this.routeCode,
    required this.routeName,
    required this.originName,
    required this.destinationName,
    required this.zoneName,
    required this.serviceLevel,
    required this.distanceKm,
    required this.leadTimeHours,
    required this.baseFare,
    required this.vehicleLimit,
    required this.todayOrderCount,
    required this.onTimeRate,
    required this.statusCode,
    required this.isActive,
    required this.appointmentRequired,
    required this.tollIncluded,
    required this.temperatureControl,
    required this.memo,
  });

  final int id;
  final String routeCode;
  final String routeName;
  final String originName;
  final String destinationName;
  final String zoneName;
  final String serviceLevel;
  final int distanceKm;
  final int leadTimeHours;
  final String baseFare;
  final String vehicleLimit;
  final int todayOrderCount;
  final double onTimeRate;
  final String statusCode;
  final bool isActive;
  final bool appointmentRequired;
  final bool tollIncluded;
  final bool temperatureControl;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'route_code': routeCode,
      'route_name': routeName,
      'origin_name': originName,
      'destination_name': destinationName,
      'zone_name': zoneName,
      'service_level': serviceLevel,
      'distance_km': distanceKm,
      'lead_time_hours': leadTimeHours,
      'base_fare': baseFare.replaceAll(',', '').replaceAll('원', '').trim(),
      'vehicle_limit': vehicleLimit,
      'appointment_required': appointmentRequired,
      'toll_included': tollIncluded,
      'temperature_controlled': temperatureControl,
      'status': statusCode,
      'is_active': isActive,
      'metadata': {
        'today_order_count': todayOrderCount,
        'on_time_rate': onTimeRate,
        'memo': memo,
      },
    };
  }

  Color get color {
    if (temperatureControl) {
      return const Color(0xFF2563EB);
    }
    if (appointmentRequired) {
      return AppTheme.amber;
    }
    return AppTheme.cyan;
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

const _seedZones = [
  _ZoneRecord(
    id: 1,
    zoneCode: 'ZONE001',
    zoneName: '수도권',
    parentZone: '전국',
    regionManager: '수도권운영팀',
    hubName: '용인 RDC',
    cutoffTime: '17:00',
    destinationCount: 68,
    activeRouteCount: 14,
    todayOrderCount: 142,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '서울, 경기, 인천 일 배송권역. 혼잡 시간대 리드타임 보정 필요.',
  ),
  _ZoneRecord(
    id: 2,
    zoneCode: 'ZONE002',
    zoneName: '충청권',
    parentZone: '전국',
    regionManager: '중부운영팀',
    hubName: '대전 허브',
    cutoffTime: '16:30',
    destinationCount: 34,
    activeRouteCount: 8,
    todayOrderCount: 54,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '수도권-영남권 중간 경유지로 환적 물량 포함 관리.',
  ),
  _ZoneRecord(
    id: 3,
    zoneCode: 'ZONE003',
    zoneName: '영남권',
    parentZone: '전국',
    regionManager: '영남운영팀',
    hubName: '양산 CDC',
    cutoffTime: '15:30',
    destinationCount: 46,
    activeRouteCount: 10,
    todayOrderCount: 88,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '부산항, 울산 공장, 대구권 매장 직납 노선 포함.',
  ),
  _ZoneRecord(
    id: 4,
    zoneCode: 'ZONE004',
    zoneName: '호남권',
    parentZone: '전국',
    regionManager: '서남운영팀',
    hubName: '광주 물류센터',
    cutoffTime: '15:00',
    destinationCount: 27,
    activeRouteCount: 6,
    todayOrderCount: 31,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '농산물 및 냉장 품목 비중이 높아 온도 관리 노선 우선 배정.',
  ),
  _ZoneRecord(
    id: 5,
    zoneCode: 'ZONE005',
    zoneName: '강원권',
    parentZone: '전국',
    regionManager: '동부운영팀',
    hubName: '원주 TC',
    cutoffTime: '14:30',
    destinationCount: 19,
    activeRouteCount: 4,
    todayOrderCount: 18,
    statusCode: 'INACTIVE',
    isActive: false,
    memo: '동절기 산간 운송 조건 재정비 후 활성화 예정.',
  ),
];

const _seedRoutes = [
  _RouteRecord(
    id: 1,
    routeCode: 'RTE0001',
    routeName: '용인 RDC → 강남권 순환',
    originName: '용인 RDC',
    destinationName: '강남권 매장군',
    zoneName: '수도권',
    serviceLevel: '당일',
    distanceKm: 58,
    leadTimeHours: 4,
    baseFare: '180,000',
    vehicleLimit: '5톤 이하',
    todayOrderCount: 24,
    onTimeRate: 98.6,
    statusCode: 'ACTIVE',
    isActive: true,
    appointmentRequired: true,
    tollIncluded: true,
    temperatureControl: false,
    memo: '오전 피크 시간대 강남 진입 혼잡. 07:00 이전 출발 권장.',
  ),
  _RouteRecord(
    id: 2,
    routeCode: 'RTE0002',
    routeName: '평택 공장 → 용인 RDC',
    originName: '평택 공장',
    destinationName: '용인 RDC',
    zoneName: '수도권',
    serviceLevel: '당일',
    distanceKm: 72,
    leadTimeHours: 5,
    baseFare: '220,000',
    vehicleLimit: '11톤 이하',
    todayOrderCount: 18,
    onTimeRate: 97.8,
    statusCode: 'ACTIVE',
    isActive: true,
    appointmentRequired: false,
    tollIncluded: true,
    temperatureControl: false,
    memo: '상차지 야드 혼잡 시 대기비 발생 가능.',
  ),
  _RouteRecord(
    id: 3,
    routeCode: 'RTE0003',
    routeName: '용인 RDC → 부산 동부',
    originName: '용인 RDC',
    destinationName: '부산 동부권',
    zoneName: '영남권',
    serviceLevel: '익일',
    distanceKm: 392,
    leadTimeHours: 18,
    baseFare: '680,000',
    vehicleLimit: '25톤 이하',
    todayOrderCount: 11,
    onTimeRate: 96.9,
    statusCode: 'ACTIVE',
    isActive: true,
    appointmentRequired: true,
    tollIncluded: false,
    temperatureControl: false,
    memo: '야간 간선 후 오전 배송. 통행료 실비 정산.',
  ),
  _RouteRecord(
    id: 4,
    routeCode: 'RTE0004',
    routeName: '광주 물류센터 → 전주 냉장',
    originName: '광주 물류센터',
    destinationName: '전주 냉장센터',
    zoneName: '호남권',
    serviceLevel: '당일',
    distanceKm: 96,
    leadTimeHours: 6,
    baseFare: '260,000',
    vehicleLimit: '냉장 5톤',
    todayOrderCount: 7,
    onTimeRate: 99.1,
    statusCode: 'ACTIVE',
    isActive: true,
    appointmentRequired: true,
    tollIncluded: true,
    temperatureControl: true,
    memo: '냉장 온도 이탈 알림 필수. 도착 전 30분 사전 연락.',
  ),
  _RouteRecord(
    id: 5,
    routeCode: 'RTE0005',
    routeName: '대전 허브 → 청주 산업단지',
    originName: '대전 허브',
    destinationName: '청주 산업단지',
    zoneName: '충청권',
    serviceLevel: '당일',
    distanceKm: 48,
    leadTimeHours: 3,
    baseFare: '150,000',
    vehicleLimit: '3.5톤 이하',
    todayOrderCount: 15,
    onTimeRate: 98.2,
    statusCode: 'ACTIVE',
    isActive: true,
    appointmentRequired: false,
    tollIncluded: true,
    temperatureControl: false,
    memo: '정기 셔틀 성격. 왕복 회차 관리 필요.',
  ),
  _RouteRecord(
    id: 6,
    routeCode: 'RTE0006',
    routeName: '원주 TC → 강릉권',
    originName: '원주 TC',
    destinationName: '강릉권',
    zoneName: '강원권',
    serviceLevel: '익일',
    distanceKm: 128,
    leadTimeHours: 10,
    baseFare: '320,000',
    vehicleLimit: '5톤 이하',
    todayOrderCount: 0,
    onTimeRate: 94.5,
    statusCode: 'INACTIVE',
    isActive: false,
    appointmentRequired: false,
    tollIncluded: true,
    temperatureControl: false,
    memo: '동절기 대체 노선 검토 중.',
  ),
];
