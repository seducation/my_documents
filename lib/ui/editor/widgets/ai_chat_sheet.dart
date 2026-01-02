import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/ai_service.dart';
import '../../../providers/editor_provider.dart';
import '../../../models/note_model.dart';

class AIChatSheet extends StatefulWidget {
  const AIChatSheet({super.key});

  @override
  State<AIChatSheet> createState() => _AIChatSheetState();
}

class _AIChatSheetState extends State<AIChatSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<EditorProvider>();
    final userMsg = AIChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    provider.addAIChatMessage(userMsg);
    _controller.clear();
    setState(() {
      _isTyping = true;
    });

    // Actual AI API call
    _getAIResponse();
  }

  Future<void> _getAIResponse() async {
    final provider = context.read<EditorProvider>();
    final doc = provider.activeDocument;
    if (doc == null) return;

    final history = doc.chatHistory
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    try {
      final response = await AIService.getChatResponse(history);
      if (mounted) {
        final aiMsg = AIChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        );
        provider.addAIChatMessage(aiMsg);
        setState(() {
          _isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error connecting to AI service")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.select<EditorProvider, List<AIChatMessage>>((p) {
      return p.activeDocument?.chatHistory ?? [];
    });

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome,
                    color: Colors.purple.shade400, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "AI Assistant",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (_isTyping ? 1 : 0) + 1,
              itemBuilder: (context, index) {
                if (index == messages.length + (_isTyping ? 1 : 0)) {
                  // Insert Entire Chat Button
                  if (messages.length >= 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final fullChat = messages
                              .map((m) =>
                                  "${m.isUser ? 'User' : 'AI'}: ${m.text}")
                              .join("\n\n");
                          context.read<EditorProvider>().appendTextWithOverflow(
                              fullChat,
                              startNewPage: true);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add_to_photos),
                        label: const Text("Insert Entire Chat to Document"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade700,
                          side: BorderSide(color: Colors.purple.shade200),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }

                if (index == messages.length) {
                  return const TypingIndicator();
                }
                final msg = messages[index];
                return ChatBubble(message: msg);
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your request...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.purple.shade400,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final AIChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: message.isUser
                  ? Colors.purple.shade400
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isUser ? 16 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 16),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.copy,
                    label: "Copy",
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Text copied to clipboard"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.add_circle_outline,
                    label: "Insert",
                    onTap: () {
                      context.read<EditorProvider>().appendTextWithOverflow(
                          message.text,
                          startNewPage: true);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Text(
          "...",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
