import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class PendingApprovalsScreen extends StatelessWidget {
  const PendingApprovalsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pendingApprovalsStream = FirebaseFirestore.instance
        .collectionGroup('pending_approvals')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final approvedVisitorsStream = FirebaseFirestore.instance
        .collectionGroup('approved_visitors')
        .orderBy('approvedAt', descending: true)
        .snapshots();

    final rejectedVisitorsStream = FirebaseFirestore.instance
        .collectionGroup('rejected_visitors')
        .orderBy('rejectedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: pendingApprovalsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No pending approvals found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final hostEmail = docs[index].reference.parent.parent?.id ?? 'Unknown host';
                    final approvalData = {
                      ...data,
                      'id': docs[index].id,
                      'hostEmail': hostEmail,
                    };

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          child: Text(
                            approvalData['visitorName']?.substring(0, 1).toUpperCase() ?? 'V',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          approvalData['visitorName'] ?? 'Unknown Visitor',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Host: $hostEmail'),
                            Text('Status: ${approvalData['status'] ?? 'Unknown'}'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: approvedVisitorsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No approved visitors found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final hostEmail = docs[index].reference.parent.parent?.id ?? 'Unknown host';
                    final approvalData = {
                      ...data,
                      'id': docs[index].id,
                      'hostEmail': hostEmail,
                    };

                    _scheduleDeletion(approvalData['id'], hostEmail, 'approved_visitors');

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                        title: Text(
                          approvalData['visitorName'] ?? 'Unknown Visitor',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Host: $hostEmail'),
                            Text('Status: ${approvalData['status'] ?? 'Unknown'}'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: rejectedVisitorsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No rejected visitors found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final hostEmail = docs[index].reference.parent.parent?.id ?? 'Unknown host';
                    final approvalData = {
                      ...data,
                      'id': docs[index].id,
                      'hostEmail': hostEmail,
                    };

                    _scheduleDeletion(approvalData['id'], hostEmail, 'rejected_visitors');

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          child: const Icon(Icons.cancel, color: Colors.red),
                        ),
                        title: Text(
                          approvalData['visitorName'] ?? 'Unknown Visitor',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Host: $hostEmail'),
                            Text('Status: ${approvalData['status'] ?? 'Unknown'}'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleDeletion(String visitorId, String hostEmail, String collection) {
    Timer(const Duration(minutes: 1), () async {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('hosts')
            .doc(hostEmail)
            .collection(collection)
            .doc(visitorId);

        await docRef.delete();
        print('Document $visitorId deleted successfully from $collection');

        // Also delete from the main collection
        final mainDocRef = FirebaseFirestore.instance.collection('visits').doc(visitorId);
        await mainDocRef.delete();
        print('Main document $visitorId deleted successfully');
      } catch (e) {
        print('Error deleting document $visitorId from $collection: $e');
      }
    });
  }
}
