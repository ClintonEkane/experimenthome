import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/current_reading.dart';

class LiveGraph extends StatelessWidget {
  final List<CurrentReading> readings;
  final bool isActive;

  const LiveGraph({super.key, required this.readings, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current vs Time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: readings.length < 2
                  ? Center(
                      child: Text(
                        isActive
                            ? 'Waiting for data...'
                            : 'Start the experiment to see the graph',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  : LineChart(_buildChartData()),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData() {
    final spots = readings.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.currentMa);
    }).toList();

    final maxY = readings.map((r) => r.currentMa).reduce((a, b) => a > b ? a : b);
    final minY = readings.map((r) => r.currentMa).reduce((a, b) => a < b ? a : b);
    final yPadding = (maxY - minY) * 0.2;

    return LineChartData(
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: const Text('mA',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('samples',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade200),
      ),
      minY: (minY - yPadding).clamp(0, double.infinity),
      maxY: maxY + yPadding + 1,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.graphLine,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.graphLine.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}
