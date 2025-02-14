import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/host_providers.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class VisitHistoryScreen extends HookConsumerWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(currentHostProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/host'),
        ),
        title: const Text('Visit History'),
      ),
      body: hostAsync.when(
        data: (host) {
          if (host == null) {
            return const Center(child: Text('Host data not found'));
          }

          return StreamBuilder(
            stream: ref.read(hostServiceProvider).getHostVisitorHistory(host.email),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final visits = snapshot.data ?? [];

              if (visits.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No visit history available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: visits.length,
                itemBuilder: (context, index) {
                  final visit = visits[index];
                  return VisitHistoryCard(visitData: visit);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class VisitHistoryCard extends StatelessWidget {
  final Map<String, dynamic> visitData;

  const VisitHistoryCard({
    super.key,
    required this.visitData,
  });

  @override
  Widget build(BuildContext context) {
    final visitTime = visitData['visitTime'] as DateTime? ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            (visitData['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'V',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          visitData['name'] ?? 'Unknown Visitor',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy hh:mm a').format(visitTime),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (visitData['email'] != null && visitData['email'] != 'Not provided')
              Text(
                visitData['email'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (visitData['purposeOfVisit'] != null)
                  _buildInfoRow('Purpose', visitData['purposeOfVisit']),
                _buildInfoRow('Contact', visitData['contactNumber'] ?? 'Not provided'),
                if (visitData['department'] != null)
                  _buildInfoRow('Department', visitData['department']),
                _buildInfoRow('Visit Type', visitData['type']?.toString().toUpperCase() ?? 'Not specified'),
                _buildInfoRow('Group Size', (visitData['numberOfVisitors'] ?? 1).toString()),
                if (visitData['vehicleNumber'] != null)
                  _buildInfoRow('Vehicle', visitData['vehicleNumber']),
                if (visitData['remarks'] != null)
                  _buildInfoRow('Remarks', visitData['remarks']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
