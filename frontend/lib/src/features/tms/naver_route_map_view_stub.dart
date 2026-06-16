import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

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

class NaverRouteMapView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FallbackRoutePainter(
        progress: progress,
        vehicleLabel: vehicleLabel,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 18,
            child: _FallbackBadge(
              icon: Icons.map_rounded,
              label: 'Naver Map Web 연결',
              color: AppTheme.cyan,
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: _FallbackBadge(
              icon: Icons.local_shipping_rounded,
              label: vehicleLabel,
              color: AppTheme.teal,
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: _FallbackBadge(
              icon: Icons.schedule_rounded,
              label: 'ETA $etaLabel',
              color: AppTheme.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({
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
              style: const TextStyle(
                color: AppTheme.graphite,
                fontSize: 12,
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

class _FallbackRoutePainter extends CustomPainter {
  const _FallbackRoutePainter({
    required this.progress,
    required this.vehicleLabel,
  });

  final double progress;
  final String vehicleLabel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF4F6),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.64)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (
      var x = -size.width * 0.2;
      x < size.width * 1.2;
      x += size.width * 0.18
    ) {
      canvas.drawLine(
        Offset(x, size.height * 0.08),
        Offset(x + size.width * 0.36, size.height * 0.94),
        gridPaint,
      );
    }
    for (var y = size.height * 0.16; y < size.height; y += size.height * 0.2) {
      canvas.drawLine(
        Offset(size.width * 0.04, y),
        Offset(size.width * 0.94, y + size.height * 0.02),
        gridPaint,
      );
    }

    final points = [
      Offset(size.width * 0.16, size.height * 0.72),
      Offset(size.width * 0.43, size.height * 0.45),
      Offset(size.width * 0.82, size.height * 0.28),
    ];
    final route = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy);

    canvas.drawPath(
      route.shift(const Offset(4, 5)),
      Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.12)
        ..strokeWidth = 13
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = AppTheme.cyan.withValues(alpha: 0.72)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final vehicle = Offset.lerp(points[0], points[2], progress.clamp(0, 1))!;
    for (final point in points) {
      canvas.drawCircle(point, 13, Paint()..color = Colors.white);
      canvas.drawCircle(point, 9, Paint()..color = AppTheme.cyan);
      canvas.drawCircle(point, 4, Paint()..color = const Color(0xFF0B1220));
    }
    _drawVehicleMarker(canvas, size, vehicle);
  }

  void _drawVehicleMarker(Canvas canvas, Size size, Offset vehicle) {
    const iconSize = 38.0;
    const markerHeight = 38.0;
    const horizontalPadding = 8.0;
    const labelGap = 7.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: vehicleLabel,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final markerWidth =
        horizontalPadding * 2 + iconSize + labelGap + textPainter.width;
    final left = (vehicle.dx - iconSize / 2 - horizontalPadding).clamp(
      12.0,
      size.width - markerWidth - 12.0,
    );
    final top = (vehicle.dy - markerHeight / 2).clamp(
      12.0,
      size.height - markerHeight - 12.0,
    );
    final markerRect = Rect.fromLTWH(left, top, markerWidth, markerHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        markerRect.shift(const Offset(0, 4)),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markerRect, const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markerRect, const Radius.circular(8)),
      Paint()
        ..color = AppTheme.teal.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final iconCenter = Offset(
      left + horizontalPadding + iconSize / 2,
      top + markerHeight / 2,
    );
    canvas.drawCircle(
      iconCenter,
      17,
      Paint()..color = AppTheme.teal.withValues(alpha: 0.14),
    );
    _drawTruckIcon(canvas, iconCenter);

    textPainter.paint(
      canvas,
      Offset(
        left + horizontalPadding + iconSize + labelGap,
        top + (markerHeight - textPainter.height) / 2,
      ),
    );
  }

  void _drawTruckIcon(Canvas canvas, Offset center) {
    final bodyPaint = Paint()..color = AppTheme.teal;
    final cabPaint = Paint()..color = const Color(0xFF0D9488);
    final windowPaint = Paint()..color = const Color(0xFFD9FBF4);
    final wheelPaint = Paint()..color = const Color(0xFF172033);
    final hubPaint = Paint()..color = Colors.white;
    final origin = center - const Offset(19, 11);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + 1.0, origin.dy + 4.0, 23.8, 13.4),
        const Radius.circular(2.0),
      ),
      bodyPaint,
    );

    final cab = Path()
      ..moveTo(origin.dx + 24.8, origin.dy + 9.2)
      ..lineTo(origin.dx + 30.2, origin.dy + 9.2)
      ..quadraticBezierTo(
        origin.dx + 31.8,
        origin.dy + 9.2,
        origin.dx + 32.7,
        origin.dy + 10.5,
      )
      ..lineTo(origin.dx + 36.1, origin.dy + 15.2)
      ..lineTo(origin.dx + 36.1, origin.dy + 19.0)
      ..lineTo(origin.dx + 24.8, origin.dy + 19.0)
      ..close();
    canvas.drawPath(cab, cabPaint);

    canvas.drawRect(
      Rect.fromLTWH(origin.dx + 1.0, origin.dy + 17.0, 35.1, 3.0),
      bodyPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + 28.0, origin.dy + 11.5, 4.9, 3.4),
        const Radius.circular(0.8),
      ),
      windowPaint,
    );

    canvas.drawLine(
      Offset(origin.dx + 4.0, origin.dy + 7.0),
      Offset(origin.dx + 22.0, origin.dy + 7.0),
      Paint()
        ..color = windowPaint.color.withValues(alpha: 0.75)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    final leftWheel = Offset(origin.dx + 9.0, origin.dy + 20.4);
    final rightWheel = Offset(origin.dx + 28.4, origin.dy + 20.4);
    canvas.drawCircle(leftWheel, 3.8, wheelPaint);
    canvas.drawCircle(rightWheel, 3.8, wheelPaint);
    canvas.drawCircle(leftWheel, 1.4, hubPaint);
    canvas.drawCircle(rightWheel, 1.4, hubPaint);
  }

  @override
  bool shouldRepaint(covariant _FallbackRoutePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.vehicleLabel != vehicleLabel;
  }
}
