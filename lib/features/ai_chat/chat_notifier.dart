import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? image;
  final bool isLoading;
  final bool hasAction;
  final Map<String, dynamic>? action;
  final bool actionExecuted;
  final List<Map<String, dynamic>> actions;
  final List<bool> actionsExecuted;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.image,
    this.isLoading = false,
    this.hasAction = false,
    this.action,
    this.actionExecuted = false,
    List<Map<String, dynamic>>? actions,
    List<bool>? actionsExecuted,
    DateTime? timestamp,
  })  : actions = actions ?? [],
        actionsExecuted = actionsExecuted ?? [],
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    bool? actionExecuted,
    List<bool>? actionsExecuted,
    List<Map<String, dynamic>>? actions,
    Map<String, dynamic>? action,
  }) =>
      ChatMessage(
        text: text,
        isUser: isUser,
        image: image,
        isLoading: isLoading,
        hasAction: hasAction,
        action: action ?? this.action,
        actionExecuted: actionExecuted ?? this.actionExecuted,
        actions: actions ?? this.actions,
        actionsExecuted: actionsExecuted ?? this.actionsExecuted,
        timestamp: timestamp,
      );
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier()
      : super([
          ChatMessage(
            text: 'Hey! 👋 I\'m your SpendSmart AI assistant. I can:\n\n'
                '💸 Add expenses — "movie 500" or "salary 50000"\n'
                '📸 Scan receipts — upload a bill photo\n'
                '📊 Spending insights — "how much on food?"\n'
                '💡 Financial tips — "am I overspending?"\n\n'
                'What would you like to do?',
            isUser: false,
          ),
        ]);

  void addUserMessage(String text, {Uint8List? image}) {
    state = [
      ...state,
      ChatMessage(text: text, isUser: true, image: image),
    ];
  }

  void addLoadingMessage() {
    state = [
      ...state,
      ChatMessage(text: '', isUser: false, isLoading: true),
    ];
  }

  void replaceLastWithResponse(
    String displayText,
    List<Map<String, dynamic>> actions,
  ) {
    final newState = List<ChatMessage>.from(state);
    if (newState.isNotEmpty && newState.last.isLoading) {
      newState.removeLast();
    }
    newState.add(ChatMessage(
      text: displayText,
      isUser: false,
      hasAction: actions.isNotEmpty,
      action: actions.isNotEmpty ? actions.first : null,
      actions: actions,
      actionsExecuted: List.filled(actions.length, false),
    ));
    state = newState;
  }

  void markActionExecuted(int messageIndex, int actionIndex) {
    final newState = List<ChatMessage>.from(state);
    if (messageIndex >= newState.length) return;
    final msg = newState[messageIndex];

    if (msg.actions.isNotEmpty) {
      if (actionIndex < 0 || actionIndex >= msg.actionsExecuted.length) return;
      final newExecuted = List<bool>.from(msg.actionsExecuted);
      newExecuted[actionIndex] = true;
      newState[messageIndex] = msg.copyWith(
        actionsExecuted: newExecuted,
        actionExecuted: newExecuted.every((e) => e),
      );
    } else {
      newState[messageIndex] = msg.copyWith(actionExecuted: true);
    }
    state = newState;
  }

  void updateAction(int messageIndex, int actionIndex, Map<String, dynamic> updatedAction) {
    final newState = List<ChatMessage>.from(state);
    if (messageIndex >= newState.length) return;
    final msg = newState[messageIndex];
    if (actionIndex >= msg.actions.length) return;

    final newActions = List<Map<String, dynamic>>.from(msg.actions);
    newActions[actionIndex] = updatedAction;
    newState[messageIndex] = msg.copyWith(
      actions: newActions,
      action: actionIndex == 0 ? updatedAction : null,
    );
    state = newState;
  }

  void markAllActionsExecuted(int messageIndex) {
    final newState = List<ChatMessage>.from(state);
    if (messageIndex >= newState.length) return;
    final msg = newState[messageIndex];
    newState[messageIndex] = msg.copyWith(
      actionsExecuted: List.filled(msg.actions.length, true),
      actionExecuted: true,
    );
    state = newState;
  }

  void clearChat() {
    state = [
      ChatMessage(
        text: 'Chat cleared! 🔄 How can I help you?',
        isUser: false,
      ),
    ];
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
        (_) => ChatNotifier());

final isSendingProvider = StateProvider<bool>((ref) => false);
