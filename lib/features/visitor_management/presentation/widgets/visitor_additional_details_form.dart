import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/route_utils.dart';
import '../../domain/models/visitor.dart';
import '../screens/visitor_success_screen.dart';
import '../../../../core/utils/responsive_utils.dart';
import 'dart:io';
import './camera_screen.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/firebase_provider.dart';
import '../../domain/models/department_data.dart'; // Add this import for documentTypes
import 'package:flutter/foundation.dart' show kIsWeb;

const int _maxVisitors = 15;

class VisitorAdditionalDetailsForm extends ConsumerStatefulWidget {
  final Visitor visitor;
  final void Function(Visitor updatedVisitor)? onSubmitted;

  const VisitorAdditionalDetailsForm({
    super.key,
    required this.visitor,
    this.onSubmitted,
  });

  @override
  ConsumerState<VisitorAdditionalDetailsForm> createState() =>
      _VisitorAdditionalDetailsFormState();
}

class _VisitorAdditionalDetailsFormState
    extends ConsumerState<VisitorAdditionalDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _vehicleController = TextEditingController();
  int _numberOfVisitors = 1;
  String? _photoUrl;
  String? _documentUrl;
  bool _sendNotification = false;
  File? _photoFile;
  File? _documentFile;
  bool _isLoading = false;
  String _selectedDocumentType = documentTypes[0].value; // Initialize with first value

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.visitor.email ?? '';
    _emergencyNameController.text = widget.visitor.emergencyContactName ?? '';
    _emergencyContactController.text =
        widget.visitor.emergencyContactNumber ?? '';
    _vehicleController.text = widget.visitor.vehicleNumber ?? '';
    _selectedDocumentType = widget.visitor.documentType ?? documentTypes[0].value;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyContactController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter email address';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateEmergencyContact(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (value.length != 10) {
      return 'Contact number must be 10 digits';
    }
    return null;
  }

  Future<void> _takePhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          onPhotoTaken: (String path) {
            setState(() {
              _photoFile = File(path);
              _photoUrl = path;
            });
          },
        ),
      ),
    );
  }

  void _uploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
        withData: true, // Ensure we get the bytes for web
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            // For web, create a fake file path and store bytes
            final bytes = result.files.first.bytes!;
            _photoFile = null; // Don't use File on web
            _photoUrl = 'photo_${DateTime.now().millisecondsSinceEpoch}';
            // Store bytes for later upload
            // You'll need to modify your upload logic to handle bytes
          } else {
            // For mobile, use file path
            _photoFile = File(result.files.first.path!);
            _photoUrl = result.files.first.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Error picking file: ',
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

  void _uploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
        withData: true, // Ensure we get the bytes for web
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            // For web, create a fake file path and store bytes
            final bytes = result.files.first.bytes!;
            _documentFile = null; // Don't use File on web
            _documentUrl = 'document_${DateTime.now().millisecondsSinceEpoch}';
            // Store bytes for later upload
            // You'll need to modify your upload logic to handle bytes
          } else {
            // For mobile, use file path
            _documentFile = File(result.files.first.path!);
            _documentUrl = result.files.first.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Error picking file: ',
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

  Future<void> _takeDocumentPhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          onPhotoTaken: (String path) {
            setState(() {
              _documentFile = File(path);
              _documentUrl = path;
            });
          },
        ),
      ),
    );
  }

  void _sendNotificationToHost() async {
    // TODO: Implement notification sending
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification sent to host'),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Show upload progress dialog
        if (_photoFile != null || _documentFile != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading files...'),
                ],
              ),
            ),
          );
        }

        final updatedVisitor = widget.visitor.copyWith(
          email: _emailController.text,
          emergencyContactName: _emergencyNameController.text.isEmpty
              ? null
              : _emergencyNameController.text,
          emergencyContactNumber: _emergencyContactController.text.isEmpty
              ? null
              : _emergencyContactController.text,
          vehicleNumber:
              _vehicleController.text.isEmpty ? null : _vehicleController.text,
          numberOfVisitors: _numberOfVisitors,
          photoUrl: _photoUrl,
          documentUrl: _documentUrl,
          sendNotification: _sendNotification,
          documentType: _selectedDocumentType,
        );

        // Skip registration check since this is additional details for an already validated visitor
        await ref.read(firebaseServiceProvider).saveVisitorData(
              updatedVisitor,
              photoFile: _photoFile,
              documentFile: _documentFile,
              skipRegistrationCheck: true,
            );

        // Dismiss upload progress dialog if showing
        if (_photoFile != null || _documentFile != null) {
          Navigator.pop(context);
        }

        widget.onSubmitted?.call(updatedVisitor);

        if (mounted) {
          // Navigate to success screen
          Navigator.pushReplacement(
            context,
            RouteUtils.noAnimationRoute(
              VisitorSuccessScreen(
                visitor: updatedVisitor,
              ),
            ),
          );
        }
      } catch (e) {
        // Dismiss upload progress dialog if showing
        if (_photoFile != null || _documentFile != null) {
          Navigator.pop(context);
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText.rich(
                TextSpan(
                  text: 'Error saving visitor data: ',
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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = ResponsiveUtils.getHorizontalPadding(screenWidth);
    final isCabVisitor = widget.visitor.cabProvider != null;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding + 8, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Additional Details (Optional)',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please provide any additional information if available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                // Photo Upload Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                isCabVisitor ? 'Driver Photo' : 'Visitor Photo',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPhotoButton(
                                      icon: Icons.camera_alt_outlined,
                                      label: 'Take Photo',
                                      onPressed: _takePhoto,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildPhotoButton(
                                      icon: Icons.upload_file,
                                      label: 'Upload Photo',
                                      onPressed: _uploadPhoto,
                                    ),
                                  ),
                                ],
                              ),
                              if (_photoFile != null)
                                _buildPhotoPreview(_photoFile),
                            ],
                          ),
                        ),
                        if (_photoUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Photo uploaded successfully',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Add Document Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.document_scanner_outlined,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Identity Document',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedDocumentType,
                                decoration: InputDecoration(
                                  labelText: 'Document Type *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.document_scanner_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                items: documentTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type.value,
                                    child: Text(type.label),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) { // Add null check
                                    setState(() => _selectedDocumentType = value);
                                  }
                                },
                                validator: (value) =>
                                    value == null ? 'Please select a document type' : null,
                              ),
                              if (_selectedDocumentType != null) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPhotoButton(
                                        icon: Icons.camera_alt_outlined,
                                        label: 'Take Photo',
                                        onPressed: _takeDocumentPhoto,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildPhotoButton(
                                        icon: Icons.upload_file,
                                        label: 'Upload Document',
                                        onPressed: _uploadDocument,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_documentFile != null)
                                  _buildPhotoPreview(_documentFile),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Regular Fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildInputField(
                    controller: _emailController,
                    label: 'Email Address',
                    prefixIcon: Icons.email_outlined,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 24),
                if (!isCabVisitor) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildInputField(
                      controller: _emergencyNameController,
                      label: 'Emergency Contact Name',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildInputField(
                      controller: _emergencyContactController,
                      label: 'Emergency Contact Number',
                      prefixIcon: Icons.phone_outlined,
                      validator: _validateEmergencyContact,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (isCabVisitor) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildInputField(
                      controller: _vehicleController,
                      label: 'Vehicle Number',
                      prefixIcon: Icons.directions_car_outlined,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (!isCabVisitor) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.borderColor,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Number of Visitors',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCounterButton(
                                icon: Icons.remove,
                                onPressed: _numberOfVisitors > 1
                                    ? () => setState(() => _numberOfVisitors--)
                                    : null,
                              ),
                              Container(
                                width: 80,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  _numberOfVisitors.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _buildCounterButton(
                                icon: Icons.add,
                                onPressed: _numberOfVisitors < _maxVisitors
                                    ? () => setState(() => _numberOfVisitors++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Notification',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: _sendNotification,
                          onChanged: (bool? value) {
                            setState(() {
                              _sendNotification = value ?? false;
                            });
                          },
                          title: const Text('Send notification to host'),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppTheme.primaryColor,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_sendNotification) ...[
                          const SizedBox(height: 8),
                          Text(
                            'The host will be notified when the visitor arrives.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: onPressed == null
            ? Colors.grey[100]
            : AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color:
                  onPressed == null ? Colors.grey[400] : AppTheme.primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(
            prefixIcon,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.primaryColor),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 16,
        ),
        cursorColor: AppTheme.primaryColor,
        textCapitalization: textCapitalization,
      ),
    );
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        side: BorderSide(
          color: AppTheme.primaryColor,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(File? file) {
    if (file == null) return const SizedBox.shrink();

    final extension = file.path.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(extension);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Error loading image'),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.file_present),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (file == _photoFile) {
                        _photoFile = null;
                        _photoUrl = null;
                      } else {
                        _documentFile = null;
                        _documentUrl = null;
                      }
                    });
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
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
