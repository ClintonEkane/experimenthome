import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/session_record.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../widgets/chip_logo.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<List<SessionRecord>>(
              stream: firestore.userSessionsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Failed to load history.',
                          style: TextStyle(color: AppColors.textSecondary)));
                }
                final sessions = snapshot.data ?? [];
                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 64,
                            color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        const Text('No sessions yet',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Your experiment sessions will appear here.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _SessionCard(session: sessions[i]),
                );
              },
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionRecord session;
  const _SessionCard({required this.session});

  static final _fmt = DateFormat('dd MMM yyyy, HH:mm');

  String _resistorLabel(int ohms) =>
      ohms >= 1000 ? '${ohms ~/ 1000}kΩ' : '$ohmsΩ';

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmt.format(session.startedAt);
    final duration =
        session.endedAt?.difference(session.startedAt).inSeconds;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ChipLogo(size: 24),
                const SizedBox(width: 8),
                Text('Ohm\'s Law Verification',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _InfoChip(
                    label: 'Resistor',
                    value: _resistorLabel(session.resistorOhms)),
                const SizedBox(width: 12),
                _InfoChip(
                    label: 'Peak Current',
                    value: '${session.peakCurrentMa.toStringAsFixed(2)} mA'),
                if (duration != null) ...[
                  const SizedBox(width: 12),
                  _InfoChip(label: 'Duration', value: '${duration}s'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}
