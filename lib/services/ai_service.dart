import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIService {
  static const String _apiKey = 'sk-cfe7e57888544145adbd46f5aa5af6e2';
  static const String _baseUrl = 'https://api.deepseek.com/chat/completions';

  static Future<String> getChatResponse(
      List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': messages,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ??
            'No response from AI.';
      } else {
        debugPrint('AI Error: ${response.statusCode} - ${response.body}');
        return 'Error: Failed to connect to AI service. (Status: ${response.statusCode})';
      }
    } catch (e) {
      debugPrint('AI Exception: $e');
      return 'Error: Something went wrong while talking to the AI.';
    }
  }
}
