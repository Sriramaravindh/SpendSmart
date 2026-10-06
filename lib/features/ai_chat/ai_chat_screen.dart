import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/services/gemini_service.dart';
import '../../providers/providers.dart';
import 'chat_notifier.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      _speechAvailable = false;
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _controller.text.trim();
    if (text.isEmpty || ref.read(isSendingProvider)) return;

    _controller.clear();
    final notifier = ref.read(chatNotifierProvider.notifier);
    ref.read(isSendingProvider.notifier).state = true;
    notifier.addUserMessage(text);
    notifier.addLoadingMessage();
    _scrollToBottom();

    try {
      final response = await GeminiService.sendMessage(text);
      final actions = await GeminiService.parseActions(response);
      final displayText = GeminiService.removeActionBlock(response);

      notifier.replaceLastWithResponse(displayText, actions);
    } catch (e) {
      notifier.replaceLastWithResponse(
        'Sorry, something went wrong. Please try again.\n\n$e',
        const [],
      );
    } finally {
      if (mounted) ref.read(isSendingProvider.notifier).state = false;
      if (mounted) _scrollToBottom();
    }
  }

  Future<void> _sendImageMessage(Uint8List imageBytes, String mimeType) async {
    final notifier = ref.read(chatNotifierProvider.notifier);
    ref.read(isSendingProvider.notifier).state = true;
    notifier.addUserMessage('Sent an image', image: imageBytes);
    notifier.addLoadingMessage();
    _scrollToBottom();

    try {
      final response = await GeminiService.sendImageMessage(
        _controller.text.trim(),
        imageBytes,
        mimeType,
      );
      _controller.clear();

      final actions = await GeminiService.parseActions(response);
      final displayText = GeminiService.removeActionBlock(response);

      notifier.replaceLastWithResponse(displayText, actions);
    } catch (e) {
      notifier.replaceLastWithResponse(
        'Sorry, I could not process that image. Please try again.\n\n$e',
        const [],
      );
    } finally {
      if (mounted) ref.read(isSendingProvider.notifier).state = false;
      if (mounted) _scrollToBottom();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      await _sendImageMessage(bytes, mimeType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _executeAction(int messageIndex, [int actionIndex = 0]) async {
    final messages = ref.read(chatNotifierProvider);
    if (messageIndex >= messages.length) return;
    final msg = messages[messageIndex];
    final action = msg.actions.isNotEmpty ? msg.actions[actionIndex] : msg.action;
    if (action == null) return;
    if (msg.actions.isNotEmpty && msg.actionsExecuted[actionIndex]) return;
    if (msg.actions.isEmpty && msg.actionExecuted) return;

    final success = await GeminiService.executeAction(action);
    if (success) {
      refreshExpenses(ref);
      ref.read(chatNotifierProvider.notifier).markActionExecuted(messageIndex, actionIndex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Transaction added successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add transaction. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _executeAllActions(int messageIndex) async {
    final messages = ref.read(chatNotifierProvider);
    if (messageIndex >= messages.length) return;
    final msg = messages[messageIndex];
    if (msg.actions.isEmpty) return;

    int successCount = 0;
    int failCount = 0;
    final succeededIndices = <int>[];

    for (int i = 0; i < msg.actions.length; i++) {
      if (msg.actionsExecuted[i]) continue;
      final success = await GeminiService.executeAction(msg.actions[i]);
      if (success) {
        successCount++;
        succeededIndices.add(i);
      } else {
        failCount++;
      }
    }

    if (successCount > 0) {
      refreshExpenses(ref);
      final notifier = ref.read(chatNotifierProvider.notifier);
      if (failCount == 0) {
        notifier.markAllActionsExecuted(messageIndex);
      } else {
        for (final i in succeededIndices) {
          notifier.markActionExecuted(messageIndex, i);
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                failCount > 0 ? Icons.warning_rounded : Icons.done_all_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('$successCount transaction${successCount > 1 ? 's' : ''} added${failCount > 0 ? ', $failCount failed' : ''}'),
            ],
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
            if (_controller.text.trim().isNotEmpty) {
              _sendMessage();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    }
  }

  Future<void> _toggleSpeak(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      final cleaned = text
          .replaceAll(RegExp(r'[*#`]'), '')
          .replaceAll(RegExp(r'[•]'), ',')
          .replaceAll('₹', 'rupees ')
          .replaceAll(RegExp(r'[\U0001F300-\U0001F9FF]'), '');
      await _tts.speak(cleaned);
    }
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Upload Image', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Upload a receipt or bill to scan', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: Theme.of(ctx).colorScheme.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = ref.watch(chatNotifierProvider);
    final isSending = ref.watch(isSendingProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final catList = categoriesAsync.valueOrNull ?? [];
    final pmList = paymentMethodsAsync.valueOrNull ?? [];
    final tagList = tagsAsync.valueOrNull ?? [];
    final catMaps = catList.map((c) => {'id': c.id, 'name': c.name, 'type': c.type}).toList();
    final pmMaps = pmList.map((p) => {'id': p.id, 'name': p.name, 'type': p.type}).toList();
    final tagMaps = tagList.map((t) => {'id': t.id, 'name': t.name}).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  isSending ? 'Thinking...' : 'Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSending ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'New conversation',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('New Conversation?'),
                  content: const Text('This will clear the current chat history.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        GeminiService.resetChat();
                        ref.read(chatNotifierProvider.notifier).clearChat();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _QuickAction(label: 'Add Expense', icon: Icons.remove_circle_outline, onTap: () => _sendMessage('I want to add an expense'), color: colorScheme.error),
                    _QuickAction(label: 'Add Income', icon: Icons.add_circle_outline, onTap: () => _sendMessage('I want to add an income'), color: Colors.green),
                    _QuickAction(label: 'Monthly Summary', icon: Icons.calendar_month_outlined, onTap: () => _sendMessage('Give me a detailed summary of my spending this month with category breakdown'), color: colorScheme.primary),
                    _QuickAction(label: 'Scan Bill', icon: Icons.receipt_long_outlined, onTap: _showImageSourcePicker, color: Colors.orange),
                    _QuickAction(label: 'Top Spending', icon: Icons.trending_up_rounded, onTap: () => _sendMessage('What are my top spending categories this month? Any areas where I should cut back?'), color: Colors.red.shade400),
                    _QuickAction(label: 'Savings Tips', icon: Icons.lightbulb_outline, onTap: () => _sendMessage('Based on my spending patterns, give me practical tips to save money'), color: Colors.amber.shade700),
                    _QuickAction(label: 'Today\'s Spend', icon: Icons.today_rounded, onTap: () => _sendMessage('What did I spend today?'), color: Colors.teal),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outline.withOpacity(0.15)),

              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('Start a conversation!'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return _MessageBubble(
                            message: msg,
                            colorScheme: colorScheme,
                            isDark: isDark,
                            onExecuteAction: msg.hasAction && !msg.actionExecuted
                                ? () => _executeAction(index)
                                : null,
                            onExecuteActionAt: msg.actions.length > 1
                                ? (actionIdx) => _executeAction(index, actionIdx)
                                : null,
                            onExecuteAll: msg.actions.length > 1 && msg.actionsExecuted.any((e) => !e)
                                ? () => _executeAllActions(index)
                                : null,
                            onSpeak: !msg.isUser && !msg.isLoading
                                ? () => _toggleSpeak(msg.text)
                                : null,
                            onCopy: !msg.isUser && !msg.isLoading
                                ? () => _copyMessage(msg.text)
                                : null,
                            isSpeaking: _isSpeaking,
                            categories: catMaps,
                            paymentMethods: pmMaps,
                            tags: tagMaps,
                            onUpdateAction: msg.actions.isNotEmpty && msg.actionsExecuted.any((e) => !e)
                                ? (actionIdx, updated) {
                                    ref.read(chatNotifierProvider.notifier).updateAction(index, actionIdx, updated);
                                  }
                                : null,
                          );
                        },
                      ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.camera_alt_rounded, color: colorScheme.onSurfaceVariant),
                      onPressed: isSending ? null : _showImageSourcePicker,
                      tooltip: 'Upload image',
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: _isListening
                              ? Border.all(color: colorScheme.error, width: 2)
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  hintText: _isListening ? 'Listening...' : 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: _isListening ? colorScheme.error : null,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                maxLines: 4,
                                minLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _isListening ? colorScheme.error : colorScheme.onSurfaceVariant,
                              ),
                              onPressed: isSending ? null : _toggleListening,
                              tooltip: _isListening ? 'Stop listening' : 'Voice input',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isSending ? Icons.hourglass_top_rounded : Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: isSending ? null : () => _sendMessage(),
                        tooltip: 'Send',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_isListening)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.error.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Listening...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QuickAction({required this.label, required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 15, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        onPressed: onTap,
        side: BorderSide(color: color.withOpacity(0.25)),
        backgroundColor: color.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback? onExecuteAction;
  final void Function(int)? onExecuteActionAt;
  final VoidCallback? onExecuteAll;
  final VoidCallback? onSpeak;
  final VoidCallback? onCopy;
  final bool isSpeaking;
  final void Function(int actionIndex, Map<String, dynamic> updated)? onUpdateAction;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> paymentMethods;
  final List<Map<String, dynamic>> tags;

  const _MessageBubble({
    required this.message,
    required this.colorScheme,
    required this.isDark,
    this.onExecuteAction,
    this.onExecuteActionAt,
    this.onExecuteAll,
    this.onSpeak,
    this.onCopy,
    this.isSpeaking = false,
    this.onUpdateAction,
    this.categories = const [],
    this.paymentMethods = const [],
    this.tags = const [],
  });

  String _currencySymbol(String? code) {
    const map = {'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'AUD': 'A\$', 'CAD': 'C\$', 'CHF': 'CHF', 'SGD': 'S\$', 'AED': 'AED'};
    return map[code ?? 'INR'] ?? '₹';
  }

  Widget _buildReviewCard(BuildContext context, Map<String, dynamic> act, VoidCallback? onConfirm, int actionIndex) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.06),
            colorScheme.tertiary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.receipt_long, size: 16, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text('Review Transaction',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colorScheme.primary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (act['expenseType'] == 'INCOME' ? Colors.green : colorScheme.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  act['expenseType'] == 'INCOME' ? 'Income' : 'Expense',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: act['expenseType'] == 'INCOME' ? Colors.green : colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _editableRow(context, Icons.currency_rupee, 'Amount', '${_currencySymbol(act['currency'] as String?)}${act['amount']}', () {
            _showAmountEditor(context, act, actionIndex);
          }),
          _editableRow(context, Icons.category_outlined, 'Category', '${act['_categoryName'] ?? 'Unknown'}', () {
            _showCategoryPicker(context, act, actionIndex);
          }),
          _editableRow(context, Icons.payment_outlined, 'Payment', '${act['_paymentMethodName'] ?? 'Cash'}', () {
            _showPaymentPicker(context, act, actionIndex);
          }),
          _editableRow(context, Icons.note_outlined, 'Note', '${act['note'] ?? 'No note'}', () {
            _showNoteEditor(context, act, actionIndex);
          }),
          _editableRow(context, Icons.label_outline, 'Group', '${act['tag'] ?? 'None'}', () {
            _showTagPicker(context, act, actionIndex);
          }),
          _editableRow(context, Icons.calendar_today_outlined, 'Date', '${act['date'] ?? 'Today'}', () {
            _showDatePicker(context, act, actionIndex);
          }),
          _editableRow(context, Icons.currency_exchange, 'Currency', '${act['currency'] ?? 'INR'}', () {
            _showCurrencyPicker(context, act, actionIndex);
          }),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Confirm & Add', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableRow(BuildContext context, IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onUpdateAction != null ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            SizedBox(
              width: 70,
              child: Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (onUpdateAction != null)
              Icon(Icons.edit_outlined, size: 13, color: colorScheme.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showAmountEditor(BuildContext context, Map<String, dynamic> act, int actionIndex) {
    final controller = TextEditingController(text: '${act['amount']}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                final updated = Map<String, dynamic>.from(act);
                updated['amount'] = val;
                onUpdateAction?.call(actionIndex, updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNoteEditor(BuildContext context, Map<String, dynamic> act, int actionIndex) {
    final controller = TextEditingController(text: act['note'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final updated = Map<String, dynamic>.from(act);
              updated['note'] = controller.text.trim();
              onUpdateAction?.call(actionIndex, updated);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, Map<String, dynamic> act, int actionIndex) {
    if (categories.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = cat['id'] == act['categoryId'];
                  return ListTile(
                    leading: Icon(Icons.circle, size: 12, color: isSelected ? colorScheme.primary : Colors.grey),
                    title: Text(cat['name'] as String),
                    selected: isSelected,
                    onTap: () {
                      final updated = Map<String, dynamic>.from(act);
                      updated['categoryId'] = cat['id'];
                      updated['_categoryName'] = cat['name'];
                      onUpdateAction?.call(actionIndex, updated);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentPicker(BuildContext context, Map<String, dynamic> act, int actionIndex) {
    if (paymentMethods.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: paymentMethods.length,
                itemBuilder: (_, i) {
                  final pm = paymentMethods[i];
                  final isSelected = pm['id'] == act['paymentMethodId'];
                  return ListTile(
                    leading: Icon(Icons.circle, size: 12, color: isSelected ? colorScheme.primary : Colors.grey),
                    title: Text(pm['name'] as String),
                    subtitle: Text(pm['type'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onTap: () {
                      final updated = Map<String, dynamic>.from(act);
                      updated['paymentMethodId'] = pm['id'];
                      updated['_paymentMethodName'] = pm['name'];
                      onUpdateAction?.call(actionIndex, updated);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagPicker(BuildContext context, Map<String, dynamic> act, int actionIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Expense Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // "None" clears the tag.
                  ListTile(
                    leading: Icon(Icons.block, size: 16,
                        color: act['tag'] == null ? colorScheme.primary : Colors.grey),
                    title: const Text('None'),
                    selected: act['tag'] == null,
                    onTap: () {
                      final updated = Map<String, dynamic>.from(act);
                      updated.remove('tag');
                      onUpdateAction?.call(actionIndex, updated);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...tags.map((t) {
                    final name = t['name'] as String;
                    final isSelected = name == act['tag'];
                    return ListTile(
                      leading: Icon(Icons.label, size: 14,
                          color: isSelected ? colorScheme.primary : Colors.grey),
                      title: Text(name),
                      selected: isSelected,
                      onTap: () {
                        final updated = Map<String, dynamic>.from(act);
                        updated['tag'] = name;
                        onUpdateAction?.call(actionIndex, updated);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, Map<String, dynamic> act, int actionIndex) async {
    final now = DateTime.now();
    DateTime initial = now;
    try {
      final parts = (act['date'] as String?)?.split('-');
      if (parts != null && parts.length == 3) {
        initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      final updated = Map<String, dynamic>.from(act);
      updated['date'] = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      onUpdateAction?.call(actionIndex, updated);
    }
  }

  void _showCurrencyPicker(BuildContext context, Map<String, dynamic> act, int actionIndex) {
    const currencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'SGD', 'AED'];
    const labels = {'INR': '₹ Indian Rupee', 'USD': '\$ US Dollar', 'EUR': '€ Euro', 'GBP': '£ British Pound', 'JPY': '¥ Japanese Yen', 'AUD': 'A\$ Australian Dollar', 'CAD': 'C\$ Canadian Dollar', 'CHF': 'CHF Swiss Franc', 'SGD': 'S\$ Singapore Dollar', 'AED': 'AED UAE Dirham'};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Currency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ...currencies.map((c) => ListTile(
              leading: Icon(Icons.circle, size: 12, color: c == act['currency'] ? colorScheme.primary : Colors.grey),
              title: Text(labels[c] ?? c),
              selected: c == act['currency'],
              onTap: () {
                final updated = Map<String, dynamic>.from(act);
                updated['currency'] = c;
                onUpdateAction?.call(actionIndex, updated);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(String label) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 14, color: Colors.green.shade700),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text('Thinking...', style: TextStyle(color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    final isUser = message.isUser;
    final timeStr = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.image != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(message.image!, height: 160, width: 160, fit: BoxFit.cover),
                ),
              ),
            if (message.image != null) const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : (isDark ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLow),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? colorScheme.onPrimary.withOpacity(0.6) : colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Multiple actions — show individual review cards
            if (!isUser && message.actions.isNotEmpty)
              ...List.generate(message.actions.length, (i) {
                final act = message.actions[i];
                final executed = message.actionsExecuted[i];
                if (executed) {
                  final currency = act['currency'] as String? ?? 'INR';
                  final sym = currency == 'INR' ? '₹' : (currency == 'JPY' ? '¥' : (currency == 'USD' ? '\$' : currency));
                  return _buildSuccessCard('$sym${act['amount']} ${act['note'] ?? ''} added!');
                }
                return _buildReviewCard(
                  context,
                  act,
                  () => onExecuteActionAt != null ? onExecuteActionAt!(i) : onExecuteAction?.call(),
                  i,
                );
              }),

            // Confirm All button for multiple unexecuted actions
            if (!isUser && message.actions.length > 1 && message.actionsExecuted.any((e) => !e))
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onExecuteAll,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(
                    'Confirm All (${message.actionsExecuted.where((e) => !e).length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),

            // Single action fallback (when actions list is empty but action exists)
            if (!isUser && message.actions.isEmpty && message.hasAction && message.action != null && !message.actionExecuted)
              _buildReviewCard(context, message.action!, onExecuteAction, 0),

            if (!isUser && message.actions.isEmpty && message.hasAction && message.actionExecuted)
              _buildSuccessCard('Transaction added!'),

            // Action buttons (speak, copy)
            if (!isUser && !message.isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onSpeak != null)
                      _ActionIcon(
                        icon: isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                        onTap: onSpeak!,
                        color: isSpeaking ? colorScheme.error : colorScheme.onSurfaceVariant,
                      ),
                    if (onCopy != null) ...[
                      const SizedBox(width: 2),
                      _ActionIcon(
                        icon: Icons.copy_rounded,
                        onTap: onCopy!,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionIcon({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
