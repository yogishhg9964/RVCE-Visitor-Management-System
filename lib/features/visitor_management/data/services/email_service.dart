import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/models/visitor.dart';
import '../../domain/models/department_data.dart';

class EmailService {
  static const String _serviceId = 'service_8bu9p0a';
  static const String _templateId = 'template_jb10x1i';
  static const String _userId = '_YTpty7L0DITVp5Bi';
  static const String _accessToken = 'YOUR_ACCESS_TOKEN';
  static const String _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';

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

  Future<bool> sendQrCodeEmail({
    required String toEmail,
    required String visitorName,
    required String qrCodeUrl,
    required Visitor visitor,
  }) async {
    try {
      final hostName = getHostNameFromEmail(visitor.whomToMeet);
      
      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _userId,
          'template_params': {
            'visitor_name': visitorName,
            'visitor_id': visitor.entryTime?.millisecondsSinceEpoch.toString().substring(5),
            'host_name': hostName,
            'department': visitor.department,
            'visitor_url': qrCodeUrl, // This maps to the template's {{visitor_url}}
            'to_email': toEmail,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Email sent successfully to $toEmail');
        return true;
      } else {
        print('Failed to send email: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}
