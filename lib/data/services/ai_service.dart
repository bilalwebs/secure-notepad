import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:secure_notepad/data/services/gemini_ai_service.dart';
import 'package:secure_notepad/data/services/groq_ai_service.dart';

/// A single message in a chat conversation.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'role': role,
        'content': content,
      };
}

/// Abstract AI service — Gemini and Groq both implement this.
abstract class AIService {
  Future<String> chat(List<ChatMessage> history, String newMessage);
  Future<String> summarize(String noteContent);
  Future<String> fixGrammar(String text);
  Future<String> expandIdea(String text);
  Future<String> shortenText(String text);
  Future<List<String>> generateTags(String text);
  Future<String> findRelevantNotes(String query, List<String> notePreviews);
  Stream<String> chatStream(List<ChatMessage> history, String message);
  Stream<String> summarizeStream(String noteContent);
  bool get isReady;
  String get providerName;
}

/// Factory that reads AI_PROVIDER from .env and creates the right service.
class AIServiceFactory {
  static AIService create() {
    final provider = dotenv.env['AI_PROVIDER'] ?? 'gemini';
    if (provider == 'groq') {
      return GroqAIService();
    }
    return GeminiAIService();
  }
}
