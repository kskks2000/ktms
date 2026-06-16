import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'master_api.dart';
import 'naver_route_map_view.dart';

class ExecutionTrackingPage extends StatefulWidget {
  const ExecutionTrackingPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<ExecutionTrackingPage> createState() => _ExecutionTrackingPageState();
}

class _ExecutionTrackingPageState extends State<ExecutionTrackingPage> {
  late final List<_ExecutionTrip> _trips = List<_ExecutionTrip>.from(
    _seedExecutionTrips,
  );
  int _selectedTripId = 1;
  String _statusFilter = 'ALL';

  _ExecutionTrip get _selectedTrip {
    return _trips.firstWhere(
      (trip) => trip.id == _selectedTripId,
      orElse: () => _trips.first,
    );
  }

  List<_ExecutionTrip> get _filteredTrips {
    return _trips.where((trip) {
      return switch (_statusFilter) {
        'DELAY' => trip.delayRiskCode != 'GOOD',
        'COLD' => trip.temperatureControlled,
        'ARRIVING' => trip.statusCode == 'ARRIVING',
        'ALL' || _ => true,
      };
    }).toList();
  }

  int get _activeCount {
    return _trips.where((trip) => trip.statusCode != 'COMPLETED').length;
  }

  int get _delayRiskCount {
    return _trips.where((trip) => trip.delayRiskCode != 'GOOD').length;
  }

  int get _coldChainCount {
    return _trips.where((trip) => trip.temperatureControlled).length;
  }

  double get _averageProgress {
    if (_trips.isEmpty) {
      return 0;
    }
    return _trips.fold<double>(0, (sum, trip) => sum + trip.progress) /
        _trips.length;
  }

  void _selectTrip(_ExecutionTrip trip) {
    setState(() => _selectedTripId = trip.id);
  }

  Future<void> _advanceSelectedVehicle() async {
    final trip = _selectedTrip;
    final nextProgress = math.min(1.0, trip.progress + 0.08);
    final nextEta = math.max(0, trip.etaMinutes - 7);
    final nextStatus = nextProgress >= 0.96
        ? 'ARRIVING'
        : trip.statusCode == 'READY'
        ? 'DEPARTED'
        : trip.statusCode;
    setState(() {
      final index = _trips.indexWhere((item) => item.id == trip.id);
      if (index != -1) {
        _trips[index] = trip.copyWith(
          progress: nextProgress,
          etaMinutes: nextEta,
          statusCode: nextStatus,
          lastSignal: '방금 전',
        );
      }
    });

    final position = _positionAlongStops(trip.stops, nextProgress);
    final result = await MasterApi.instance.saveTrackingPosition({
      'vehicle_no': trip.vehicleNo,
      'driver_name': trip.driverName,
      'plan_no': trip.planNo,
      'status_label': _statusLabelForCode(nextStatus),
      'eta_label': _etaLabelForMinutes(nextEta),
      'progress': nextProgress.toStringAsFixed(4),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed_kph': 72,
      'heading_degree': position.headingDegree,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'location_text': '${trip.originName} → ${trip.destinationName}',
      'notes': '${trip.vehicleNo} GPS 갱신',
      'metadata': {
        'execution_trip_id': trip.id,
        'customer_name': trip.customerName,
        'carrier_name': trip.carrierName,
        'cargo_type': trip.cargoType,
        'origin_name': trip.originName,
        'destination_name': trip.destinationName,
      },
    });

    if (!mounted) {
      return;
    }
    if (result.failed) {
      _showMessage('${trip.vehicleNo} 위치는 갱신됐지만 DB 저장에 실패했습니다.');
      return;
    }
    if (result.skipped) {
      _showMessage('${trip.vehicleNo} 위치를 갱신했습니다.');
      return;
    }
    _showMessage('${trip.vehicleNo} 위치를 갱신하고 DB에 저장했습니다.');
  }

