import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
import '../services/local_database_service.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _postsRef = FirebaseFirestore.instance.collection('posts');

  int _currentPage = 0;
  String _lastCachedPostSignature = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // สร้างโพสต์
  // ============================================================

  Future<void> _createPost() async {
    final titleController = TextEditingController();
    final detailController = TextEditingController();

    String selectedGame = 'Valorant';
    String? imageUrl;
    bool isUploading = false;

    final isSuccess = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF6C63FF),
                  ),
                  SizedBox(width: 8),
                  Text('สร้างโพสต์หาปาร์ตี้'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedGame,
                      decoration: const InputDecoration(
                        labelText: 'เกม',
                        prefixIcon: Icon(
                          Icons.sports_esports_outlined,
                        ),
                      ),
                      items: const [
                        'Valorant',
                        'ROV',
                        'Minecraft',
                        'PUBG',
                        'Free Fire',
                        'Genshin Impact',
                        'อื่น ๆ',
                      ].map(
                        (game) {
                          return DropdownMenuItem<String>(
                            value: game,
                            child: Text(game),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedGame = value;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'หัวข้อ',
                        hintText: 'เช่น หาเพื่อนเล่น Valorant',
                        prefixIcon: Icon(
                          Icons.title_rounded,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: detailController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                        hintText:
                            'เช่น แรงค์ / เวลาเล่น / จำนวนคนที่ต้องการ',
                        prefixIcon: Icon(
                          Icons.description_outlined,
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // รูปภาพ
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          if (imageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return Container(
                                    height: 140,
                                    width: double.infinity,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextButton.icon(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    XFile? image;
                                    try {
                                      image = await ImagePicker().pickImage(
                                        source: ImageSource.gallery,
                                      );
                                    } catch (_) {
                                      if (mounted) {
                                        _showMessage('ไม่สามารถเปิดแกลเลอรีได้', isError: true);
                                      }
                                      return;
                                    }

                                    if (image == null) return;

                                    setDialogState(() {
                                      isUploading = true;
                                    });

                                    try {
                                      final uploadedUrl =
                                          await CloudinaryService
                                              .uploadImage(image);

                                      setDialogState(() {
                                        imageUrl = uploadedUrl;
                                        isUploading = false;
                                      });
                                      if (uploadedUrl == null && mounted) {
                                        _showMessage('อัปโหลดรูปไม่สำเร็จ กรุณาลองใหม่', isError: true);
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isUploading = false;
                                      });

                                      if (mounted) {
                                        _showMessage(
                                          'อัปโหลดรูปไม่สำเร็จ',
                                          isError: true,
                                        );
                                      }
                                    }
                                  },
                            icon: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_outlined,
                                  ),
                            label: Text(
                              isUploading
                                  ? 'กำลังอัปโหลด...'
                                  : imageUrl == null
                                      ? 'เพิ่มรูปภาพ'
                                      : 'เปลี่ยนรูปภาพ',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx, false);
                  },
                  child: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  onPressed: isUploading
                      ? null
                      : () {
                          if (titleController.text.trim().isEmpty) {
                            _showMessage(
                              'กรุณากรอกหัวข้อโพสต์',
                              isError: true,
                            );
                            return;
                          }

                          Navigator.pop(ctx, true);
                        },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('โพสต์'),
                ),
              ],
            );
          },
        );
      },
    );

    if (isSuccess == true &&
        titleController.text.trim().isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage('กรุณาเข้าสู่ระบบก่อนสร้างโพสต์', isError: true);
        titleController.dispose();
        detailController.dispose();
        return;
      }

      try {
        await _postsRef.add({
          'uid': user.uid,
          'userName': user.displayName ?? user.email ?? 'ผู้เล่น',
          'game': selectedGame,
          'title': titleController.text.trim(),
          'detail': detailController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': 0,
          'dislikes': 0,
          'likedBy': <String>[],
          'dislikedBy': <String>[],
          'reactions': <String, dynamic>{},
          'commentCount': 0,
        });
        _showMessage('สร้างโพสต์เรียบร้อยแล้ว', isError: false);
      } on FirebaseException catch (e) {
        _showMessage(_friendlyFirebaseError(e, 'สร้างโพสต์ไม่สำเร็จ'), isError: true);
      } catch (_) {
        _showMessage('เกิดข้อผิดพลาดระหว่างสร้างโพสต์ กรุณาลองใหม่', isError: true);
      }
    }

    titleController.dispose();
    detailController.dispose();
  }

  // ============================================================
  // Like
  // ============================================================

  Future<void> _toggleLike(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนกดถูกใจ', isError: true);
      return;
    }

    final data = doc.data() ?? {};

    final List<dynamic> likedBy =
        List<dynamic>.from(data['likedBy'] ?? []);

    final List<dynamic> dislikedBy =
        List<dynamic>.from(data['dislikedBy'] ?? []);

    final isLiked = likedBy.contains(user.uid);
    final isDisliked = dislikedBy.contains(user.uid);

    final updates = <String, dynamic>{};

    if (isLiked) {
      likedBy.remove(user.uid);

      updates['likes'] = FieldValue.increment(-1);
    } else {
      likedBy.add(user.uid);

      updates['likes'] = FieldValue.increment(1);

      if (isDisliked) {
        dislikedBy.remove(user.uid);

        updates['dislikes'] =
            FieldValue.increment(-1);
      }
    }

    updates['likedBy'] = likedBy;
    updates['dislikedBy'] = dislikedBy;

    try {
      await doc.reference.update(updates);
    } on FirebaseException catch (e) {
      _showMessage(_friendlyFirebaseError(e, 'กดถูกใจไม่สำเร็จ'), isError: true);
    } catch (_) {
      _showMessage('กดถูกใจไม่สำเร็จ กรุณาลองใหม่', isError: true);
    }
  }

  // ============================================================
  // Dislike
  // ============================================================

  Future<void> _toggleDislike(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนกดไม่ถูกใจ', isError: true);
      return;
    }

    final data = doc.data() ?? {};

    final List<dynamic> likedBy =
        List<dynamic>.from(data['likedBy'] ?? []);

    final List<dynamic> dislikedBy =
        List<dynamic>.from(data['dislikedBy'] ?? []);

    final isLiked = likedBy.contains(user.uid);
    final isDisliked = dislikedBy.contains(user.uid);

    final updates = <String, dynamic>{};

    if (isDisliked) {
      dislikedBy.remove(user.uid);

      updates['dislikes'] =
          FieldValue.increment(-1);
    } else {
      dislikedBy.add(user.uid);

      updates['dislikes'] =
          FieldValue.increment(1);

      if (isLiked) {
        likedBy.remove(user.uid);

        updates['likes'] =
            FieldValue.increment(-1);
      }
    }

    updates['likedBy'] = likedBy;
    updates['dislikedBy'] = dislikedBy;

    try {
      await doc.reference.update(updates);
    } on FirebaseException catch (e) {
      _showMessage(_friendlyFirebaseError(e, 'บันทึกการไม่ถูกใจไม่สำเร็จ'), isError: true);
    } catch (_) {
      _showMessage('บันทึกการไม่ถูกใจไม่สำเร็จ กรุณาลองใหม่', isError: true);
    }
  }

  // ============================================================
  // Emoji Reaction
  // ============================================================

  Future<void> _addReaction(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String emoji,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนส่ง Reaction', isError: true);
      return;
    }

    final data = doc.data() ?? {};

    final reactions = Map<String, dynamic>.from(
      data['reactions'] ?? {},
    );

    final currentCount =
        (reactions[emoji] ?? 0) as num;

    reactions[emoji] = currentCount + 1;

    try {
      await doc.reference.update({'reactions': reactions});
      _showMessage('บันทึก Reaction แล้ว', isError: false);
    } on FirebaseException catch (e) {
      _showMessage(_friendlyFirebaseError(e, 'บันทึก Reaction ไม่สำเร็จ'), isError: true);
    } catch (_) {
      _showMessage('บันทึก Reaction ไม่สำเร็จ กรุณาลองใหม่', isError: true);
    }
  }

  // ============================================================
  // แสดง Emoji
  // ============================================================

  void _showReactionPicker(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const emojis = [
          '❤️',
          '😂',
          '😮',
          '😢',
          '😡',
          '🔥',
          '🎮',
          '👏',
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 16,
            children: emojis.map((emoji) {
              return InkWell(
                onTap: () async {
                  Navigator.pop(context);

                  await _addReaction(doc, emoji);
                },
                borderRadius: BorderRadius.circular(20),
                child: Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 32,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ============================================================
  // Comment
  // ============================================================

  Future<void> _showComments(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final commentController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom,
          ),
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'ความคิดเห็น',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: doc.reference
                        .collection('comments')
                        .orderBy(
                          'createdAt',
                          descending: false,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'ไม่สามารถโหลดความคิดเห็นได้',
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child:
                              CircularProgressIndicator(),
                        );
                      }

                      final comments =
                          snapshot.data!.docs;

                      if (comments.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .chat_bubble_outline_rounded,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'ยังไม่มีความคิดเห็น',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding:
                            const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder:
                            (context, index) {
                          final comment =
                              comments[index].data();

                          return ListTile(
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 4,
                            ),
                            leading:
                                const CircleAvatar(
                              child: Icon(
                                Icons.person,
                              ),
                            ),
                            title: Text(
                              comment['userName'] ??
                                  'ผู้เล่น',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              comment['text'] ?? '',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              commentController,
                          textInputAction:
                              TextInputAction.send,
                          onSubmitted: (_) =>
                              _addComment(
                            doc,
                            commentController,
                          ),
                          decoration:
                              const InputDecoration(
                            hintText:
                                'เขียนความคิดเห็น...',
                            prefixIcon: Icon(
                              Icons
                                  .chat_bubble_outline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _addComment(
                          doc,
                          commentController,
                        ),
                        icon: const Icon(
                          Icons.send_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    commentController.dispose();
  }

  Future<void> _addComment(
    DocumentSnapshot<Map<String, dynamic>> doc,
    TextEditingController controller,
  ) async {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนแสดงความคิดเห็น', isError: true);
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final commentRef = doc.reference.collection('comments').doc();
      batch.set(commentRef, {
        'uid': user.uid,
        'userName': user.displayName ?? user.email ?? 'ผู้เล่น',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(doc.reference, {'commentCount': FieldValue.increment(1)});
      await batch.commit();
      controller.clear();
      _showMessage('เพิ่มความคิดเห็นแล้ว', isError: false);
    } on FirebaseException catch (e) {
      _showMessage(_friendlyFirebaseError(e, 'ส่งความคิดเห็นไม่สำเร็จ'), isError: true);
    } catch (_) {
      _showMessage('ส่งความคิดเห็นไม่สำเร็จ กรุณาลองใหม่', isError: true);
    }
  }

  // ============================================================
  // Edit Post
  // ============================================================

  Future<void> _editPost(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? {};

    final titleController = TextEditingController(
      text: data['title'] ?? '',
    );

    final detailController = TextEditingController(
      text: data['detail'] ?? '',
    );

    String selectedGame =
        data['game'] ?? 'Valorant';

    const games = [
      'Valorant',
      'ROV',
      'Minecraft',
      'PUBG',
      'Free Fire',
      'Genshin Impact',
      'อื่น ๆ',
    ];

    if (!games.contains(selectedGame)) {
      selectedGame = 'อื่น ๆ';
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('แก้ไขโพสต์'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedGame,
                      decoration: const InputDecoration(
                        labelText: 'เกม',
                      ),
                      items: games.map(
                        (game) {
                          return DropdownMenuItem<String>(
                            value: game,
                            child: Text(game),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedGame = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(
                        labelText: 'หัวข้อ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailController,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(
                        labelText: 'รายละเอียด',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title =
                        titleController.text.trim();

                    if (title.isEmpty) {
                      _showMessage(
                        'กรุณากรอกหัวข้อ',
                        isError: true,
                      );
                      return;
                    }

                    try {
                      await doc.reference.update({
                        'game': selectedGame,
                        'title': title,
                        'detail': detailController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
                      _showMessage('แก้ไขโพสต์เรียบร้อยแล้ว', isError: false);
                    } on FirebaseException catch (e) {
                      _showMessage(_friendlyFirebaseError(e, 'แก้ไขโพสต์ไม่สำเร็จ'), isError: true);
                    } catch (_) {
                      _showMessage('แก้ไขโพสต์ไม่สำเร็จ กรุณาลองใหม่', isError: true);
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    detailController.dispose();
  }

  // ============================================================
  // Delete Post
  // ============================================================

  Future<void> _deletePost(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ลบโพสต์?'),
          content: const Text(
            'คุณต้องการลบโพสต์นี้ใช่หรือไม่?\n'
            'การลบจะไม่สามารถย้อนกลับได้',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('ลบโพสต์'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await doc.reference.delete();
      _showMessage('ลบโพสต์เรียบร้อยแล้ว', isError: false);
    } on FirebaseException catch (e) {
      _showMessage(_friendlyFirebaseError(e, 'ลบโพสต์ไม่สำเร็จ'), isError: true);
    } catch (_) {
      _showMessage('ลบโพสต์ไม่สำเร็จ กรุณาลองใหม่', isError: true);
    }
  }

  // ============================================================
  // Report
  // ============================================================

  Future<void> _reportPost(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String selectedReason = 'เนื้อหาไม่เหมาะสม';

        const reasons = [
          'เนื้อหาไม่เหมาะสม',
          'สแปม',
          'โฆษณา',
          'การกลั่นแกล้ง',
          'อื่น ๆ',
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('รายงานโพสต์'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กรุณาเลือกเหตุผลที่ต้องการรายงาน',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: reasons.map(
                      (reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(
                      labelText: 'รายละเอียดเพิ่มเติม',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      selectedReason,
                    );
                  },
                  child: const Text('รายงาน'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      reasonController.dispose();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      reasonController.dispose();
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'postId': doc.id,
        'reportedBy': user.uid,
        'reason': result,
        'detail': reasonController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showMessage('ส่งรายงานเรียบร้อยแล้ว ขอบคุณสำหรับการแจ้งเตือน', isError: false);
    } on FirebaseException catch (e) {
      _showMessage(_friendlyFirebaseError(e, 'ส่งรายงานไม่สำเร็จ'), isError: true);
    } catch (_) {
      _showMessage('ส่งรายงานไม่สำเร็จ กรุณาลองใหม่', isError: true);
    } finally {
      reasonController.dispose();
    }
  }

  // ============================================================
  // Post Menu
  // ============================================================

  void _showPostMenu(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final user = FirebaseAuth.instance.currentUser;

    final data = doc.data() ?? {};

    final isOwner = user != null &&
        data['uid'] == user.uid;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                  ),
                  title: const Text('แก้ไขโพสต์'),
                  onTap: () {
                    Navigator.pop(context);
                    _editPost(doc);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'ลบโพสต์',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePost(doc);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                  ),
                  title: const Text('รายงานโพสต์'),
                  onTap: () {
                    Navigator.pop(context);
                    _reportPost(doc);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // Message
  // ============================================================

  String _friendlyFirebaseError(FirebaseException error, String fallback) {
    switch (error.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์ดำเนินการนี้';
      case 'unauthenticated':
        return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'เชื่อมต่อบริการไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
      case 'not-found':
        return 'ไม่พบข้อมูลนี้ อาจถูกลบไปแล้ว';
      case 'resource-exhausted':
        return 'ใช้งานบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
      default:
        return fallback;
    }
  }

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError
                ? Colors.red.shade700
                : Colors.green.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // -------------------------------
    // Chat
    // -------------------------------

    if (_currentPage == 1) {
      return ChatScreen(
        onBack: () {
          setState(() {
            _currentPage = 0;
          });
        },
      );
    }

    // -------------------------------
    // Profile
    // -------------------------------

    if (_currentPage == 2) {
      return ProfileScreen(
        onBack: () {
          setState(() {
            _currentPage = 0;
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.sports_esports_rounded,
              color: Color(0xFF6C63FF),
            ),
            SizedBox(width: 8),
            Text(
              'Game Party',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'แชท',
            onPressed: () {
              setState(() {
                _currentPage = 1;
              });
            },
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
            ),
          ),
          IconButton(
            tooltip: 'โปรไฟล์',
            onPressed: () {
              setState(() {
                _currentPage = 2;
              });
            },
            icon: const Icon(
              Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ========================================================
      // Body
      // ========================================================

      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              4,
              12,
              8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาเกมหรือโพสต์...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(
                              Icons.clear_rounded,
                            ),
                          ),
              ),
            ),
          ),

          // Feed
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _postsRef
                  .orderBy(
                    'createdAt',
                    descending: true,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 50,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ไม่สามารถโหลดโพสต์ได้',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองอีกครั้ง',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final allPosts = snapshot.data!.docs;

                // Keep a local SQLite copy of the latest feed for persistence.
                // Firestore remains the source of truth for post actions.
                final signature = allPosts
                    .map((doc) => '${doc.id}:${doc.data().toString()}')
                    .join('|');
                if (signature != _lastCachedPostSignature) {
                  _lastCachedPostSignature = signature;
                  LocalDatabaseService.instance.cachePosts(
                    allPosts
                        .map((doc) => {
                              'id': doc.id,
                              'data': doc.data(),
                            })
                        .toList(),
                  ).catchError((_) {
                    // A cache write failure must not break the live feed.
                  });
                }

                final query = _searchController.text
                    .toLowerCase()
                    .trim();

                final docs =
                    allPosts.where((doc) {
                  final data = doc.data();

                  final combinedText =
                      '${data['game'] ?? ''} '
                      '${data['title'] ?? ''} '
                      '${data['detail'] ?? ''} '
                      '${data['userName'] ?? ''}'
                          .toLowerCase();

                  return combinedText.contains(query);
                }).toList();

                if (docs.isEmpty) {
                  return _buildEmptyFeed();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    100,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildPostCard(
                      docs[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ========================================================
      // Create Post
      // ========================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _createPost,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'สร้างโพสต์',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Post Card
  // ============================================================

  Widget _buildPostCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    final user = FirebaseAuth.instance.currentUser;

    final List<dynamic> likedBy =
        List<dynamic>.from(data['likedBy'] ?? []);

    final List<dynamic> dislikedBy =
        List<dynamic>.from(data['dislikedBy'] ?? []);

    final isLiked =
        user != null && likedBy.contains(user.uid);

    final isDisliked =
        user != null &&
            dislikedBy.contains(user.uid);

    final likes = data['likes'] ?? 0;
    final dislikes = data['dislikes'] ?? 0;
    final comments = data['commentCount'] ?? 0;

    final imageUrl =
        data['imageUrl']?.toString() ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------
          // User Header
          // ---------------------------------------------

          ListTile(
            contentPadding:
                const EdgeInsets.fromLTRB(
              14,
              8,
              8,
              4,
            ),
            leading: CircleAvatar(
              backgroundColor:
                  const Color(0xFF6C63FF)
                      .withValues(alpha: 0.12),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xFF6C63FF),
              ),
            ),
            title: Text(
              data['userName'] ?? 'ผู้เล่น',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Row(
              children: [
                const Icon(
                  Icons.sports_esports_outlined,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  data['game'] ?? '',
                ),
              ],
            ),
            trailing: IconButton(
              tooltip: 'เพิ่มเติม',
              onPressed: () =>
                  _showPostMenu(doc),
              icon: const Icon(
                Icons.more_horiz_rounded,
              ),
            ),
          ),

          // ---------------------------------------------
          // Image
          // ---------------------------------------------

          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return Container(
                  height: 210,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),

          // ---------------------------------------------
          // Content
          // ---------------------------------------------

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              6,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if ((data['detail'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    data['detail'] ?? '',
                    style: const TextStyle(
                      height: 1.4,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // -----------------------------------------
                // Stats
                // -----------------------------------------

                Row(
                  children: [
                    Text(
                      '$likes ถูกใจ',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$dislikes ไม่ถูกใจ',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$comments ความคิดเห็น',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ---------------------------------------------
          // Action Buttons
          // ---------------------------------------------

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: 'ถูกใจ',
                    count: likes,
                    color: isLiked
                        ? Colors.red
                        : Colors.grey.shade700,
                    onPressed: () =>
                        _toggleLike(doc),
                  ),
                ),

                Expanded(
                  child: _ActionButton(
                    icon: isDisliked
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_outlined,
                    label: 'ไม่ถูกใจ',
                    count: dislikes,
                    color: isDisliked
                        ? Colors.orange
                        : Colors.grey.shade700,
                    onPressed: () =>
                        _toggleDislike(doc),
                  ),
                ),

                Expanded(
                  child: _ActionButton(
                    icon:
                        Icons.chat_bubble_outline_rounded,
                    label: 'ความคิดเห็น',
                    count: comments,
                    color: Colors.grey.shade700,
                    onPressed: () =>
                        _showComments(doc),
                  ),
                ),

                IconButton(
                  tooltip: 'Reaction',
                  onPressed: () =>
                      _showReactionPicker(doc),
                  icon: const Text(
                    '😊',
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------
          // Reaction summary
          // ---------------------------------------------

          _buildReactionSummary(data),
        ],
      ),
    );
  }

  // ============================================================
  // Reaction Summary
  // ============================================================

  Widget _buildReactionSummary(
    Map<String, dynamic> data,
  ) {
    final reactions = Map<String, dynamic>.from(
      data['reactions'] ?? {},
    );

    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = reactions.entries
        .where(
          (entry) => (entry.value ?? 0) > 0,
        )
        .toList();

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12,
      ),
      child: Wrap(
        spacing: 6,
        children: entries.map((entry) {
          return Chip(
            label: Text(
              '${entry.key} ${entry.value}',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
            visualDensity:
                VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // Empty Feed
  // ============================================================

  Widget _buildEmptyFeed() {
    final isSearching =
        _searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.forum_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              isSearching
                  ? 'ไม่พบโพสต์ที่ค้นหา'
                  : 'ยังไม่มีโพสต์',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'ลองค้นหาด้วยคำอื่น'
                  : 'มาเป็นคนแรกที่สร้างโพสต์กันเถอะ 🎮',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Action Button
// ============================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic count;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 10,
        ),
      ),
      icon: Icon(
        icon,
        size: 20,
      ),
      label: Flexible(
        child: Text(
          count == null
              ? label
              : '$label ${count == 0 ? '' : count}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}