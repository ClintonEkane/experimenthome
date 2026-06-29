import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/experiment.dart';
import '../../../core/models/session_record.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../experiment/screens/experiment_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth      = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user      = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ExperimentHome'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Experiments ─────────────────────────────────────────────────
            const Text('Experiments',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<List<Experiment>>(
              stream: firestore.experimentsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final experiments = snap.data ?? [];
                if (experiments.isEmpty) {
                  return const Text('No experiments available.',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                return Column(
                  children: experiments
                      .map((e) => _ExperimentCard(experiment: e))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Recent Sessions ──────────────────────────────────────────────
            const Text('Recent Sessions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (user == null)
              const Text('Not logged in',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              StreamBuilder<List<SessionRecord>>(
                stream: firestore.userSessionsStream(user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final sessions = snap.data ?? [];
                  if (sessions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No sessions yet. Run your first experiment!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: sessions
                        .take(3)
                        .map((s) => _SessionCard(session: s))
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Experiment card ──────────────────────────────────────────────────────────

class _ExperimentCard extends StatelessWidget {
  final Experiment experiment;
  const _ExperimentCard({required this.experiment});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StreamBuilder<List<Station>>(
        stream: firestore.stationsStream(experiment.id),
        builder: (context, snap) {
          final stations  = snap.data ?? [];
          final available = stations.where((s) => s.isAvailable).length;
          final total     = stations.length;

          final statusColor = total == 0
              ? AppColors.offline
              : available > 0
                  ? AppColors.online
                  : AppColors.stale;
          final statusLabel = total == 0
              ? 'Offline'
              : available > 0
                  ? '$available/$total available'
                  : 'In use';

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.memory,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(experiment.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(experiment.description,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(statusLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final SessionRecord session;
  const _SessionCard({required this.session});

  static final _fmt = DateFormat('dd MMM, HH:mm');

  String _resistorLabel(int ohms) =>
      ohms >= 1000 ? '${ohms ~/ 1000}kΩ' : '$ohmsΩ';

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmt.format(session.startedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 1,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ohm's Law — ${_resistorLabel(session.resistorOhms)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Peak: ${session.peakCurrentMa.toStringAsFixed(2)} mA',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
