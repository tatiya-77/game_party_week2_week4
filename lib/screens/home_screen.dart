import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final titleController = TextEditingController();
    final detailController = TextEditingController();
    String selectedGame = 'Valorant';
    String? imageUrl;
    bool isUploading = false;

    final isSuccess = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('สร้างโพสต์หาปาร์ตี้'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedGame,
                  decoration: const InputDecoration(
                    labelText: 'เกม',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Valorant', 'ROV', 'Minecraft', 'PUBG', 'อื่น ๆ']
                      .map((game) => DropdownMenuItem(
                            value: game,
                            child: Text(game),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(
                    () => selectedGame = value ?? selectedGame,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'หัวข้อ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด / แรงค์ / เวลา',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image == null) return;

                          setDialogState(() => isUploading = true);

                          // อัปโหลดไป Cloudinary ผ่านบริการ CloudinaryService
                          final uploadedUrl =
                              await CloudinaryService.uploadImage(image);

                          setDialogState(() {
                            imageUrl = uploadedUrl;
                            isUploading = false;
                          });
                        },
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(
                    isUploading
                        ? 'กำลังอัปโหลด...'
                        : imageUrl == null
                            ? 'แนบรูป (ไม่บังคับ)'
                            : 'แนบรูปแล้ว',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('โพสต์'),
            ),
          ],
        ),
      ),
    );

    if (isSuccess == true && titleController.text.trim().isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser!;
      await _postsRef.add({
        'uid': user.uid,
        'userName': user.displayName ?? user.email ?? 'ผู้เล่น',
        'game': selectedGame,
        'title': titleController.text.trim(),
        'detail': detailController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });
    }

    titleController.dispose();
    detailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == 1) {
      return ChatScreen(onBack: () => setState(() => _currentPage = 0));
    }
    if (_currentPage == 2) {
      return ProfileScreen(onBack: () => setState(() => _currentPage = 0));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Party'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _currentPage = 1),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            onPressed: () => setState(() => _currentPage = 2),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาเกมหรือโพสต์...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _postsRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('ผิดพลาด: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final query = _searchController.text.toLowerCase().trim();
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final combinedText =
                      '${data['game']} ${data['title']} ${data['detail']}'
                          .toLowerCase();
                  return combinedText.contains(query);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีโพสต์ที่ตรงกับการค้นหา'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(data['userName'] ?? 'ผู้เล่น'),
                            subtitle: Text(data['game'] ?? ''),
                            trailing: IconButton(
                              onPressed: () =>
                                  setState(() => _currentPage = 1),
                              icon: const Icon(Icons.chat),
                            ),
                          ),
                          if (data['imageUrl'] != null &&
                              data['imageUrl'].toString().isNotEmpty)
                            Image.network(
                              data['imageUrl'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(data['detail'] ?? ''),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => doc.reference.update({
                                        'likes': FieldValue.increment(1),
                                      }),
                                      icon: const Icon(Icons.favorite_border),
                                    ),
                                    Text('${data['likes'] ?? 0}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPost,
        icon: const Icon(Icons.add),
        label: const Text('สร้างโพสต์'),
      ),
    );
  }
}