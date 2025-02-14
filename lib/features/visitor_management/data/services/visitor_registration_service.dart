import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/visitor.dart';

class VisitorRegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerVisitorWithHost({
    required Visitor visitor,
    required String hostEmail,
  }) async {
    try {
      final batch = _firestore.batch();
      final visitorRef = _firestore.collection('visitors').doc();
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Add visitor to visitors collection
      final visitorData = {
        ...visitor.toJson(),
        'id': visitorRef.id,
        'hostEmail': hostEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(visitorRef, visitorData);

      // Add visitor to host's pending_approvals
      final pendingApprovalRef = hostRef
          .collection('pending_approvals')
          .doc(visitorRef.id);
      batch.set(pendingApprovalRef, {
        ...visitorData,
        'visitTime': visitor.visitTime.toIso8601String(),
        'status': 'pending',
      });

      await batch.commit();
    } catch (e) {
      print('Error registering visitor: $e');
      throw Exception('Failed to register visitor: $e');
    }
  }

  Future<void> updateVisitorStatus({
    required String visitorId,
    required String hostEmail,
    required String status,
  }) async {
    try {
      final batch = _firestore.batch();
      final visitorRef = _firestore.collection('visitors').doc(visitorId);
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Update main visitor document
      batch.update(visitorRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from pending_approvals
      final pendingRef = hostRef
          .collection('pending_approvals')
          .doc(visitorId);
      batch.delete(pendingRef);

      // Add to visit_history
      final historyRef = hostRef
          .collection('visit_history')
          .doc(visitorId);
      batch.set(historyRef, {
        'visitorId': visitorId,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Increment total visitor count if approved
      if (status == 'approved') {
        batch.update(hostRef, {
          'numberOfVisitors': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating visitor status: $e');
      throw Exception('Failed to update visitor status: $e');
    }
  }
}
