import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/host.dart';
import '../../domain/models/visitor.dart';

class HostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerHost({
    required String email,
    required String name,
    required String department,
    required String contactNumber,
    String? profilePhotoUrl,
    String? position,
  }) async {
    try {
      final host = Host(
        email: email,
        name: name,
        department: department,
        contactNumber: contactNumber,
        role: 'host',
        profilePhotoUrl: profilePhotoUrl,
        position: position,
        notificationSettings: {
          'emailNotifications': true,
          'smsNotifications': false,
        },
      );

      final hostData = {
        ...host.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();

      // Add to hosts collection
      final hostRef = _firestore.collection('hosts').doc(email);
      batch.set(hostRef, hostData);

      // Add to users collection
      final userRef = _firestore.collection('users').doc(email);
      batch.set(userRef, hostData, SetOptions(merge: true));

      // Removed the creation of dummy pending_approvals document

      await batch.commit();
      print('Host registration completed successfully');
    } catch (e) {
      print('Error registering host: $e');
      throw Exception('Failed to register host: $e');
    }
  }

  Future<Host?> fetchHostData(String email) async {
    try {
      final hostDoc = await _firestore.collection('hosts').doc(email).get();
      if (!hostDoc.exists) return null;
      return Host.fromFirestore(hostDoc);
    } catch (e) {
      print('Error fetching host data: $e');
      throw Exception('Failed to fetch host data: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getHostNotifications(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<int> getPendingApprovalsCount(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('pending_approvals')
        .where('status', isEqualTo: 'pending')  // Add this filter
        .where('sendNotification', isEqualTo: true)  // Add this to match actual pending requests
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getApprovedVisitorsCount(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('approved_visitors')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getVisitHistoryCount(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('visit_history')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<Map<String, dynamic>>> getPendingApprovals(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('pending_approvals')
        .orderBy('createdAt', descending: true)  // Only use createdAt ordering
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> approvals = [];
          
          for (var doc in snapshot.docs) {
            final approvalData = doc.data();
            // Filter sendNotification in memory instead of in query
            if (approvalData['sendNotification'] == true) {
              final visitorId = approvalData['visitorId'];
              try {
                // Fetch visitor details from visitors collection
                final visitorDoc = await _firestore
                    .collection('visitors')
                    .where('contactNumber', isEqualTo: visitorId)
                    .limit(1)
                    .get();

                if (visitorDoc.docs.isNotEmpty) {
                  final visitorData = visitorDoc.docs.first.data();
                  approvals.add({
                    ...approvalData,
                    ...visitorData,
                    'id': doc.id,
                    'createdAt': approvalData['createdAt']?.toDate(),
                    'name': visitorData['name'] ?? 'Unknown',
                    'email': visitorData['email'] ?? 'Not provided',
                    'contactNumber': visitorData['contactNumber'] ?? 'Not provided',
                    'purposeOfVisit': visitorData['purposeOfVisit'] ?? 'Not specified',
                    'type': visitorData['type'] ?? 'general',
                    'department': visitorData['department'] ?? 'Not specified',
                  });
                }
              } catch (e) {
                print('Error fetching visitor data: $e');
              }
            }
          }
          return approvals;
        });
  }

  Stream<List<Map<String, dynamic>>> getVisitHistory(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('visit_history')
        .orderBy('visitTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
            'visitTime': data['visitTime']?.toDate(),
            'createdAt': data['createdAt']?.toDate(),
          };
        }).toList());
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

  Stream<List<Map<String, dynamic>>> getApprovedVisitors(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .collection('approved_visitors')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<Host?> getHostStream(String email) {
    return _firestore
        .collection('hosts')
        .doc(email)
        .snapshots()
        .map((doc) => doc.exists ? Host.fromFirestore(doc) : null);
  }

  Stream<List<Map<String, dynamic>>> getHostVisitorHistory(String hostEmail) {
    return _firestore
        .collection('hosts')
        .doc(hostEmail)
        .collection('visit_history')
        .orderBy('visitTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> visits = [];
          
          for (var doc in snapshot.docs) {
            final visitData = doc.data();
            // Changed: Use visitorId or contactNumber as the reference
            final visitorRef = visitData['visitorId'] ?? visitData['contactNumber'];
            
            if (visitorRef != null) {
              try {
                // Try to fetch visitor from visitors collection
                final visitorDoc = await _firestore
                    .collection('visitors')
                    .where('contactNumber', isEqualTo: visitorRef)
                    .limit(1)
                    .get();

                if (visitorDoc.docs.isNotEmpty) {
                  final visitorData = visitorDoc.docs.first.data();
                  print('Found visitor data: $visitorData'); // Debug print
                  
                  visits.add({
                    ...visitData,
                    ...visitorData,
                    'id': doc.id,
                    'visitTime': _parseTimestamp(visitData['visitTime']),
                    'createdAt': _parseTimestamp(visitData['createdAt']),
                    'name': visitorData['name'] ?? 'Unknown',
                    'email': visitorData['email'] ?? 'Not provided',
                    'contactNumber': visitorData['contactNumber'] ?? 'Not provided',
                    'purposeOfVisit': visitorData['purposeOfVisit'] ?? 'Not specified',
                    'type': visitorData['type'] ?? 'general',
                    'status': visitData['status'] ?? 'unknown',
                    'numberOfVisitors': visitorData['numberOfVisitors'] ?? 1,
                    'department': visitorData['department'] ?? 'Not specified',
                  });
                } else {
                  print('No visitor found for reference: $visitorRef'); // Debug print
                  visits.add(_createDefaultVisitData(doc.id, visitData));
                }
              } catch (e) {
                print('Error fetching visitor data: $e'); // Debug print
                visits.add(_createDefaultVisitData(doc.id, visitData));
              }
            } else {
              print('No visitor reference found in visit data'); // Debug print
              visits.add(_createDefaultVisitData(doc.id, visitData));
            }
          }
          return visits;
        });
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.parse(timestamp);
    return DateTime.now();
  }

  Map<String, dynamic> _createDefaultVisitData(String docId, Map<String, dynamic> visitData) {
    return {
      ...visitData,
      'id': docId,
      'visitTime': _parseTimestamp(visitData['visitTime']),
      'name': 'Unknown Visitor',
      'email': 'Not available',
      'contactNumber': 'Not available',
      'purposeOfVisit': visitData['purpose'] ?? 'Not specified',
      'type': visitData['type'] ?? 'general',
      'status': visitData['status'] ?? 'unknown',
      'numberOfVisitors': visitData['numberOfVisitors'] ?? 1,
      'department': visitData['department'] ?? 'Not specified',
    };
  }
}
