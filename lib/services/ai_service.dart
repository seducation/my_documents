import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIService {
  static const String _apiKey =
      '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';
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

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
          'model': 'deepseek/deepseek-chat',
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
