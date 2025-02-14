import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PendingApprovalCard extends StatelessWidget {
  final Map<String, dynamic> visitorData;
  final Function(String) onApprove;
  final Function(String) onReject;

  const PendingApprovalCard({
    super.key,
    required this.visitorData,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                (visitorData['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'V',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              visitorData['name'] ?? 'Unknown Visitor',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              visitorData['email'] ?? visitorData['contactNumber'] ?? 'No Contact',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pending, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onReject(visitorData['visitId'] ?? ''),
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: const Text('REJECT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onApprove(visitorData['visitId'] ?? ''),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('APPROVE'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            title: const Text('View Details'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Purpose', visitorData['purposeOfVisit'] ?? 'Not specified'),
                    _buildInfoRow('Department', visitorData['department'] ?? 'Not specified'),
                    _buildInfoRow('Visit Type', visitorData['type']?.toString().toUpperCase() ?? 'Not specified'),
                    _buildInfoRow('Number of Visitors', (visitorData['numberOfVisitors'] ?? 1).toString()),
                    _buildInfoRow('Contact', visitorData['contactNumber'] ?? 'Not provided'),
                  ],
                ),
              ),
            ],
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
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
