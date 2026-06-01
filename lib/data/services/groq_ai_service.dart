import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:secure_notepad/data/services/ai_service.dart';

class GroqAIService implements AIService {
  static const _baseUrl = 'https://api.groq.com/openai/v1';
  late final String _apiKey;
  late final String _model;
  bool _initialized = false;

  GroqAIService() {
    _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    _model = dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';
    _initialized = _apiKey.isNotEmpty && !_apiKey.contains('your_');
  }

  @override
  String get providerName => 'Groq (Llama)';

  @override
  bool get isReady => _initialized;

  static const String _systemPrompt =
      'You are a helpful AI assistant in SecureNotepad, '
      'a private encrypted note-taking app. '
      'Be concise, practical, and helpful.';

  @override
  Future<String> chat(
      List<ChatMessage> history, String newMessage) async {
    if (!_initialized) return _notReady();
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': newMessage},
    ];
    return _callGroq(messages);
  }

  @override
  Stream<String> chatStream(
      List<ChatMessage> history, String message) async* {
    if (!_initialized) {
      yield _notReady();
      return;
    }
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': message},
    ];
    yield* _callGroqStream(messages);
  }

  @override
  Future<String> summarize(String content) => _singleTurn(
      'Summarize in 2-3 sentences. Return ONLY summary:\n\n$content');

  @override
  Stream<String> summarizeStream(String content) =>
      _singleTurnStream('Summarize in 2-3 sentences:\n\n$content');

  @override
  Future<String> fixGrammar(String text) => _singleTurn(
      'Fix grammar and spelling. Return ONLY corrected text:\n\n$text');

  @override
  Future<String> expandIdea(String text) => _singleTurn(
      'Expand this idea into a detailed paragraph:\n\n$text');

  @override
  Future<String> shortenText(String text) => _singleTurn(
      'Shorten keeping all key points:\n\n$text');

  @override
  Future<List<String>> generateTags(String text) async {
    final result = await _singleTurn(
        'Generate 3-5 tags. Return ONLY comma-separated list:\n\n$text');
    return result
        .split(',')
        .map((t) =>
            t.trim().toLowerCase().replaceAll(RegExp(r'[#\n]'), ''))
        .where((t) => t.isNotEmpty && t.length > 1)
        .take(5)
        .toList();
  }

  @override
  Future<String> findRelevantNotes(
      String query, List<String> notePreviews) async {
    final list = notePreviews
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return _singleTurn(
        'Query: "$query"\nWhich notes are relevant? Give note numbers and brief reasons:\n\n$list');
  }

  Future<String> _singleTurn(String prompt) => _callGroq([
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': prompt},
      ]);

  Stream<String> _singleTurnStream(String prompt) =>
      _callGroqStream([
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': prompt},
      ]);

  Future<String> _callGroq(
      List<Map<String, dynamic>> messages) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.trim() ??
            'No response.';
      }
      return 'Groq Error: ${response.statusCode} ${response.body}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Stream<String> _callGroqStream(
      List<Map<String, dynamic>> messages) async* {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/completions'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': 1024,
        'temperature': 0.7,
        'stream': true,
      });
      final client = http.Client();
      final response = await client.send(request);
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ') && chunk != 'data: [DONE]') {
          try {
            final data = jsonDecode(chunk.substring(6));
            final content =
                data['choices']?[0]?['delta']?['content'];
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {}
        }
      }
      client.close();
    } catch (e) {
      yield 'Error: $e';
    }
  }

  String _notReady() =>
      'AI not configured. Add GROQ_API_KEY to .env file.';
}
