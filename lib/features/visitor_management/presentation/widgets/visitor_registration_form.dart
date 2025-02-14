import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/route_utils.dart';
import '../../domain/models/visitor.dart';
import '../../domain/models/department_data.dart';
import '../providers/visitor_form_provider.dart';
import '../providers/firebase_provider.dart';
import '../screens/quick_checkin_screen.dart';
import '../widgets/visitor_additional_details_form.dart';
import '../../../../core/widgets/base_screen.dart';
import '../../../../core/utils/responsive_utils.dart';
import 'dart:io';
import './camera_screen.dart';
import 'package:file_picker/file_picker.dart';

class VisitorRegistrationForm extends ConsumerStatefulWidget {
  final void Function(Visitor visitor)? onSubmitted;

  const VisitorRegistrationForm({
    super.key,
    this.onSubmitted,
  });

  @override
  ConsumerState<VisitorRegistrationForm> createState() =>
      _VisitorRegistrationFormState();
}

class _VisitorRegistrationFormState
    extends ConsumerState<VisitorRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _purposeController = TextEditingController();
  String? _selectedDepartmentCode;
  String? _selectedStaffId;
  File? _photoFile;
  String? _photoUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter visitor name';
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter address';
    }
    return null;
  }

  String? _validateContact(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter contact number';
    }
    if (value.length != 10) {
      return 'Contact number must be 10 digits';
    }
    return null;
  }

  String? _validatePurpose(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter purpose of visit';
    }
    return null;
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Show loading indicator
        setState(() {
          _isLoading = true;
        });

        // Check if visitor is already registered
        final isRegistered = await ref
            .read(firebaseServiceProvider)
            .isVisitorRegistered(_contactController.text);

        if (isRegistered) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Show dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Already Registered'),
                content: const Text(
                    'This visitor is already registered. Please use Quick Check-in instead.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuickCheckInScreen(),
                        ),
                      );
                    },
                    child: const Text('Go to Quick Check-in'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
            return;
          }
        }

        final visitor = Visitor(
          name: _nameController.text,
          address: _addressController.text,
          contactNumber: _contactController.text,
          email: '',
          vehicleNumber: null,
          purposeOfVisit: _purposeController.text,
          numberOfVisitors: 1,
          whomToMeet: _selectedStaffId ?? '',
          department: _selectedDepartmentCode ?? '',
          documentType: documentTypes[0].value, // Set default document type
          entryTime: DateTime.now(),
        );

        Navigator.push(
          context,
          RouteUtils.noAnimationRoute(
            BaseScreen(
              title: 'Additional Details',
              showBackButton: true,
              body: SingleChildScrollView(
                child: VisitorAdditionalDetailsForm(
                  visitor: visitor,
                  onSubmitted: (updatedVisitor) {
                    ref
                        .read(visitorFormProvider.notifier)
                        .submitVisitor(updatedVisitor);
                    widget.onSubmitted?.call(updatedVisitor);
                  },
                ),
              ),
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _photoFile = File(result.files.single.path!);
          _photoUrl = result.files.single.path;
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

  Widget _buildFilePreview() {
    if (_photoFile == null) return const SizedBox.shrink();

    final extension = _photoFile!.path.split('.').last.toLowerCase();
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
                _photoFile!,
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
                      _photoFile!.path.split('/').last,
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
                      _photoFile = null;
                      _photoUrl = null;
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = ResponsiveUtils.getHorizontalPadding(screenWidth);

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visitor Registration',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill in the visitor details',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputField(
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _addressController,
                  label: 'Address',
                  prefixIcon: Icons.location_on_outlined,
                  validator: _validateAddress,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _contactController,
                  label: 'Contact Number',
                  prefixIcon: Icons.phone_outlined,
                  validator: _validateContact,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _purposeController,
                  label: 'Purpose of Visit',
                  prefixIcon: Icons.assignment_outlined,
                  validator: _validatePurpose,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDepartmentCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Department *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.business_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  menuMaxHeight: 300,
                  items: departments.map((department) {
                    return DropdownMenuItem(
                      value: department.value,
                      child: Text(
                        department.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartmentCode = value;
                      _selectedStaffId =
                          null; // Reset staff selection when department changes
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a department' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStaffId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Whom to Meet *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  menuMaxHeight: 300,
                  items: _selectedDepartmentCode == null
                      ? []
                      : departmentStaff[_selectedDepartmentCode]
                              ?.map((staff) => DropdownMenuItem(
                                    value: staff.value,
                                    child: Text(
                                      staff.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ))
                              .toList() ??
                          [],
                  onChanged: _selectedDepartmentCode == null
                      ? null
                      : (value) => setState(() => _selectedStaffId = value),
                  validator: (value) =>
                      value == null ? 'Please select whom to meet' : null,
                ),
                const SizedBox(height: 16),
                if (_photoFile != null) ...[
                  const SizedBox(height: 16),
                  _buildFilePreview(),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Next',
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
    int? maxLines,
    String? hintText,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
            minHeight: 56,
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              prefixIcon: Icon(
                prefixIcon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            validator: validator,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines ?? 1,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.primaryTextColor,
            ),
          ),
        );
      },
    );
  }
}
