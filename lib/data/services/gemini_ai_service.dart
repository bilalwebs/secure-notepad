import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:secure_notepad/data/services/ai_service.dart';
import 'package:secure_notepad/data/services/groq_ai_service.dart';

class GeminiAIService implements AIService {
  late final GenerativeModel _model;
  bool _initialized = false;

  GeminiAIService() {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    final model = dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';
    if (key.isEmpty || key.contains('your_')) {
      _initialized = false;
      return;
    }
    _model = GenerativeModel(
      model: model,
      apiKey: key,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
      systemInstruction: Content.system(
        'You are a helpful AI assistant integrated into SecureNotepad, '
        'a private encrypted note-taking app. Help users understand, '
        'organize, and improve their notes. Be concise and practical. '
        'Never ask the user to share sensitive information.',
      ),
    );
    _initialized = true;
  }

  @override
  String get providerName => 'Gemini';

  @override
  bool get isReady => _initialized;

  @override
  Future<String> chat(
      List<ChatMessage> history, String newMessage) async {
    if (!_initialized) return _notReady();
    try {
      final contents = [
        ...history.map((m) => Content(m.role, [TextPart(m.content)])),
        Content('user', [TextPart(newMessage)]),
      ];
      final response = await _model.generateContent(contents);
      return response.text?.trim() ?? 'No response.';
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota') ||
          msg.contains('rate') ||
          msg.contains('limit') ||
          msg.contains('429')) {
        debugPrint('Gemini quota exceeded, falling back to Groq');
        try {
          final groq = GroqAIService();
          if (groq.isReady) return await groq.chat(history, newMessage);
        } catch (_) {}
        return 'AI is busy right now. Please wait a moment and retry.';
      }
      return 'AI Error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  @override
  Stream<String> chatStream(
      List<ChatMessage> history, String message) async* {
    if (!_initialized) {
      yield _notReady();
      return;
    }
    try {
      final contents = [
        ...history.map((m) => Content(m.role, [TextPart(m.content)])),
        Content('user', [TextPart(message)]),
      ];
      final stream = _model.generateContentStream(contents);
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) yield text;
      }
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota') ||
          msg.contains('rate') ||
          msg.contains('limit') ||
          msg.contains('429')) {
        debugPrint('Gemini quota exceeded, falling back to Groq stream');
        try {
          final groq = GroqAIService();
          if (groq.isReady) {
            yield* groq.chatStream(history, message);
            return;
          }
        } catch (_) {}
        yield 'AI quota exceeded. Please retry in a moment.';
        return;
      }
      yield 'AI Error: ${e.message}';
    } catch (e) {
      yield 'Error: $e';
    }
  }

  @override
  Future<String> summarize(String content) async {
    if (!_initialized) return _notReady();
    return _generate(
        'Summarize this note in 2-3 concise sentences. Return ONLY the summary:\n\n$content');
  }

  @override
  Stream<String> summarizeStream(String content) async* {
    if (!_initialized) {
      yield _notReady();
      return;
    }
    yield* _generateStream(
        'Summarize this note in 2-3 sentences:\n\n$content');
  }

  @override
  Future<String> fixGrammar(String text) async {
    if (!_initialized) return _notReady();
    return _generate(
        'Fix all grammar and spelling. Return ONLY corrected text:\n\n$text');
  }

  @override
  Future<String> expandIdea(String text) async {
    if (!_initialized) return _notReady();
    return _generate(
        'Expand this idea into a detailed paragraph:\n\n$text');
  }

  @override
  Future<String> shortenText(String text) async {
    if (!_initialized) return _notReady();
    return _generate(
        'Shorten while keeping all key points:\n\n$text');
  }

  @override
  Future<List<String>> generateTags(String text) async {
    if (!_initialized) return [];
    final result = await _generate(
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
    if (!_initialized) return _notReady();
    final notesList = notePreviews
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    return _generate(
        'Based on this query: "$query"\n\nWhich of these notes are most relevant? Return note numbers and brief reasons:\n\n$notesList');
  }

  Future<String> _generate(String prompt) async {
    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'No response.';
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota') ||
          msg.contains('rate') ||
          msg.contains('limit') ||
          msg.contains('429')) {
        debugPrint('Gemini quota exceeded, falling back to Groq');
        try {
          final groq = GroqAIService();
          if (groq.isReady) {
            return await groq.chat([], prompt);
          }
        } catch (_) {}
        return 'AI is busy right now. Please wait a moment and retry.';
      }
      return 'AI Error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Stream<String> _generateStream(String prompt) async* {
    try {
      final stream =
          _model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) yield text;
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  String _notReady() =>
      'AI not configured. Add GEMINI_API_KEY to .env file.';
}
