import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<String> askProfessor(String prompt) async {
    final url = Uri.parse('$baseUrl/ask');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error del servidor: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['response'] ?? 'Sin respuesta';
  }

  static Future<List<Map<String, dynamic>>> generateExam({
    required String transcript,
    String? customPrompt,
  }) async {
    final url = Uri.parse('$baseUrl/generate_exam');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transcript': transcript,
        'custom_prompt': customPrompt ?? '',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al generar el examen: ${response.body}');
    }

    final data = jsonDecode(response.body);

    final questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
    return questions;
  }
}