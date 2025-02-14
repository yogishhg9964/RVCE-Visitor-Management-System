import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../domain/models/visitor.dart';
import '../../domain/models/department_data.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/utils/responsive_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/navigation_utils.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../providers/firebase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/email_provider.dart';

class VisitorSuccessScreen extends ConsumerStatefulWidget {
  final Visitor visitor;

  const VisitorSuccessScreen({
    super.key,
    required this.visitor,
  });

  @override
  ConsumerState<VisitorSuccessScreen> createState() => _VisitorSuccessScreenState();
}

class _VisitorSuccessScreenState extends ConsumerState<VisitorSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey _qrKey = GlobalKey();
  String? _qrCodeUrl;
  bool _isSaving = false;

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

  String get _visitorQrData {
    final Map<String, dynamic> qrData = {
      'name': widget.visitor.name,
      'address': widget.visitor.address,
      'contactNumber': widget.visitor.contactNumber,
      'email': widget.visitor.email,
      'vehicleNumber': widget.visitor.vehicleNumber,
      'purposeOfVisit': widget.visitor.purposeOfVisit,
      'numberOfVisitors': widget.visitor.numberOfVisitors,
      'whomToMeet': getHostNameFromEmail(widget.visitor.whomToMeet),
      'whomToMeetEmail': widget.visitor.whomToMeet,
      'department': widget.visitor.department,
      'documentType': widget.visitor.documentType,
      'entryTime': widget.visitor.entryTime?.toIso8601String(),
      'visitorId': widget.visitor.entryTime?.millisecondsSinceEpoch
          .toString()
          .substring(5),
    };
    return json.encode(qrData);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.forward().then((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showSuccessAnimation = false;
          });
          _updateVisitorStatus();
        }
      });
    });
  }

  bool _showSuccessAnimation = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _updateVisitorStatus() async {
    try {
      final String visitorId =
          widget.visitor.entryTime!.millisecondsSinceEpoch.toString();

      // Create update data
      final Map<String, dynamic> updateData = {
        'status': 'checked_in',
        'updatedAt': FieldValue.serverTimestamp(),
        'checkInTime': FieldValue.serverTimestamp(),
      };

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .update(updateData);
    } catch (e) {
      print('Error updating visitor status: $e'); // For debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Error updating status: ',
                children: [
                  TextSpan(
                    text: e.toString(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveQrCodeAndEmail() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Capture QR code as image
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find QR code widget');
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not convert QR code to image');
      
      final qrBytes = byteData.buffer.asUint8List();
      
      // Upload to Firebase Storage
      final visitorId = widget.visitor.entryTime!.millisecondsSinceEpoch.toString();
      final qrUrl = await ref.read(firebaseServiceProvider).uploadQrCode(
        visitorId,
        qrBytes,
      );

      setState(() {
        _qrCodeUrl = qrUrl;
      });

      // Send email if visitor has email address
      if (widget.visitor.email?.isNotEmpty ?? false) {
        final emailSent = await ref.read(emailServiceProvider).sendQrCodeEmail(
          toEmail: widget.visitor.email!,
          visitorName: widget.visitor.name,
          qrCodeUrl: qrUrl,
          visitor: widget.visitor,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                emailSent
                    ? 'QR Code saved and email sent successfully!'
                    : 'QR Code saved but failed to send email.',
              ),
              backgroundColor: emailSent ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR Code saved successfully! No email address provided.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = ResponsiveUtils.getHorizontalPadding(screenWidth);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  if (_showSuccessAnimation)
                    Lottie.asset(
                      'assets/animations/success.json',
                      width: 200,
                      height: 200,
                      controller: _controller,
                      repeat: false,
                    ),
                  if (!_showSuccessAnimation) const SizedBox(height: 200),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          const Text(
                            'Registration Successful!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Visitor ID: ${widget.visitor.entryTime?.millisecondsSinceEpoch.toString().substring(5)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          RepaintBoundary(
                            key: _qrKey,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: _visitorQrData,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppTheme.primaryColor,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveQrCodeAndEmail,
                              icon: _isSaving 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.email_outlined),
                              label: Text(_isSaving ? 'Saving...' : 'Save & Email QR Code'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildDetailCard(
                            title: 'Visitor Details',
                            icon: Icons.person,
                            details: [
                              DetailItem('Name', widget.visitor.name),
                              DetailItem('Address', widget.visitor.address),
                              DetailItem(
                                  'Contact', widget.visitor.contactNumber),
                              DetailItem('Email', widget.visitor.email),
                              if (widget.visitor.vehicleNumber != null)
                                DetailItem(
                                    'Vehicle', widget.visitor.vehicleNumber!),
                              DetailItem(
                                  'Purpose', widget.visitor.purposeOfVisit),
                              DetailItem('Visitors',
                                  widget.visitor.numberOfVisitors.toString()),
                              DetailItem(
                                  'Host',
                                  getHostNameFromEmail(
                                      widget.visitor.whomToMeet)),
                              DetailItem(
                                  'Department', widget.visitor.department),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailCard(
                            title: 'Meeting Details',
                            icon: Icons.business,
                            details: [
                              DetailItem(
                                  'Department', widget.visitor.department),
                              DetailItem('Host', widget.visitor.whomToMeet),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailCard(
                            title: 'Document Details',
                            icon: Icons.document_scanner,
                            details: [
                              DetailItem('Type', widget.visitor.documentType),
                              if (widget.visitor.documentUrl != null)
                                DetailItem('Status', 'Uploaded'),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () =>
                                  NavigationUtils.navigateToHome(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Back to Home',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<DetailItem> details,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details.map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${detail.label}:',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          detail.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class DetailItem {
  final String label;
  final String value;

  DetailItem(this.label, this.value);
}
