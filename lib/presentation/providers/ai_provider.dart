import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_notepad/data/services/ai_service.dart';

/// The active AI service (Gemini or Groq based on AI_PROVIDER in .env).
final aiServiceProvider = Provider<AIService>((ref) {
  return AIServiceFactory.create();
});

/// In-memory chat history for the AI chat screen.
final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
        (ref) => ChatHistoryNotifier());

class ChatHistoryNotifier extends StateNotifier<List<ChatMessage>> {
  ChatHistoryNotifier() : super([]);

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void addUserMessage(String content) {
    addMessage(ChatMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    ));
  }

  void addAssistantMessage(String content) {
    addMessage(ChatMessage(
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
    ));
  }

  void replaceAll(List<ChatMessage> messages) {
    state = messages;
  }

  void clearHistory() => state = [];

  /// Keep last 20 messages to avoid token overflow.
  List<ChatMessage> get trimmedHistory =>
      state.length > 20 ? state.sublist(state.length - 20) : state;
}
