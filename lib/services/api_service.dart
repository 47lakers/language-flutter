import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple API client for your /generate_batch endpoint.
///
/// baseUrl should include scheme and host (e.g. http://10.0.0.115:8000 or http://10.0.2.2:8000).
class ApiService {
  final String baseUrl;
  final String appKey;
  final Duration timeout;

  ApiService({
    required this.baseUrl,
    required this.appKey,
    this.timeout = const Duration(seconds: 60),
  });

  Future<Map<String, dynamic>> generateBatch({
    required String targetLanguage,
    required String translationLanguage,
    required List<String> focusVerbs,
    required String level,
    required List<String> tenses,
    required int batchSize,
  }) async {
    final uri = Uri.parse('$baseUrl/generate_batch');
    final body = {
      "target_language": targetLanguage,
      "translation_language": translationLanguage,
      "focus_verbs": focusVerbs,
      "level": level,
      "tenses": tenses,
      "batch_size": batchSize,
    };

    final headers = {
      'content-type': 'application/json',
      'X-APP-KEY': appKey,
    };

    final resp = await http
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(timeout);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      // Explicitly decode as UTF-8 to handle special characters properly
      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return {"data": decoded};
    } else {
      // Ensure message is non-null by providing a fallback.
      final message = resp.body.isNotEmpty ? resp.body : (resp.reasonPhrase ?? 'Unknown error');
      throw ApiException(resp.statusCode, message);
    }
  }
}

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => 'ApiException($status): $message';
}