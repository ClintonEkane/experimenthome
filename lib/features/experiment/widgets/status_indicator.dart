import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mqtt_service.dart';

class StatusIndicator extends StatelessWidget {
  final DeviceStatus status;

  const StatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DeviceStatus.online => AppColors.online,
      DeviceStatus.stale => AppColors.stale,
      DeviceStatus.offline => AppColors.offline,
    };

    final label = switch (status) {
      DeviceStatus.online => 'Online',
      DeviceStatus.stale => 'Delayed',
      DeviceStatus.offline => 'Offline',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
