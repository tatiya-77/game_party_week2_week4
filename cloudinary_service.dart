import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'ikevsyy7';
  static const String uploadPreset = 'game-party-202';

  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final bytes = await imageFile.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        url,
      )
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile.name,
          ),
        );

      final response = await request.send();

      final responseData = await response.stream.toBytes();
      final responseString = utf8.decode(responseData);

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(responseString);

        return jsonMap['secure_url'] as String?;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}