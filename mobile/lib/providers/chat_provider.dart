import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/app_provider.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool loading;

  const ChatState({
    this.messages = const [],
    this.loading = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  Future<void> ask(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || state.loading) return;

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: trimmed, fromUser: true)],
      loading: true,
    );

    try {
      final jobId = ref.read(selectedJobIdProvider);
      final res = await ref.read(chatRepositoryProvider).ask(
            trimmed,
            jobId: jobId,
          );
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            text: res.answer.isEmpty ? 'No answer returned.' : res.answer,
            fromUser: false,
            cites: res.cites,
          ),
        ],
        loading: false,
      );
      invalidateGlobalFeed(ref);
      await ref.read(feedProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            text: 'Could not reach the server.\n$e',
            fromUser: false,
            error: true,
          ),
        ],
        loading: false,
      );
    }
  }

  void clear() => state = const ChatState();
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