  void _completeSelectedTrip() {
    final trip = _selectedTrip;
    setState(() {
      final index = _trips.indexWhere((item) => item.id == trip.id);
      if (index != -1) {
        _trips[index] = trip.copyWith(
          progress: 1,
          etaMinutes: 0,
          statusCode: 'COMPLETED',
          lastSignal: '방금 전',
        );
      }
    });
    _showMessage('${trip.planNo} 운송 실행이 완료 처리되었습니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
          _ExecutionHeader(
            selectedTrip: _selectedTrip,
            onRefreshLocation: _advanceSelectedVehicle,
            onCompleteTrip: _completeSelectedTrip,
          ),
          const SizedBox(height: 16),
          _ExecutionMetricStrip(
            activeCount: _activeCount,
            delayRiskCount: _delayRiskCount,
            coldChainCount: _coldChainCount,
            averageProgress: _averageProgress,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1240 && !widget.compact;
              final mapPanel = _TrackingMapPanel(
                trip: _selectedTrip,
                compact: widget.compact,
              );
              final queuePanel = _TripQueuePanel(
                trips: _filteredTrips,
                selectedTripId: _selectedTripId,
                statusFilter: _statusFilter,
                onStatusFilterChanged: (value) =>
                    setState(() => _statusFilter = value),
                onSelect: _selectTrip,
              );
              final detailPanel = _ExecutionDetailPanel(
                trip: _selectedTrip,
                onRefreshLocation: _advanceSelectedVehicle,
                onCompleteTrip: _completeSelectedTrip,
              );

              if (!wide) {
                return Column(
                  children: [
                    mapPanel,
                    const SizedBox(height: 16),
                    queuePanel,
                    const SizedBox(height: 16),
                    detailPanel,
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
                        mapPanel,
                        const SizedBox(height: 16),
                        _RouteEventPanel(trip: _selectedTrip),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: Column(
                      children: [
                        queuePanel,
                        const SizedBox(height: 16),
                        detailPanel,
                      ],
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

class _ExecutionHeader extends StatelessWidget {
  const _ExecutionHeader({
    required this.selectedTrip,
    required this.onRefreshLocation,
    required this.onCompleteTrip,
  });

  final _ExecutionTrip selectedTrip;
  final VoidCallback onRefreshLocation;
  final VoidCallback onCompleteTrip;

  @override
  Widget build(BuildContext context) {
    return _ExecutionPanel(
      padding: const EdgeInsets.all(22),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 680,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: AppTheme.cyan,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '실행 트래킹',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.graphite,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Naver Map 기반 차량 위치, 운송 경로, ETA, 출발/도착 이벤트를 관제합니다.',
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
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderPill(
                icon: Icons.local_shipping_rounded,
                label: selectedTrip.vehicleNo,
                color: AppTheme.teal,
              ),
              SizedBox(
                width: 150,
                child: OutlinedButton.icon(
                  onPressed: onRefreshLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('위치 갱신'),
                ),
              ),
              SizedBox(
                width: 150,
                child: ElevatedButton.icon(
                  onPressed: onCompleteTrip,
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('완료 처리'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutionMetricStrip extends StatelessWidget {
  const _ExecutionMetricStrip({
    required this.activeCount,
    required this.delayRiskCount,
    required this.coldChainCount,
    required this.averageProgress,
  });

  final int activeCount;
  final int delayRiskCount;
  final int coldChainCount;
  final double averageProgress;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _ExecutionMetric(
        label: '운송 실행중',
        value: '$activeCount건',
        detail: '출발/도착 이벤트 감시',
        icon: Icons.route_rounded,
        color: AppTheme.teal,
      ),
      _ExecutionMetric(
        label: '지연 위험',
        value: '$delayRiskCount건',
        detail: 'ETA 기준 자동 분류',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.amber,
      ),
      _ExecutionMetric(
        label: '콜드체인',
        value: '$coldChainCount건',
        detail: '온도 로그 추적',
        icon: Icons.thermostat_rounded,
        color: const Color(0xFF2563EB),
      ),
      _ExecutionMetric(
        label: '평균 진행률',
        value: '${(averageProgress * 100).round()}%',
        detail: '전체 실행 운송 기준',
        icon: Icons.timeline_rounded,
        color: AppTheme.cyan,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 640
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
                (metric) => SizedBox(width: width, child: _MetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _TrackingMapPanel extends StatelessWidget {
  const _TrackingMapPanel({required this.trip, required this.compact});

  final _ExecutionTrip trip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _ExecutionPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.map_rounded,
            title: '차량 이동 및 경로 관제',
            subtitle: '네이버 지도 레이어에 연결될 차량 위치와 운송계획 경로입니다.',
          ),
          const SizedBox(height: 14),
          const _NaverMapStatusBar(),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: compact ? 0.86 : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: NaverRouteMapView(
                          routePoints: trip.stops
                              .map(
                                (stop) => NaverRoutePoint(
                                  label: stop.name,
                                  latitude: stop.latitude,
                                  longitude: stop.longitude,
                                  plannedTime: stop.plannedTime,
                                ),
                              )
                              .toList(),
                          progress: trip.progress,
                          vehicleLabel: trip.vehicleNo,
                          statusLabel: trip.statusLabel,
                          etaLabel: trip.etaLabel,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _MapBadge(
                          icon: Icons.sensors_rounded,
                          label: 'LIVE GPS',
                          color: AppTheme.teal,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _MapBadge(
                          icon: Icons.layers_rounded,
                          label: 'Naver Map LIVE',
                          color: AppTheme.cyan,
                        ),
                      ),
                      for (final stop in trip.stops)
                        Positioned(
                          left: (stop.point.dx * constraints.maxWidth - 54)
                              .clamp(10, constraints.maxWidth - 124),
                          top: (stop.point.dy * constraints.maxHeight + 12)
                              .clamp(48, constraints.maxHeight - 54),
                          child: _StopLabel(stop: stop),
                        ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _MapBadge(
                          icon: Icons.access_time_filled_rounded,
                          label: 'ETA ${trip.etaLabel}',
                          color: trip.delayColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NaverMapStatusBar extends StatelessWidget {
  const _NaverMapStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: const [
          _LayerChip(icon: Icons.map_rounded, label: 'Naver Map'),
          _LayerChip(icon: Icons.vpn_key_rounded, label: '키 연결 완료'),
          _LayerChip(icon: Icons.polyline_rounded, label: '경로 폴리라인'),
          _LayerChip(icon: Icons.pin_drop_rounded, label: '상하차/경유 마커'),
          _LayerChip(icon: Icons.traffic_rounded, label: '교통/ETA 준비'),
        ],
      ),
    );
  }
}

class _TripQueuePanel extends StatelessWidget {
  const _TripQueuePanel({
    required this.trips,
    required this.selectedTripId,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.onSelect,
  });

  final List<_ExecutionTrip> trips;
  final int selectedTripId;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<_ExecutionTrip> onSelect;

  @override
  Widget build(BuildContext context) {
    return _ExecutionPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.format_list_bulleted_rounded,
            title: '운송 실행 목록',
            subtitle: '출발, 이동중, 도착예정 차량을 실시간으로 확인합니다.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: '전체',
                selected: statusFilter == 'ALL',
                onTap: () => onStatusFilterChanged('ALL'),
              ),
              _FilterChip(
                label: '지연위험',
                selected: statusFilter == 'DELAY',
                onTap: () => onStatusFilterChanged('DELAY'),
              ),
              _FilterChip(
                label: '콜드체인',
                selected: statusFilter == 'COLD',
                onTap: () => onStatusFilterChanged('COLD'),
              ),
              _FilterChip(
                label: '도착예정',
                selected: statusFilter == 'ARRIVING',
                onTap: () => onStatusFilterChanged('ARRIVING'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (trips.isEmpty)
            const _EmptyQueue()
          else
            for (final trip in trips) ...[
              _TripTile(
                trip: trip,
                selected: trip.id == selectedTripId,
                onTap: () => onSelect(trip),
              ),
              if (trip != trips.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  final _ExecutionTrip trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.cyan.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppTheme.cyan.withValues(alpha: 0.34)
                  : AppTheme.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: trip.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: trip.statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.planNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.graphite,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                        Text(
                          '${trip.vehicleNo} · ${trip.driverName}',
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
                  _SmallPill(label: trip.statusLabel, color: trip.statusColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${trip.originName} → ${trip.destinationName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: trip.progress,
                  minHeight: 7,
                  backgroundColor: AppTheme.line,
                  valueColor: AlwaysStoppedAnimation<Color>(trip.statusColor),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MetaChip(icon: Icons.schedule_rounded, label: trip.etaLabel),
                  _MetaChip(
                    icon: Icons.sensors_rounded,
                    label: trip.lastSignal,
                  ),
                  _MetaChip(
                    icon: Icons.thermostat_rounded,
                    label: trip.temperatureText,
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

class _ExecutionDetailPanel extends StatelessWidget {
  const _ExecutionDetailPanel({
    required this.trip,
    required this.onRefreshLocation,
    required this.onCompleteTrip,
  });

  final _ExecutionTrip trip;
  final VoidCallback onRefreshLocation;
  final VoidCallback onCompleteTrip;

  @override
  Widget build(BuildContext context) {
    return _ExecutionPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.assignment_turned_in_rounded,
            title: '운송실행 상세',
            subtitle: '차량, 기사, 위치 신호, 다음 이벤트를 확인합니다.',
          ),
          const SizedBox(height: 14),
          _InfoRow(label: '운송계획', value: trip.planNo),
          _InfoRow(
            label: '고객/화물',
            value: '${trip.customerName} · ${trip.cargoType}',
          ),
          _InfoRow(label: '운송사', value: trip.carrierName),
          _InfoRow(
            label: '차량/기사',
            value: '${trip.vehicleNo} · ${trip.driverName}',
          ),
          _InfoRow(label: '다음 이벤트', value: trip.nextEvent),
          _InfoRow(label: 'GPS 신호', value: trip.lastSignal),
          const SizedBox(height: 12),
          _ExecutionNotice(
            icon: trip.delayRiskCode == 'GOOD'
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            title: trip.delayRiskCode == 'GOOD' ? '정상 운행' : '지연 위험 관리',
            message: trip.delayDescription,
            color: trip.delayColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefreshLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('GPS 갱신'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCompleteTrip,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('완료'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteEventPanel extends StatelessWidget {
  const _RouteEventPanel({required this.trip});

  final _ExecutionTrip trip;

  @override
  Widget build(BuildContext context) {
    return _ExecutionPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.timeline_rounded,
            title: '운송 이벤트 타임라인',
            subtitle: '출발, 경유, 도착 이벤트와 증빙 수신 상태입니다.',
          ),
          const SizedBox(height: 14),
          for (final event in trip.events) ...[
            _ExecutionEventRow(event: event),
            if (event != trip.events.last)
              const Divider(height: 18, color: AppTheme.line),
          ],
        ],
      ),
    );
  }
}

class _ExecutionEventRow extends StatelessWidget {
  const _ExecutionEventRow({required this.event});

  final _ExecutionEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  letterSpacing: 0,
                  height: 1.32,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.slate,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionNotice extends StatelessWidget {
  const _ExecutionNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.32,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _ExecutionMetric metric;

  @override
  Widget build(BuildContext context) {
    return _ExecutionPanel(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  metric.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        Icon(icon, color: AppTheme.cyan, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
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
      ],
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: selected ? AppTheme.teal : Colors.white,
      side: BorderSide(color: selected ? AppTheme.teal : AppTheme.line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.graphite,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.graphite,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.slate, size: 14),
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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

class _StopLabel extends StatelessWidget {
  const _StopLabel({required this.stop});

  final _RouteStop stop;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        stop.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        '조건에 맞는 운송 실행 건이 없습니다.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.slate,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ExecutionMetric {
  const _ExecutionMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _RouteStop {
  const _RouteStop({
    required this.name,
    required this.point,
    required this.plannedTime,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final Offset point;
  final String plannedTime;
  final double latitude;
  final double longitude;
}

class _GpsPosition {
  const _GpsPosition({
    required this.latitude,
    required this.longitude,
    required this.headingDegree,
  });

  final double latitude;
  final double longitude;
  final double headingDegree;
}

_GpsPosition _positionAlongStops(List<_RouteStop> stops, double progress) {
  if (stops.isEmpty) {
    return const _GpsPosition(latitude: 0, longitude: 0, headingDegree: 0);
  }
  if (stops.length == 1) {
    return _GpsPosition(
      latitude: stops.first.latitude,
      longitude: stops.first.longitude,
      headingDegree: 0,
    );
  }

  final clampedProgress = progress.clamp(0.0, 1.0);
  var totalDistance = 0.0;
  for (var index = 0; index < stops.length - 1; index += 1) {
    totalDistance += _stopDistance(stops[index], stops[index + 1]);
  }

  var remaining = totalDistance * clampedProgress;
  for (var index = 0; index < stops.length - 1; index += 1) {
    final start = stops[index];
    final end = stops[index + 1];
    final segmentDistance = _stopDistance(start, end);
    if (remaining > segmentDistance) {
      remaining -= segmentDistance;
      continue;
    }

    final ratio = segmentDistance == 0 ? 0.0 : remaining / segmentDistance;
    return _GpsPosition(
      latitude: start.latitude + (end.latitude - start.latitude) * ratio,
      longitude: start.longitude + (end.longitude - start.longitude) * ratio,
      headingDegree: _headingDegree(start, end),
    );
  }

  final previous = stops[stops.length - 2];
  final last = stops.last;
  return _GpsPosition(
    latitude: last.latitude,
    longitude: last.longitude,
    headingDegree: _headingDegree(previous, last),
  );
}

double _stopDistance(_RouteStop a, _RouteStop b) {
  final latitude = a.latitude - b.latitude;
  final longitude = a.longitude - b.longitude;
  return math.sqrt(latitude * latitude + longitude * longitude);
}

double _headingDegree(_RouteStop start, _RouteStop end) {
  final radians = math.atan2(
    end.longitude - start.longitude,
    end.latitude - start.latitude,
  );
  final degree = radians * 180 / math.pi;
  return degree < 0 ? degree + 360 : degree;
}

String _statusLabelForCode(String statusCode) {
  return switch (statusCode) {
    'READY' => '출발대기',
    'DEPARTED' => '운송중',
    'ARRIVING' => '도착예정',
    'COMPLETED' => '완료',
    _ => '운송중',
  };
}

String _etaLabelForMinutes(int etaMinutes) {
  if (etaMinutes <= 0) {
    return '도착';
  }
  if (etaMinutes >= 60) {
    final hours = etaMinutes ~/ 60;
    final minutes = etaMinutes % 60;
    return minutes == 0 ? '$hours시간' : '$hours시간 $minutes분';
  }
  return '$etaMinutes분';
}

class _ExecutionEvent {
  const _ExecutionEvent({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color color;
}

class _ExecutionTrip {
  const _ExecutionTrip({
    required this.id,
    required this.planNo,
    required this.customerName,
    required this.carrierName,
    required this.vehicleNo,
    required this.driverName,
    required this.originName,
    required this.destinationName,
    required this.cargoType,
    required this.temperatureText,
    required this.temperatureControlled,
    required this.statusCode,
    required this.delayRiskCode,
    required this.delayDescription,
    required this.etaMinutes,
    required this.progress,
    required this.lastSignal,
    required this.nextEvent,
    required this.stops,
    required this.events,
  });

  final int id;
  final String planNo;
  final String customerName;
  final String carrierName;
  final String vehicleNo;
  final String driverName;
  final String originName;
  final String destinationName;
  final String cargoType;
  final String temperatureText;
  final bool temperatureControlled;
  final String statusCode;
  final String delayRiskCode;
  final String delayDescription;
  final int etaMinutes;
  final double progress;
  final String lastSignal;
  final String nextEvent;
  final List<_RouteStop> stops;
  final List<_ExecutionEvent> events;

  String get statusLabel => switch (statusCode) {
    'READY' => '출발대기',
    'DEPARTED' => '운송중',
    'ARRIVING' => '도착예정',
    'COMPLETED' => '완료',
    _ => '운송중',
  };

  Color get statusColor => switch (statusCode) {
    'READY' => AppTheme.slate,
    'DEPARTED' => AppTheme.teal,
    'ARRIVING' => AppTheme.amber,
    'COMPLETED' => AppTheme.cyan,
    _ => AppTheme.teal,
  };

  Color get delayColor => switch (delayRiskCode) {
    'HIGH' => const Color(0xFFDC2626),
    'WATCH' => AppTheme.amber,
    _ => AppTheme.teal,
  };

  String get etaLabel {
    if (etaMinutes <= 0) {
      return '도착';
    }
    if (etaMinutes >= 60) {
      final hours = etaMinutes ~/ 60;
      final minutes = etaMinutes % 60;
      return minutes == 0 ? '$hours시간' : '$hours시간 $minutes분';
    }
    return '$etaMinutes분';
  }

  _ExecutionTrip copyWith({
    String? statusCode,
    int? etaMinutes,
    double? progress,
    String? lastSignal,
  }) {
    return _ExecutionTrip(
      id: id,
      planNo: planNo,
      customerName: customerName,
      carrierName: carrierName,
      vehicleNo: vehicleNo,
      driverName: driverName,
      originName: originName,
      destinationName: destinationName,
      cargoType: cargoType,
      temperatureText: temperatureText,
      temperatureControlled: temperatureControlled,
      statusCode: statusCode ?? this.statusCode,
      delayRiskCode: delayRiskCode,
      delayDescription: delayDescription,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      progress: progress ?? this.progress,
      lastSignal: lastSignal ?? this.lastSignal,
      nextEvent: nextEvent,
      stops: stops,
      events: events,
    );
  }
}

const _seedExecutionTrips = [
  _ExecutionTrip(
    id: 1,
    planNo: 'LP-20260616-001',
    customerName: '삼성전자',
    carrierName: '직계약 위수탁',
    vehicleNo: '서울 82바 1724',
    driverName: '김도윤',
    originName: '수원 CDC',
    destinationName: '부산 RDC',
    cargoType: '전자부품',
    temperatureText: '상온',
    temperatureControlled: false,
    statusCode: 'DEPARTED',
    delayRiskCode: 'GOOD',
    delayDescription: '현재 속도와 교통 기준으로 계획 시간 내 도착 가능합니다.',
    etaMinutes: 84,
    progress: 0.62,
    lastSignal: '1분 전',
    nextEvent: '부산권 진입 확인',
    stops: [
      _RouteStop(
        name: '수원 CDC',
        point: Offset(0.16, 0.72),
        plannedTime: '09:00',
        latitude: 37.2636,
        longitude: 127.0286,
      ),
      _RouteStop(
        name: '옥천 HUB',
        point: Offset(0.43, 0.45),
        plannedTime: '12:40',
        latitude: 36.3012,
        longitude: 127.5681,
      ),
      _RouteStop(
        name: '부산 RDC',
        point: Offset(0.82, 0.28),
        plannedTime: '18:00',
        latitude: 35.1796,
        longitude: 129.0756,
      ),
    ],
    events: [
      _ExecutionEvent(
        title: '출발 완료',
        description: '수원 CDC에서 전자서명 출발 처리',
        time: '09:12',
        icon: Icons.flag_rounded,
        color: AppTheme.teal,
      ),
      _ExecutionEvent(
        title: '중간 경유',
        description: '옥천 HUB 통과, GPS 신호 정상',
        time: '12:48',
        icon: Icons.alt_route_rounded,
        color: AppTheme.cyan,
      ),
      _ExecutionEvent(
        title: '도착 예정',
        description: '부산 RDC 도착 예정 84분',
        time: 'ETA',
        icon: Icons.pin_drop_rounded,
        color: AppTheme.amber,
      ),
    ],
  ),
  _ExecutionTrip(
    id: 2,
    planNo: 'LP-20260616-002',
    customerName: '프레시온',
    carrierName: 'CJ대한통운',
    vehicleNo: '경기 91사 3342',
    driverName: '박성민',
    originName: '김포 콜드체인',
    destinationName: '서울 동부센터',
    cargoType: '냉장 식자재',
    temperatureText: '냉장 3.8도',
    temperatureControlled: true,
    statusCode: 'DEPARTED',
    delayRiskCode: 'WATCH',
    delayDescription: '강변북로 정체로 ETA가 18분 밀렸습니다. 고객 알림 후보입니다.',
    etaMinutes: 41,
    progress: 0.48,
    lastSignal: '2분 전',
    nextEvent: '도착 예정 알림',
    stops: [
      _RouteStop(
        name: '김포 콜드체인',
        point: Offset(0.18, 0.34),
        plannedTime: '06:00',
        latitude: 37.6151,
        longitude: 126.7158,
      ),
      _RouteStop(
        name: '상암 IC',
        point: Offset(0.46, 0.55),
        plannedTime: '07:10',
        latitude: 37.5794,
        longitude: 126.8913,
      ),
      _RouteStop(
        name: '서울 동부센터',
        point: Offset(0.78, 0.42),
        plannedTime: '08:20',
        latitude: 37.5385,
        longitude: 127.1238,
      ),
    ],
    events: [
      _ExecutionEvent(
        title: '출발 완료',
        description: '냉장 온도 로그 수신 시작',
        time: '06:18',
        icon: Icons.flag_rounded,
        color: AppTheme.teal,
      ),
      _ExecutionEvent(
        title: '정체 감지',
        description: 'ETA 18분 증가, 지연 위험 관찰',
        time: '07:12',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.amber,
      ),
      _ExecutionEvent(
        title: '도착 전 알림',
        description: '센터 예약 슬롯 재확인 필요',
        time: '예정',
        icon: Icons.notifications_active_rounded,
        color: AppTheme.cyan,
      ),
    ],
  ),
  _ExecutionTrip(
    id: 3,
    planNo: 'LP-20260616-003',
    customerName: '신세계푸드',
    carrierName: '한진',
    vehicleNo: '인천 77아 9014',
    driverName: '정하준',
    originName: '평택 콜드센터',
    destinationName: '강남 점포권',
    cargoType: '냉동 간편식',
    temperatureText: '냉동 -18.6도',
    temperatureControlled: true,
    statusCode: 'ARRIVING',
    delayRiskCode: 'GOOD',
    delayDescription: '온도 이탈 없이 도착권에 진입했습니다.',
    etaMinutes: 16,
    progress: 0.91,
    lastSignal: '방금 전',
    nextEvent: '하차 도착 처리',
    stops: [
      _RouteStop(
        name: '평택 콜드센터',
        point: Offset(0.2, 0.76),
        plannedTime: '07:00',
        latitude: 36.9921,
        longitude: 127.1126,
      ),
      _RouteStop(
        name: '판교 JC',
        point: Offset(0.55, 0.5),
        plannedTime: '09:10',
        latitude: 37.3948,
        longitude: 127.1112,
      ),
      _RouteStop(
        name: '강남 점포권',
        point: Offset(0.76, 0.24),
        plannedTime: '10:30',
        latitude: 37.4979,
        longitude: 127.0276,
      ),
    ],
    events: [
      _ExecutionEvent(
        title: '출발 완료',
        description: '냉동 온도 로그 정상',
        time: '07:06',
        icon: Icons.flag_rounded,
        color: AppTheme.teal,
      ),
      _ExecutionEvent(
        title: '도착권 진입',
        description: '하차지 7.2km 전방',
        time: '10:06',
        icon: Icons.pin_drop_rounded,
        color: AppTheme.amber,
      ),
      _ExecutionEvent(
        title: 'POD 대기',
        description: '도착 후 전자서명 수신 예정',
        time: '대기',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.cyan,
      ),
    ],
  ),
  _ExecutionTrip(
    id: 4,
    planNo: 'LP-20260616-004',
    customerName: 'K패션',
    carrierName: '직계약 개별차량',
    vehicleNo: '서울 91자 4508',
    driverName: '이서윤',
    originName: '인천 반품센터',
    destinationName: '이천 물류센터',
    cargoType: '패션 반품',
    temperatureText: '상온',
    temperatureControlled: false,
    statusCode: 'READY',
    delayRiskCode: 'HIGH',
    delayDescription: '출발 예정 시간이 초과되었습니다. 배차 담당자 확인이 필요합니다.',
    etaMinutes: 132,
    progress: 0.08,
    lastSignal: '12분 전',
    nextEvent: '출발 처리',
    stops: [
      _RouteStop(
        name: '인천 반품센터',
        point: Offset(0.17, 0.54),
        plannedTime: '13:00',
        latitude: 37.4563,
        longitude: 126.7052,
      ),
      _RouteStop(
        name: '광주 분기점',
        point: Offset(0.5, 0.38),
        plannedTime: '14:10',
        latitude: 37.41,
        longitude: 127.25,
      ),
      _RouteStop(
        name: '이천 물류센터',
        point: Offset(0.82, 0.64),
        plannedTime: '15:40',
        latitude: 37.2722,
        longitude: 127.435,
      ),
    ],
    events: [
      _ExecutionEvent(
        title: '상차 대기',
        description: '상차 완료 이벤트 미수신',
        time: '13:08',
        icon: Icons.pending_actions_rounded,
        color: AppTheme.amber,
      ),
      _ExecutionEvent(
        title: '출발 지연',
        description: '계획 대비 8분 초과',
        time: '감지',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFDC2626),
      ),
      _ExecutionEvent(
        title: '담당자 확인',
        description: '배차 담당자 확인 대상',
        time: '대기',
        icon: Icons.support_agent_rounded,
        color: AppTheme.cyan,
      ),
    ],
  ),
];
