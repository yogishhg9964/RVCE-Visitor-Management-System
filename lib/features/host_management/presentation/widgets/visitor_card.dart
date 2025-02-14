import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart' show HapticFeedback;

class VisitorCard extends StatelessWidget {
  final Map<String, dynamic> visitorData;
  final Function(String) onApprove;
  final Function(String) onReject;

  const VisitorCard({
    super.key,
    required this.visitorData,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = visitorData['status']?.toString().toLowerCase() ?? 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          maintainState: true,
          initiallyExpanded: false,
          childrenPadding: EdgeInsets.zero,
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
          trailing: _buildStatusChip(status),
          onExpansionChanged: (isExpanded) {
            // Optional: Add feedback when card is tapped
            if (isExpanded) {
              HapticFeedback.lightImpact();
            }
          },
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Purpose', visitorData['purposeOfVisit'] ?? 'Not specified'),
                  _buildInfoRow('Contact', visitorData['contactNumber'] ?? 'Not provided'),
                  _buildInfoRow('Department', visitorData['department'] ?? 'Not specified'),
                  _buildInfoRow('Visit Type', visitorData['type']?.toString().toUpperCase() ?? 'Not specified'),
                  _buildInfoRow('Visitors', (visitorData['numberOfVisitors'] ?? 1).toString()),
                  _buildInfoRow('Status', status.toUpperCase()),
                  if (status == 'approved') _buildInfoRow(
                    'Approved At',
                    _formatTimestamp(visitorData['approvedAt']),
                  ),
                  if (status == 'rejected') _buildInfoRow(
                    'Rejected At',
                    _formatTimestamp(visitorData['rejectedAt']),
                  ),
                  const SizedBox(height: 16),
                  if (status == 'pending') Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => onReject(visitorData['visitId']),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        label: const Text('Reject'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => onApprove(visitorData['visitId']),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    // Skip status chip for checked_in status
    if (status.toLowerCase() == 'checked_in') {
      return const SizedBox.shrink();
    }

    Color chipColor;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'approved':
        chipColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        chipColor = Colors.red;
        icon = Icons.cancel;
        break;
      case 'pending':
        chipColor = Colors.orange;
        icon = Icons.pending;
        break;
      default:
        return const SizedBox.shrink(); // Don't show chip for unknown status
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is DateTime) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}';
    }
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    // Skip showing status row if it's checked_in
    if (label.toLowerCase() == 'status' && value.toLowerCase() == 'checked_in') {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
