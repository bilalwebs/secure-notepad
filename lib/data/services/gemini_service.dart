import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final GenerativeModel _model;
  bool _initialized = false;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final modelName =
        dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';

    if (apiKey.isEmpty || apiKey == 'paste_your_AIzaSy_key_here') {
      _initialized = false;
      return;
    }

    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _initialized = true;
  }

  bool get isReady => _initialized;

  Future<String> summarizeNote(String content) async {
    if (!_initialized) return _notConfiguredError();
    if (content.trim().isEmpty) return 'Note is empty.';
    return _generate(
      'Summarize the following note in 2-3 concise sentences. '
      'Return ONLY the summary, no preamble:\n\n$content',
    );
  }

  Future<String> fixGrammar(String content) async {
    if (!_initialized) return _notConfiguredError();
    if (content.trim().isEmpty) return 'Note is empty.';
    return _generate(
      'Fix all grammar, spelling, and punctuation errors in the '
      'following text. Return ONLY the corrected text:\n\n$content',
    );
  }

  Future<List<String>> generateTags(String content) async {
    if (!_initialized) return [];
    if (content.trim().isEmpty) return [];
    final result = await _generate(
      'Generate 3-5 relevant tags for this note. '
      'Return ONLY a comma-separated list, nothing else. '
      'Example: productivity, flutter, notes\n\n$content',
    );
    return result
        .split(',')
        .map((t) => t.trim().toLowerCase()
            .replaceAll(RegExp(r'[#\n\r]'), ''))
        .where((t) => t.isNotEmpty && t.length > 1)
        .take(5)
        .toList();
  }

  Future<String> expandIdea(String content) async {
    if (!_initialized) return _notConfiguredError();
    if (content.trim().isEmpty) return 'Note is empty.';
    return _generate(
      'Expand the following brief idea into a detailed, '
      'well-structured paragraph. Keep the original meaning '
      'but add context, examples, and detail:\n\n$content',
    );
  }

  Future<String> shortenNote(String content) async {
    if (!_initialized) return _notConfiguredError();
    if (content.trim().isEmpty) return 'Note is empty.';
    return _generate(
      'Shorten the following text to its essential points. '
      'Remove fluff, keep key information. '
      'Return ONLY the shortened version:\n\n$content',
    );
  }

  Stream<String> streamAction(String action, String content) async* {
    if (!_initialized) {
      yield _notConfiguredError();
      return;
    }
    final prompts = {
      'summarize':
          'Summarize in 2-3 sentences. Return only summary:\n\n$content',
      'grammar':
          'Fix grammar and spelling. Return corrected text only:\n\n$content',
      'expand':
          'Expand this idea into a detailed paragraph:\n\n$content',
      'shorten':
          'Shorten while keeping key points:\n\n$content',
    };
    final prompt = prompts[action] ?? prompts['summarize']!;
    yield* _generateStream(prompt);
  }

  Future<String> _generate(String prompt) async {
    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'No response generated.';
    } on GenerativeAIException catch (e) {
      return 'AI Error: ${e.message}';
    } catch (e) {
      return 'AI Error: $e';
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
    } on GenerativeAIException catch (e) {
      yield 'AI Error: ${e.message}';
    } catch (e) {
      yield 'AI Error: $e';
    }
  }

  String _notConfiguredError() =>
      'AI not configured. Add GEMINI_API_KEY to .env file.';
}
