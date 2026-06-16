import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class NaverRoutePoint {
  const NaverRoutePoint({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.plannedTime,
  });

  final String label;
  final double latitude;
  final double longitude;
  final String plannedTime;
}

class NaverRouteMapView extends StatefulWidget {
  const NaverRouteMapView({
    required this.routePoints,
    required this.progress,
    required this.vehicleLabel,
    required this.statusLabel,
    required this.etaLabel,
    super.key,
  });

  final List<NaverRoutePoint> routePoints;
  final double progress;
  final String vehicleLabel;
  final String statusLabel;
  final String etaLabel;

  @override
  State<NaverRouteMapView> createState() => _NaverRouteMapViewState();
}

class _NaverRouteMapViewState extends State<NaverRouteMapView> {
  static int _nextViewId = 0;

  late final String _viewType = 'ktms-naver-route-map-${_nextViewId++}';
  web.HTMLIFrameElement? _frame;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final frame = web.HTMLIFrameElement()
        ..src = _mapSource()
        ..allow = 'geolocation'
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      frame.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%'
        ..display = 'block'
        ..backgroundColor = '#eaf4f6';
      _frame = frame;
      return frame;
    });
  }

  @override
  void didUpdateWidget(covariant NaverRouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final frame = _frame;
    if (frame != null) {
      frame.src = _mapSource();
    }
  }

  String _mapSource() {
    final points = widget.routePoints
        .map((point) => '${point.latitude},${point.longitude}')
        .join('|');
    final labels = widget.routePoints.map((point) => point.label).join('|');
    final times = widget.routePoints
        .map((point) => point.plannedTime)
        .join('|');
    final query = Uri(
      queryParameters: {
        'points': points,
        'labels': labels,
        'times': times,
        'progress': widget.progress.toStringAsFixed(4),
        'vehicle': widget.vehicleLabel,
        'status': widget.statusLabel,
        'eta': widget.etaLabel,
      },
    ).query;
    return 'naver_map.html?$query';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
