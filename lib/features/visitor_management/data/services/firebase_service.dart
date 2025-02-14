import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/models/visitor.dart';
import '../../domain/models/department_data.dart';
import 'dart:io';
import 'dart:typed_data'; // Add this import for Uint8List
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String getHostNameFromEmail(String email) {
    for (var staffList in departmentStaff.values) {
      for (var staff in staffList) {
        if (staff.value == email) {
          return staff.label;
        }
      }
    }
    return email;
  }

  Future<Map<String, dynamic>?> findVisitorByPhone(String phoneNumber) async {
    try {
      print('Searching for visitor with phone: $phoneNumber');

      final visitorSnapshot = await _firestore
          .collection('visitors')
          .where('contactNumber', isEqualTo: phoneNumber)
          .where('isDeleted', isEqualTo: false)
          .get();

      if (visitorSnapshot.docs.isEmpty) {
        print('No visitor found');
        return null;
      }

      final visitorDoc = visitorSnapshot.docs.first;
      final rawData = visitorDoc.data();
      final visitorData = rawData is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      // Get form-specific details based on visitor type
      final String visitorId = visitorDoc.id;
      Map<String, dynamic>? formDetails;

      if (visitorData['type'] == 'registration') {
        final detailsDoc = await _firestore
            .collection('registration_details')
            .doc(visitorId)
            .get();
        if (detailsDoc.exists) {
          final rawDetails = detailsDoc.data();
          formDetails = rawDetails is Map<String, dynamic>
              ? Map<String, dynamic>.from(rawDetails)
              : <String, dynamic>{};
        }
      } else if (visitorData['type'] == 'cab') {
        final detailsDoc = await _firestore
            .collection('cab_entry_details')
            .doc(visitorId)
            .get();
        if (detailsDoc.exists) {
          final rawDetails = detailsDoc.data();
          formDetails = rawDetails is Map<String, dynamic>
              ? Map<String, dynamic>.from(rawDetails)
              : <String, dynamic>{};
        }
      }

      // Combine visitor data with form details
      return {
        ...visitorData,
        ...?formDetails,
      };
    } catch (e) {
      print('Error finding visitor: $e');
      throw Exception('Failed to find visitor: $e');
    }
  }

  Future<void> _updateVisitCount(String contactNumber, String visitId) async {
    try {
      final visitorQuery = await _firestore
          .collection('visitors')
          .where('contactNumber', isEqualTo: contactNumber)
          .limit(1)
          .get();

      if (visitorQuery.docs.isNotEmpty) {
        await visitorQuery.docs.first.reference.update({
          'lastVisit': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'visitCount': FieldValue.increment(1),
          'lastVisitId': visitId,
        });
        print('Visit count updated successfully');
      }
    } catch (e) {
      print('Error updating visit count: $e');
      throw Exception('Failed to update visit count: $e');
    }
  }

  Future<bool> isVisitorRegistered(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('visitors')
          .where('contactNumber', isEqualTo: phoneNumber)
          .where('isDeleted', isEqualTo: false)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking visitor registration: $e');
      throw Exception('Failed to check visitor registration: $e');
    }
  }

  Future<String> _uploadFile(dynamic file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      late final UploadTask uploadTask;

      if (kIsWeb) {
        // For web, handle bytes
        if (file is Uint8List) {
          uploadTask = ref.putData(
            file,
            SettableMetadata(contentType: 'application/octet-stream'),
          );
        } else {
          throw Exception('Invalid file format for web upload');
        }
      } else {
        // For mobile, handle File
        if (file is File) {
          uploadTask = ref.putFile(file);
        } else {
          throw Exception('Invalid file format for mobile upload');
        }
      }

      final snapshot = await uploadTask.whenComplete(() => null);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> saveVisitorData(
    Visitor visitor, {
    File? photoFile,
    File? documentFile, 
    bool skipRegistrationCheck = false,
  }) async {
    try {
      // Check if visitor is already registered only if not skipping the check
      if (!skipRegistrationCheck) {
        final isRegistered = await isVisitorRegistered(visitor.contactNumber);
        if (isRegistered) {
          throw Exception(
              'Visitor already registered. Please use Quick Check-in.');
        }
      }

      final String visitorId =
          visitor.entryTime!.millisecondsSinceEpoch.toString();
      final String hostName = getHostNameFromEmail(visitor.whomToMeet);

      // Check for existing visitor
      final existingVisitorQuery = await _firestore
          .collection('visitors')
          .where('contactNumber', isEqualTo: visitor.contactNumber)
          .limit(1)
          .get();

      final int currentVisitCount = existingVisitorQuery.docs.isNotEmpty
          ? (existingVisitorQuery.docs.first.data()['visitCount'] ?? 0) + 1
          : 1;

      // Upload files if they exist
      String? photoUrl;
      String? documentUrl;
      
      if (photoFile != null) {
        photoUrl = await _uploadFile(
          photoFile,
          'visitors/$visitorId/photo.${photoFile.path.split('.').last}'
        );
      }
      
      if (documentFile != null) {
        documentUrl = await _uploadFile(
          documentFile,
          'visitors/$visitorId/document.${documentFile.path.split('.').last}'
        );
      }

      // Common visitor data structure
      final Map<String, dynamic> visitorData = {
        // Basic Info
        'name': visitor.name,
        'contactNumber': visitor.contactNumber,
        'email': visitor.email,
        'purposeOfVisit': visitor.purposeOfVisit,
        'whomToMeet': hostName,
        'whomToMeetEmail': visitor.whomToMeet,
        'department': visitor.department,

        // Timestamps
        'entryTime': visitor.entryTime?.toIso8601String(),
        'exitTime': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Status and Type
        'type': visitor.type,
        'id': visitorId,
        'isDeleted': false,
        'status': 'pending',

        // Visit Details
        'sendNotification': visitor.sendNotification,
        'numberOfVisitors': visitor.numberOfVisitors,
        'vehicleNumber': visitor.vehicleNumber,

        // Document Details
        'documentType': visitor.documentType,
        'hasDocument': documentFile != null,
        'hasPhoto': photoFile != null,
        'photoUrl': photoUrl,
        'documentUrl': documentUrl,

        // Visit Tracking
        'lastVisit': FieldValue.serverTimestamp(),
        'visitCount': currentVisitCount,
        'lastVisitId': visitorId,
      };

      // Save to visitors collection
      await _firestore.collection('visitors').doc(visitorId).set(visitorData);

      // Handle form-specific data
      if (visitor.type == 'registration') {
        final registrationData = {
          // Reference
          'visitorId': visitorId,

          // Form Details
          'address': visitor.address,
          'email': visitor.email,
          'documentType': visitor.documentType,
          'numberOfVisitors': visitor.numberOfVisitors,
          'emergencyContactName': visitor.emergencyContactName,
          'emergencyContactNumber': visitor.emergencyContactNumber,

          // Document Details
          'hasDocument': documentFile != null,
          'hasPhoto': photoFile != null,
          'photoFileName': photoFile?.path.split('/').last,
          'documentFileName': documentFile?.path.split('/').last,
          'photoUrl': photoUrl,
          'documentUrl': documentUrl,

          // Timestamps
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'entryTime': visitor.entryTime?.toIso8601String(),
          'exitTime': null,

          // Status and Approval
          'status': 'pending',
          'isApproved': false,
          'approvedBy': null,
          'approvedAt': null,
          'remarks': null,

          // Visit Details
          'purpose': visitor.purposeOfVisit,
          'department': visitor.department,
          'whomToMeet': hostName,
          'whomToMeetEmail': visitor.whomToMeet,

          // Notification
          'sendNotification': visitor.sendNotification,
          'notificationSent': false,
          'notificationSentAt': null,

          // Visit Tracking
          'visitNumber': currentVisitCount,
        };

        await _firestore
            .collection('registration_details')
            .doc(visitorId)
            .set(registrationData);
      } else if (visitor.type == 'cab') {
        final cabData = {
          // Reference
          'visitorId': visitorId,

          // Basic Info
          'name': visitor.name,
          'contactNumber': visitor.contactNumber,
          'email': visitor.email,
          'address': visitor.address,

          // Cab Details
          'cabProvider': visitor.cabProvider,
          'driverName': visitor.driverName,
          'driverContact': visitor.driverContact,
          'vehicleNumber': visitor.vehicleNumber,

          // Visit Details
          'purposeOfVisit': visitor.purposeOfVisit,
          'numberOfVisitors': visitor.numberOfVisitors,
          'whomToMeet': hostName,
          'whomToMeetEmail': visitor.whomToMeet,
          'department': visitor.department,

          // Document Details
          'documentType': visitor.documentType,
          'hasDocument': documentFile != null,
          'documentFileName': documentFile?.path.split('/').last,
          'documentUrl': documentUrl,
          'hasPhoto': photoFile != null,
          'photoFileName': photoFile?.path.split('/').last,
          'photoUrl': photoUrl,

          // Emergency Contact
          'emergencyContactName': visitor.emergencyContactName,
          'emergencyContactNumber': visitor.emergencyContactNumber,

          // Timestamps
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'entryTime': visitor.entryTime?.toIso8601String(),
          'exitTime': null,

          // Status and Approval
          'status': 'pending',
          'isApproved': false,
          'approvedBy': null,
          'approvedAt': null,
          'remarks': null,

          // Visit Tracking
          'visitNumber': currentVisitCount,
          'type': 'cab',
        };

        await _firestore
            .collection('cab_entry_details')
            .doc(visitorId)
            .set(cabData);
      }

      // Update visit count for existing visitor
      if (existingVisitorQuery.docs.isNotEmpty) {
        await existingVisitorQuery.docs.first.reference.update({
          'visitCount': currentVisitCount,
          'lastVisit': FieldValue.serverTimestamp(),
          'lastVisitId': visitorId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Add this: Save to visits collection for all types of registrations
      final Map<String, dynamic> visitData = {
        'visitId': visitorId,
        'visitorId': visitor.contactNumber,
        'name': visitor.name,
        'contactNumber': visitor.contactNumber,
        'email': visitor.email,
        'purposeOfVisit': visitor.purposeOfVisit,
        'numberOfVisitors': visitor.numberOfVisitors,
        'whomToMeet': hostName,
        'whomToMeetEmail': visitor.whomToMeet,
        'department': visitor.department,
        'entryTime': FieldValue.serverTimestamp(),
        'exitTime': null,
        'type': visitor.type,
        'status': 'checked_in',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'documentType': visitor.documentType,
        'hasDocument': documentFile != null,
        'hasPhoto': photoFile != null,
        'vehicleNumber': visitor.vehicleNumber,
        // Add cab-specific fields if type is cab
        ...(visitor.type == 'cab'
            ? {
                'cabProvider': visitor.cabProvider,
                'driverName': visitor.driverName,
                'driverContact': visitor.driverContact,
              }
            : {}),
      };

      await _firestore.collection('visits').doc(visitorId).set(visitData);

      // Add this: Update host's visitor count
      final hostEmail = visitor.whomToMeet; // This is the host's email
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Update host document in a transaction to ensure count accuracy
      await _firestore.runTransaction((transaction) async {
        final hostDoc = await transaction.get(hostRef);

        if (hostDoc.exists) {
          final currentCount = hostDoc.data()?['numberOfVisitors'] as int? ?? 0;
          transaction.update(hostRef, {
            'numberOfVisitors': (currentCount ?? 0) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
            'lastVisitor': visitorData['name'],
            'lastVisitTime': FieldValue.serverTimestamp(),
          });
        }
      });

      // After saving to visits collection, add visitor to host's collection
      final Map<String, dynamic> hostVisitorData = {
        'visitId': visitorId,
        'visitorId': visitor.contactNumber,
        'name': visitor.name,
        'contactNumber': visitor.contactNumber,
        'email': visitor.email,
        'purposeOfVisit': visitor.purposeOfVisit,
        'numberOfVisitors': visitor.numberOfVisitors,
        'department': visitor.department,
        'entryTime': visitor.entryTime?.toIso8601String(),
        'exitTime': null,
        'type': visitor.type,
        'status': 'checked_in',
        'documentType': visitor.documentType,
        'hasDocument': documentFile != null,
        'hasPhoto': photoFile != null,
        'vehicleNumber': visitor.vehicleNumber,
        ...(visitor.type == 'cab'
            ? {
                'cabProvider': visitor.cabProvider,
                'driverName': visitor.driverName,
                'driverContact': visitor.driverContact,
              }
            : {}),
      };

      await addVisitorToHost(visitor.whomToMeet, hostVisitorData, visitor);

      print('Visitor data saved successfully with ID: $visitorId');
    } catch (e) {
      print('Error saving visitor data: $e');
      throw Exception('Failed to save visitor data: $e');
    }
  }

  Future<void> saveReturnVisit(Visitor visitor) async {
    try {
      final String visitId = DateTime.now().millisecondsSinceEpoch.toString();
      final String hostName = getHostNameFromEmail(visitor.whomToMeet);

      // Quick check-in specific data
      final Map<String, dynamic> quickCheckInData = {
        // System Fields
        'visitId': visitId,
        'visitorId': visitor.contactNumber,
        'type': 'quick_checkin',
        'id': visitId,

        // Basic Info
        'name': visitor.name,
        'contactNumber': visitor.contactNumber,
        'email': visitor.email,
        'address': visitor.address,

        // Visit Details
        'purposeOfVisit': visitor.purposeOfVisit,
        'numberOfVisitors': visitor.numberOfVisitors,
        'whomToMeet': hostName,
        'whomToMeetEmail': visitor.whomToMeet,
        'department': visitor.department,

        // Timestamps
        'entryTime': FieldValue.serverTimestamp(),
        'exitTime': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Status and Approval
        'status': 'checked_in',
        'isApproved': true,
        'approvedBy': null,
        'approvedAt': FieldValue.serverTimestamp(),
        'remarks': null,

        // Notification
        'sendNotification': visitor.sendNotification,
        'notificationSent': false,
        'notificationSentAt': null,

        // Additional Tracking
        'isDeleted': false,
        'checkInMethod': 'quick',
        'previousVisitId': null,
        'deviceInfo': null,
        'ipAddress': null,
        'location': null,

        // Reference to original registration
        'originalRegistrationId': null,
        'lastVisitId': null,
      };

      // Save to quick_checkins collection
      await _firestore
          .collection('quick_checkins')
          .doc(visitId)
          .set(quickCheckInData);

      // Also save to visits collection for tracking
      final Map<String, dynamic> visitData = {
        'visitId': visitId,
        'visitorId': visitor.contactNumber,
        'name': visitor.name,
        'contactNumber': visitor.contactNumber,
        'purposeOfVisit': visitor.purposeOfVisit,
        'numberOfVisitors': visitor.numberOfVisitors,
        'whomToMeet': hostName,
        'whomToMeetEmail': visitor.whomToMeet,
        'department': visitor.department,
        'entryTime': FieldValue.serverTimestamp(),
        'exitTime': null,
        'type': 'quick_checkin',
        'status': 'checked_in',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('visits').doc(visitId).set(visitData);

      // Update visitor's last visit info in visitors collection
      final visitorQuery = await _firestore
          .collection('visitors')
          .where('contactNumber', isEqualTo: visitor.contactNumber)
          .limit(1)
          .get();

      if (visitorQuery.docs.isNotEmpty) {
        await visitorQuery.docs.first.reference.update({
          'lastVisit': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'visitCount': FieldValue.increment(1),
          'lastVisitId': visitId,
          'lastCheckInType': 'quick',
        });
      }

      // Add this: Update host's visitor count
      final hostEmail = visitor.whomToMeet;
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Update host document in a transaction
      await _firestore.runTransaction((transaction) async {
        final hostDoc = await transaction.get(hostRef);

        if (hostDoc.exists) {
          final currentCount = hostDoc.data()?['numberOfVisitors'] as int? ?? 0;
          transaction.update(hostRef, {
            'numberOfVisitors': currentCount + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // After saving to visits collection, add visitor to host's collection
      final Map<String, dynamic> hostVisitorData = {
        'visitId': visitId,
        'visitorId': visitor.contactNumber,
        'name': visitor.name,
        'contactNumber': visitor.contactNumber,
        'email': visitor.email,
        'purposeOfVisit': visitor.purposeOfVisit,
        'numberOfVisitors': visitor.numberOfVisitors,
        'department': visitor.department,
        'entryTime': visitor.entryTime?.toIso8601String(),
        'exitTime': null,
        'type': 'quick_checkin',
        'status': 'checked_in',
      };

      await addVisitorToHost(visitor.whomToMeet, hostVisitorData, visitor);

      print('Quick check-in saved successfully with ID: $visitId');
    } catch (e) {
      print('Error saving quick check-in: $e');
      throw Exception('Failed to save quick check-in: $e');
    }
  }

  Future<Map<String, dynamic>?> getVisitorDetailsByPhone(String phoneNumber) async {
    try {
      final visitorDoc = await _firestore
          .collection('visitors')
          .where('contactNumber', isEqualTo: phoneNumber)
          .orderBy('entryTime', descending: true)
          .limit(1)
          .get();

      if (visitorDoc.docs.isNotEmpty) {
        return visitorDoc.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting visitor details: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> getVisitorLogs({
    String? department,
    String? status,
    DateTime? selectedDate,
    String? searchQuery,
    String sortBy = 'createdAt',
    bool ascending = false,
    String? visitType,
  }) {
    try {
      Query query = _firestore.collection('visits');

      // Apply date filter first
      if (selectedDate != null) {
        final startOfDay =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final endOfDay = DateTime(selectedDate.year, selectedDate.month,
            selectedDate.day, 23, 59, 59);
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
        );
      }

      // Apply department filter
      if (department != null) {
        query = query.where('department', isEqualTo: department);
      }

      // Apply status filter
      if (status != null && status.toLowerCase() != 'all') {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      // Apply type filter
      if (visitType != null && visitType.toLowerCase() != 'all') {
        query = query.where('type', isEqualTo: visitType.toLowerCase());
      }

      // Always order by createdAt
      query = query.orderBy('createdAt', descending: !ascending);

      return query.snapshots().map((snapshot) {
        var docs = snapshot.docs.map((doc) {
          final data =
              Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['id'] = doc.id;

          // Convert Timestamps
          if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
            data['createdAt'] =
                (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (data['entryTime'] != null && data['entryTime'] is Timestamp) {
            data['entryTime'] =
                (data['entryTime'] as Timestamp).toDate().toIso8601String();
          }
          if (data['exitTime'] != null && data['exitTime'] is Timestamp) {
            data['exitTime'] =
                (data['exitTime'] as Timestamp).toDate().toIso8601String();
          }

          return data;
        }).toList();

        // Apply search filter if provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final searchLower = searchQuery.toLowerCase();
          docs = docs.where((doc) {
            return doc['name']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ==
                    true ||
                doc['contactNumber']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ==
                    true ||
                doc['whomToMeet']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ==
                    true ||
                doc['department']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ==
                    true;
          }).toList();
        }

        return docs;
      });
    } catch (e) {
      print('Error getting visitor logs: $e');
      throw Exception('Failed to get visitor logs: $e');
    }
  }

  Future<void> checkoutVisitor(String visitId) async {
    try {
      final batch = _firestore.batch();

      final visitDoc = await _firestore.collection('visits').doc(visitId).get();
      if (!visitDoc.exists) {
        throw Exception('Visit not found');
      }

      final rawData = visitDoc.data();
      final visitData = rawData is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final visitorType = visitData['type'] as String?;

      // Update timestamps with proper server timestamp
      final Map<String, dynamic> updateData = {
        'exitTime': FieldValue.serverTimestamp(),
        'status': 'checked_out',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update in visits collection
      batch.update(_firestore.collection('visits').doc(visitId), updateData);

      // Update in type-specific collection
      final typeCollections = {
        'quick_checkin': 'quick_checkins',
        'registration': 'registration_details',
        'cab': 'cab_entry_details',
      };

      if (visitorType != null && typeCollections.containsKey(visitorType)) {
        final typeRef =
            _firestore.collection(typeCollections[visitorType]!).doc(visitId);
        final typeDoc = await typeRef.get();
        if (typeDoc.exists) {
          batch.update(typeRef, updateData);
        }
      }

      // Update visitor's last checkout
      if (visitData.containsKey('contactNumber')) {
        final visitorQuery = await _firestore
            .collection('visitors')
            .where('contactNumber', isEqualTo: visitData['contactNumber'])
            .limit(1)
            .get();

        if (visitorQuery.docs.isNotEmpty) {
          batch.update(visitorQuery.docs.first.reference, {
            'lastCheckout': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      print('Visitor checked out successfully');
    } catch (e) {
      print('Error checking out visitor: $e');
      throw Exception('Failed to checkout visitor: $e');
    }
  }

  Future<void> addVisitorToHost(
      String hostEmail, Map<String, dynamic> visitorData, Visitor visitor) async {
    try {
      final hostRef = _firestore.collection('hosts').doc(hostEmail);

      // Create references for visitor history
      final visitorHistoryRef =
          hostRef.collection('visit_history').doc(visitorData['visitId']);

      await _firestore.runTransaction((transaction) async {
        final hostDoc = await transaction.get(hostRef);

        // Get current visit count
        final visitorHistorySnapshot = await _firestore
            .collection('hosts')
            .doc(hostEmail)
            .collection('visit_history')
            .count()
            .get();

        final currentCount = visitorHistorySnapshot.count;

        if (!hostDoc.exists) {
          transaction.set(hostRef, {
            'numberOfVisitors': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Store visitor history data
        transaction.set(visitorHistoryRef, {
          'visitId': visitorData['visitId'],
          'visitorId': visitorData['visitorId'],
          'visitTime': FieldValue.serverTimestamp(),
          'status': visitorData['status'],
          'type': visitorData['type'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Only create pending approval if sendNotification is explicitly true
        if (visitor.sendNotification == true) {
          final pendingApprovalRef =
              hostRef.collection('pending_approvals').doc(visitorData['visitId']);
              
          transaction.set(pendingApprovalRef, {
            'visitId': visitorData['visitId'],
            'visitorId': visitorData['visitorId'],
            'visitTime': FieldValue.serverTimestamp(),
            'status': 'pending',  // Set initial status as pending
            'createdAt': FieldValue.serverTimestamp(),
            'sendNotification': true,
            'notificationSent': false,  // Track if notification was sent
            'visitorName': visitorData['name'],  // Add visitor name for reference
            'purposeOfVisit': visitorData['purposeOfVisit'],
          });
        }

        // Update host stats with accurate count
        transaction.update(hostRef, {
          'numberOfVisitors': (currentCount ?? 0) + 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastVisitor': visitorData['name'],
          'lastVisitTime': FieldValue.serverTimestamp(),
        });
      });

      print('Visitor history' + 
            (visitor.sendNotification ? ' and pending approval' : '') + 
            ' added successfully');
    } catch (e) {
      print('Error adding visitor to host: $e');
      throw Exception('Failed to add visitor to host: $e');
    }
  }

  Future<String> uploadQrCode(String visitorId, Uint8List qrBytes) async {
    try {
      final ref = _storage.ref().child('visitors/$visitorId/qr_code.png');
      final uploadTask = ref.putData(
        qrBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update visitor document with QR URL
      await _firestore.collection('visitors').doc(visitorId).update({
        'qrCodeUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading QR code: $e');
      throw Exception('Failed to upload QR code: $e');
    }
  }
}
