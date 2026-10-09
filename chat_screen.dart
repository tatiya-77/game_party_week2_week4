import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messagesRef = FirebaseFirestore.instance.collection('messages');

  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // แปลง Firebase error เป็นข้อความภาษาไทยที่เข้าใจง่าย
  String _getErrorMessage(Object error, {String action = 'ดำเนินการ'}) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'คุณไม่มีสิทธิ์ในการดำเนินการนี้';
        case 'unauthenticated':
          return 'กรุณาเข้าสู่ระบบใหม่อีกครั้ง';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
        case 'not-found':
          return 'ไม่พบข้อมูลที่ต้องการ';
        case 'resource-exhausted':
          return 'มีการใช้งานระบบมากเกินไป กรุณาลองใหม่ภายหลัง';
        case 'cancelled':
          return 'การดำเนินการถูกยกเลิก';
        case 'failed-precondition':
          return 'ระบบยังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง';
        default:
          return 'ไม่สามารถ$actionได้ กรุณาลองใหม่อีกครั้ง';
      }
    }

    return 'เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่อีกครั้ง';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ส่งข้อความ
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนส่งข้อความ');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _messagesRef.add({
        'uid': user.uid,
        'name': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email ?? 'ผู้เล่น',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _controller.clear();

      // เลื่อนไปยังข้อความล่าสุด
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || !_scrollController.hasClients) return;

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } on FirebaseException catch (e) {
      _showMessage(_getErrorMessage(e, action: 'ส่งข้อความ'));
    } catch (e) {
      _showMessage('ส่งข้อความไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // แปลงเวลา
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute น.';
  }

  // ลบข้อความ
  Future<void> _deleteMessage(String messageId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบใหม่อีกครั้ง');
      return;
    }

    try {
      // ตรวจสอบว่าเป็นข้อความของผู้ใช้ปัจจุบัน
      final doc = await _messagesRef.doc(messageId).get();

      if (!doc.exists) {
        _showMessage('ไม่พบข้อความนี้ อาจถูกลบไปแล้ว');
        return;
      }

      final data = doc.data();

      if (data == null || data['uid'] != user.uid) {
        _showMessage('คุณไม่มีสิทธิ์ลบข้อความนี้');
        return;
      }

      await _messagesRef.doc(messageId).delete();

      _showMessage('ลบข้อความแล้ว');
    } on FirebaseException catch (e) {
      _showMessage(_getErrorMessage(e, action: 'ลบข้อความ'));
    } catch (e) {
      _showMessage('ลบข้อความไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  // เมนูข้อความ
  void _showMessageMenu(
    BuildContext context,
    String messageId,
    bool isMine,
  ) {
    if (!isMine) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            title: const Text('ลบข้อความ'),
            onTap: () async {
              Navigator.pop(sheetContext);

              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('ลบข้อความ'),
                    content: const Text(
                      'คุณต้องการลบข้อความนี้หรือไม่?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, false);
                        },
                        child: const Text('ยกเลิก'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text('ลบ'),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                await _deleteMessage(messageId);
              }
            },
          ),
        );
      },
    );
  }

  // กล่องข้อความ
  Widget _buildMessageBubble(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String? currentUid,
  ) {
    final data = doc.data();

    final String uid = data['uid']?.toString() ?? '';
    final String name = data['name']?.toString() ?? 'ผู้เล่น';
    final String text = data['text']?.toString() ?? '';

    final timestamp = data['createdAt'];
    final Timestamp? createdAt =
        timestamp is Timestamp ? timestamp : null;

    final bool isMine = uid == currentUid;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          _showMessageMenu(
            context,
            doc.id,
            isMine,
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              Text(
                text,
                style: TextStyle(
                  color: isMine
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? colorScheme.onPrimary.withValues(alpha: 0.75)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // หน้าจอเมื่อไม่มีข้อความ
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 42,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ยังไม่มีข้อความ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'เริ่มพูดคุยกับเพื่อน ๆ ในชุมชนได้เลย',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ช่องพิมพ์ข้อความ
  Widget _buildInputArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, -3),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: colorScheme.onPrimary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_rounded,
                color: colorScheme.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'แชทชุมชน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'พูดคุยกับเพื่อน ๆ',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef.orderBy('createdAt').snapshots(),
              builder: (context, snapshot) {
                // จัดการ Error ตอนโหลดข้อความ
                if (snapshot.hasError) {
                  final errorMessage = _getErrorMessage(
                    snapshot.error!,
                    action: 'โหลดข้อความ',
                  );

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 52,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ไม่สามารถโหลดข้อความได้',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองอีกครั้ง'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(
                      context,
                      docs[index],
                      currentUid,
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }
}