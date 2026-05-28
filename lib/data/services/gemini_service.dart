import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final modelName = dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );
  }

  /// Summarizes a note in 2-3 sentences.
  Future<String> summarizeNote(String content) async {
    final prompt =
        'Summarize the following note in 2-3 concise sentences:\n\n$content';
    return _generate(prompt);
  }

  /// Fixes grammar and spelling.
  Future<String> fixGrammar(String content) async {
    final prompt =
        'Fix all grammar and spelling errors in the following text. '
        'Return only the corrected text, no explanations:\n\n$content';
    return _generate(prompt);
  }

  /// Generates 3-5 relevant tags for the note.
  Future<List<String>> generateTags(String content) async {
    final prompt =
        'Generate 3-5 relevant tags for the following note. '
        'Return only the tags as a comma-separated list, no other text:\n\n$content';
    final result = await _generate(prompt);
    return result
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Expands a brief idea into a fuller note.
  Future<String> expandIdea(String idea) async {
    final prompt =
        'Expand the following brief idea into a well-developed paragraph. '
        'Keep the original meaning but add detail and context:\n\n$idea';
    return _generate(prompt);
  }

  /// Shortens a note while keeping key points.
  Future<String> shortenNote(String content) async {
    final prompt =
        'Shorten the following text while keeping all key points. '
        'Make it concise and to the point:\n\n$content';
    return _generate(prompt);
  }

  /// Streaming version for real-time output.
  Stream<String> summarizeNoteStream(String content) {
    final prompt =
        'Summarize the following note in 2-3 concise sentences:\n\n$content';
    return _generateStream(prompt);
  }

  Stream<String> fixGrammarStream(String content) {
    final prompt =
        'Fix all grammar and spelling errors in the following text. '
        'Return only the corrected text:\n\n$content';
    return _generateStream(prompt);
  }

  Stream<String> expandIdeaStream(String idea) {
    final prompt =
        'Expand the following brief idea into a well-developed paragraph:\n\n$idea';
    return _generateStream(prompt);
  }

  Stream<String> shortenNoteStream(String content) {
    final prompt =
        'Shorten the following text while keeping all key points:\n\n$content';
    return _generateStream(prompt);
  }

  Future<String> _generate(String prompt) async {
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'No response generated.';
    } catch (e) {
      return 'AI Error: $e';
    }
  }

  Stream<String> _generateStream(String prompt) async* {
    try {
      final response = _model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield 'AI Error: $e';
    }
  }
}
