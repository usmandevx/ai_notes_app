import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:voice_task_app/core/constants/api_contants.dart';

class GeminiService {
  static String get _apiKey => dotenv.env[ApiConstants.apiKeyEnv] ?? '';
  static String get _apiUrl => dotenv.env[ApiConstants.apiUrlEnv] ?? '';
  static String get _systemTemplate =>
      dotenv.env[ApiConstants.systemTemplateEnv] ?? '';

  static Future<Map<String, dynamic>?> parseCommand(String userCommand) async {
    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": "$_systemTemplate\n\nUser: $userCommand"}
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse("$_apiUrl?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawText =
            decoded['candidates'][0]['content']['parts'][0]['text'] as String;

        final extractedJson = _extractJson(rawText);

        print("extractedJson: $extractedJson");
        if (extractedJson != null) {
          return jsonDecode(extractedJson);
        } else {
          print('Failed to extract JSON from Gemini output.');
        }
      } else {
        print('Gemini API error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error parsing Gemini response: $e');
    }

    return null;
  }

  static String? _extractJson(String text) {
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }

    return null;
  }
}
