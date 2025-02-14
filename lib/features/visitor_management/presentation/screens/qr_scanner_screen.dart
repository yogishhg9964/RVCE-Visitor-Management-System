import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_provider.dart';
import 'return_visitor_details_screen.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  void _processQRData(String qrData) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      print('QR Data received: $qrData'); // Debug log
      final jsonData = jsonDecode(qrData);
      final phoneNumber = jsonData['contactNumber'] as String;
      print('Phone number extracted: $phoneNumber'); // Debug log

      // First try to find visitor by phone
      final visitorData = await ref
          .read(firebaseServiceProvider)
          .findVisitorByPhone(phoneNumber);

      print('Visitor data found: $visitorData'); // Debug log

      if (mounted) {
        if (visitorData != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReturnVisitorDetailsScreen(
                phoneNumber: phoneNumber,
                visitorData: visitorData,
              ),
            ),
          );
        } else {
          // If no data found, try using the QR data directly
          final qrVisitorData = {
            'name': jsonData['name'],
            'contactNumber': jsonData['contactNumber'],
            'email': jsonData['email'],
            'address': jsonData['address'],
            'department': jsonData['department'],
            'type': 'quick_checkin',
            // Add any other relevant fields from QR data
          };

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReturnVisitorDetailsScreen(
                phoneNumber: phoneNumber,
                visitorData: qrVisitorData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error processing QR data: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to make square frame
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = screenSize.width * 0.7; // 70% of screen width

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.off
                      ? Icons.flash_off
                      : Icons.flash_on,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                );
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _processQRData(barcode.rawValue!);
                        return;
                      }
                    }
                  },
                ),
                // Updated QR Frame Overlay
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Top-left corner
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.blue, width: 4),
                                  left: BorderSide(color: Colors.blue, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Top-right corner
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.blue, width: 4),
                                  right: BorderSide(color: Colors.blue, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Bottom-left corner
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.blue, width: 4),
                                  left: BorderSide(color: Colors.blue, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Bottom-right corner
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.blue, width: 4),
                                  right: BorderSide(color: Colors.blue, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Center alignment crosshair (optional)
                          Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.5),
                                  width: 1,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Column(
              children: [
                Text(
                  'Center QR code in the square',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Keep your device steady',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
