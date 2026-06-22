import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/experiment.dart';
import '../../../core/services/firestore_service.dart';
import '../../experiment/screens/experiment_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Experiments'),
      ),
      body: StreamBuilder<List<Experiment>>(
        stream: firestore.experimentsStream(),
        builder: (context, expSnap) {
          if (expSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (expSnap.hasError) {
            return Center(child: Text('Error: ${expSnap.error}'));
          }
          final experiments = expSnap.data ?? [];
          if (experiments.isEmpty) {
            return const Center(
              child: Text('No experiments available yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: experiments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final exp = experiments[i];
              return _ExperimentCard(experiment: exp);
            },
          );
        },
      ),
    );
  }
}

class _ExperimentCard extends StatelessWidget {
  final Experiment experiment;

  const _ExperimentCard({required this.experiment});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<List<Station>>(
      stream: firestore.stationsStream(experiment.id),
      builder: (context, stationSnap) {
        final stations = stationSnap.data ?? [];
        final available = stations.where((s) => s.isAvailable).length;
        final total = stations.length;

        final statusColor = total == 0
            ? AppColors.offline
            : available > 0
                ? AppColors.online
                : AppColors.stale;

        final statusLabel = total == 0
            ? 'Offline'
            : available > 0
                ? '$available of $total station${total > 1 ? 's' : ''} available'
                : 'In use';

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExperimentScreen(
                  experiment: experiment,
                  stations: stations,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.biotech, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(experiment.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(experiment.description,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
