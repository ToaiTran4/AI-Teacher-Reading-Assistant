import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/chat_controller.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Tự động cuộn xuống cuối khi mở màn hình chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
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

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    final chatController = context.read<ChatController>();
    await chatController.send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatController = context.watch<ChatController>();
    final selectedDoc = chatController.selectedDocument;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RAG Chat'),
            if (selectedDoc != null)
              Text(
                selectedDoc.fileName,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          if (chatController.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa lịch sử chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.surfaceColor,
                    title: Text(
                      'Xóa lịch sử',
                      style: AppTheme.h3,
                    ),
                    content: Text(
                      'Bạn có chắc muốn xóa toàn bộ lịch sử chat?',
                      style: AppTheme.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Hủy',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          chatController.clearMessages();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                        ),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (selectedDoc == null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppTheme.spacingMD),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXS),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Text(
                      'Chưa chọn tài liệu. Vào mục Documents để chọn PDF',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: chatController.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(height: AppTheme.spacingMD),
                        Text(
                          'Bắt đầu trò chuyện',
                          style: AppTheme.h3.copyWith(
                            color: AppTheme.textHint,
                          ),
                        ),
                        if (selectedDoc != null) ...[
                          const SizedBox(height: AppTheme.spacingSM),
                          Text(
                            'Hỏi về: ${selectedDoc.fileName}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    itemCount: chatController.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatController.messages[index];
                      final isUser = msg.role == "user";

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: EdgeInsets.only(
                          bottom: AppTheme.spacingMD,
                          left: isUser ? AppTheme.spacingLG : 0,
                          right: isUser ? 0 : AppTheme.spacingLG,
                        ),
                        child: Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMD,
                                vertical: AppTheme.spacingMD),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppTheme.userMessageBg
                                  : (msg.content.startsWith('[ERROR]')
                                      ? AppTheme.errorColor.withOpacity(0.15)
                                      : AppTheme.botMessageBg),
                              borderRadius: BorderRadius.only(
                                topLeft:
                                    const Radius.circular(AppTheme.radiusLG),
                                topRight:
                                    const Radius.circular(AppTheme.radiusLG),
                                bottomLeft: Radius.circular(isUser
                                    ? AppTheme.radiusLG
                                    : AppTheme.radiusSM),
                                bottomRight: Radius.circular(isUser
                                    ? AppTheme.radiusSM
                                    : AppTheme.radiusLG),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.content,
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: isUser
                                        ? AppTheme.userMessageText
                                        : (msg.content.startsWith('[ERROR]')
                                            ? AppTheme.errorColor
                                            : AppTheme.botMessageText),
                                  ),
                                ),
                                if (!isUser && msg.documentContext != null) ...[
                                  const SizedBox(height: AppTheme.spacingSM),
                                  const Divider(),
                                  Text(
                                    'Nguồn từ PDF',
                                    style: AppTheme.caption.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (chatController.isTyping)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Text(
                    'Đang trả lời...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMD,
              vertical: AppTheme.spacingMD,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusRound),
                        border: Border.all(
                          color: AppTheme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        decoration: InputDecoration(
                          hintText: 'Nhập câu hỏi...',
                          hintStyle: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textHint,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingLG,
                              vertical: AppTheme.spacingMD),
                        ),
                        style: AppTheme.bodyMedium,
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Material(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                      onTap: chatController.isTyping ? null : _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: chatController.isTyping
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.textOnPrimary),
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: AppTheme.textOnPrimary,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
