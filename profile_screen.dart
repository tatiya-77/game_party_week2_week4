
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'private_chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onBack,
    this.userId,
  });

  final VoidCallback onBack;
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isPrivate = false;
  bool _isLoading = true;

  String _displayName = 'ผู้เล่น';
  String _email = '';
  String _bio = '';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  String? get _targetUid => widget.userId ?? _currentUid;

  bool get _isOwnProfile =>
      _currentUid != null && _currentUid == _targetUid;

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(_targetUid);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _targetUid;

    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final doc = await _userRef.get();
      final data = doc.data() ?? {};

      final authUser = _isOwnProfile
          ? FirebaseAuth.instance.currentUser
          : null;

      if (!mounted) return;

      setState(() {
        _displayName = (data['displayName'] ??
                authUser?.displayName ??
                'ผู้เล่น')
            .toString();

        _email = _isOwnProfile
            ? (data['email'] ?? authUser?.email ?? '').toString()
            : '';

        _bio = (data['bio'] ?? '').toString();
        _isPrivate = data['isPrivate'] == true;

        _nameController.text = _displayName;
        _bioController.text = _bio;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _displayName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'ผู้เล่น';
        _nameController.text = _displayName;
        _isLoading = false;
      });

      _showMessage('โหลดข้อมูลโปรไฟล์ได้ไม่ครบ', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !_isOwnProfile) return;

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.length < 2) {
      _showMessage('ชื่อที่แสดงต้องมีอย่างน้อย 2 ตัวอักษร',
          isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await user.updateDisplayName(name);

      await _userRef.set({
        'uid': user.uid,
        'displayName': name,
        'email': user.email ?? '',
        'bio': bio,
        'isPrivate': _isPrivate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _displayName = name;
        _bio = bio;
        _isEditing = false;
      });

      _showMessage('บันทึกโปรไฟล์เรียบร้อยแล้ว', isError: false);
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMessage('บันทึกไม่สำเร็จ (${e.code})', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('บันทึกโปรไฟล์ไม่สำเร็จ', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePrivacy(bool value) async {
    if (!_isOwnProfile) return;

    final oldValue = _isPrivate;
    setState(() => _isPrivate = value);

    try {
      await _userRef.set({
        'uid': _targetUid,
        'isPrivate': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showMessage(
          value ? 'ตั้งค่าโปรไฟล์ส่วนตัวแล้ว' : 'ตั้งค่าโปรไฟล์สาธารณะแล้ว',
          isError: false,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => _isPrivate = oldValue);
      _showMessage('เปลี่ยนการตั้งค่าไม่สำเร็จ', isError: true);
    }
  }

  Future<void> _toggleFollow(bool isFollowing) async {
    final currentUid = _currentUid;
    final targetUid = _targetUid;

    if (currentUid == null || targetUid == null) {
      _showMessage('กรุณาเข้าสู่ระบบก่อนติดตาม', isError: true);
      return;
    }

    if (currentUid == targetUid) return;

    final followerRef = _userRef
        .collection('followers')
        .doc(currentUid);

    final followingRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);

    try {
      final batch = _db.batch();

      if (isFollowing) {
        batch.delete(followerRef);
        batch.delete(followingRef);
      } else {
        batch.set(followerRef, {
          'uid': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.set(followingRef, {
          'uid': targetUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        _showMessage(
          isFollowing ? 'เลิกติดตามแล้ว' : 'ติดตามแล้ว',
          isError: false,
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMessage(
          'ดำเนินการไม่สำเร็จ (${e.code}) ตรวจสอบ Firestore Rules',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('ดำเนินการไม่สำเร็จ กรุณาลองใหม่', isError: true);
      }
    }
  }

  Future<void> _openPrivateChat() async {
    final uid = _targetUid;
    if (uid == null || _currentUid == null || uid == _currentUid) return;

    if (_isPrivate) {
      _showMessage(
        'โปรไฟล์นี้ตั้งค่าเป็นส่วนตัว อาจต้องได้รับอนุญาตก่อนติดต่อ',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          peerUid: uid,
          peerName: _displayName,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();

    if (mounted) widget.onBack();
  }

  Widget _countStream(String subcollection, String label) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userRef.collection(subcollection).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        );
      },
    );
  }

  Widget _followButton() {
    final currentUid = _currentUid;
    final targetUid = _targetUid;

    if (currentUid == null || targetUid == null || currentUid == targetUid) {
      return const SizedBox.shrink();
    }

    final followerRef = _userRef.collection('followers').doc(currentUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: followerRef.snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data?.exists ?? false;

        return SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: snapshot.connectionState == ConnectionState.waiting
                ? null
                : () => _toggleFollow(isFollowing),
            icon: Icon(
              isFollowing ? Icons.person_remove_alt_1 : Icons.person_add_alt_1,
            ),
            label: Text(isFollowing ? 'เลิกติดตาม' : 'ติดตาม'),
          ),
        );
      },
    );
  }

  Widget _buildPosts() {
    final uid = _targetUid;

    if (uid == null) {
      return const Center(child: Text('ไม่พบผู้ใช้'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'โหลดโพสต์ไม่สำเร็จ หากมีข้อความแจ้งสร้าง Index ให้สร้าง Index ใน Firebase Console',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('ผู้เล่นคนนี้ยังไม่มีโพสต์')),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final data = posts[index].data();
            final imageUrl = (data['imageUrl'] ?? '').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.sports_esports),
                    ),
                    title: Text(
                      (data['title'] ?? 'โพสต์').toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text((data['game'] ?? '').toString()),
                  ),
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    ),
                  if ((data['detail'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(data['detail'].toString()),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(_isOwnProfile ? 'โปรไฟล์ของฉัน' : 'โปรไฟล์ผู้เล่น'),
        actions: [
          if (_isOwnProfile && !_isEditing)
            IconButton(
              tooltip: 'แก้ไขโปรไฟล์',
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 43,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      size: 52,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isOwnProfile && _email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _isPrivate ? '🔒 โปรไฟล์ส่วนตัว' : '🌐 โปรไฟล์สาธารณะ',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _countStream('followers', 'ผู้ติดตาม'),
                      _countStream('following', 'กำลังติดตาม'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (!_isOwnProfile) ...[
              Row(
                children: [
                  Expanded(child: _followButton()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPrivateChat,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('แชต'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            if (_isOwnProfile && _isEditing)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อที่แสดง',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'เกี่ยวกับฉัน',
                          hintText: 'บอกคนอื่นเกี่ยวกับตัวคุณ',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        _nameController.text = _displayName;
                                        _bioController.text = _bio;
                                        _isEditing = false;
                                      });
                                    },
                              child: const Text('ยกเลิก'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              child: Text(
                                _isSaving ? 'กำลังบันทึก...' : 'บันทึก',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เกี่ยวกับฉัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _bio.isEmpty ? 'ยังไม่ได้เพิ่มข้อมูลเกี่ยวกับตัวเอง' : _bio,
                      ),
                    ],
                  ),
                ),
              ),

            if (_isOwnProfile) ...[
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  secondary: Icon(
                    _isPrivate ? Icons.lock_outline : Icons.public,
                    color: const Color(0xFF6C63FF),
                  ),
                  title: const Text(
                    'โปรไฟล์ส่วนตัว',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isPrivate
                        ? 'เปิดใช้งานโปรไฟล์ส่วนตัว'
                        : 'ผู้ใช้คนอื่นสามารถดูโปรไฟล์ได้',
                  ),
                  value: _isPrivate,
                  onChanged: _changePrivacy,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],

            const SizedBox(height: 18),
            const Text(
              'โพสต์ของผู้เล่น',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildPosts(),
          ],
        ),
      ),
    );
  }
}