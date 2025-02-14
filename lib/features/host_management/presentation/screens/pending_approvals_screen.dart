import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/host_providers.dart';
import '../widgets/pending_approval_card.dart'; // Updated import

class PendingApprovalsScreen extends HookConsumerWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(currentHostProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/host'),
        ),
        title: const Text('Pending Approvals'),
      ),
      body: hostAsync.when(
        data: (host) {
          if (host == null) {
            return const Center(
              child: Text('Host data not found'),
            );
          }

          return StreamBuilder(
            stream: ref.read(hostServiceProvider).getPendingApprovals(host.email),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final pendingApprovals = snapshot.data ?? [];

              if (pendingApprovals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.pending_actions_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending approvals',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingApprovals.length,
                itemBuilder: (context, index) {
                  final visitorData = pendingApprovals[index];
                  return PendingApprovalCard(
                    visitorData: visitorData,
                    onApprove: (id) => _handleApprove(ref, id, host.email),
                    onReject: (id) => _handleReject(ref, id, host.email),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Future<void> _handleApprove(WidgetRef ref, String visitorId, String hostEmail) async {
    try {
      await ref.read(hostServiceProvider).approveVisitor(visitorId, hostEmail);
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          const SnackBar(content: Text('Visitor approved successfully')),
        );
      }
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleReject(WidgetRef ref, String visitorId, String hostEmail) async {
    try {
      await ref.read(hostServiceProvider).rejectVisitor(visitorId, hostEmail);
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          const SnackBar(content: Text('Visitor rejected')),
        );
      }
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}