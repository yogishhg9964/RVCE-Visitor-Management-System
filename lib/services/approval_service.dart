import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void scheduleDeletion(String documentId, String hostEmail) {
    Timer(const Duration(seconds: 30), () async {
      try {
        final docRef = _firestore
            .collection('hosts')
            .doc(hostEmail)
            .collection('pending_approvals')
            .doc(documentId);

        await docRef.delete();
        print('Document $documentId deleted successfully');

        // Also delete from the main collection
        final mainDocRef = _firestore.collection('visits').doc(documentId);
        await mainDocRef.delete();
        print('Main document $documentId deleted successfully');
      } catch (e) {
        print('Error deleting document $documentId: $e');
      }
    });
  }

  Future<void> approveVisitor(String visitorId, String hostEmail) async {
    try {
      final batch = _firestore.batch();
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Get visitor data from pending approvals
      final pendingRef = hostRef.collection('pending_approvals').doc(visitorId);
      final pendingDoc = await pendingRef.get();
      if (!pendingDoc.exists) {
        throw Exception('Visitor not found in pending approvals');
      }

      final visitorData = pendingDoc.data()!;

      // Move to approved visitors
      final approvedRef = hostRef.collection('approved_visitors').doc(visitorId);
      batch.set(approvedRef, {
        ...visitorData,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Delete from pending
      batch.delete(pendingRef);

      // Increment visitor count
      batch.update(hostRef, {
        'numberOfVisitors': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      print('Error approving visitor: $e');
      throw Exception('Failed to approve visitor: $e');
    }
  }

  Future<void> rejectVisitor(String visitorId, String hostEmail) async {
    try {
      final batch = _firestore.batch();
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Get visitor data from pending approvals
      final pendingRef = hostRef.collection('pending_approvals').doc(visitorId);
      final pendingDoc = await pendingRef.get();
      if (!pendingDoc.exists) {
        throw Exception('Visitor not found in pending approvals');
      }

      final visitorData = pendingDoc.data()!;

      // Move to rejected visitors
      final rejectedRef = hostRef.collection('rejected_visitors').doc(visitorId);
      batch.set(rejectedRef, {
        ...visitorData,
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Delete from pending
      batch.delete(pendingRef);

      await batch.commit();
    } catch (e) {
      print('Error rejecting visitor: $e');
      throw Exception('Failed to reject visitor: $e');
    }
  }
}
