import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    _nameController.text = user?.displayName ?? '';

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ============================================================
  // โหลดข้อมูล Profile จาก Firestore
  // ============================================================

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() ?? {};

        setState(() {
          _nameController.text =
              data['displayName'] ??
              user.displayName ??
              '';

          _bioController.text =
              data['bio'] ?? '';

          _isPrivate =
              data['isPrivate'] ?? false;
        });
      }
    } catch (_) {
      // หากโหลด Firestore ไม่สำเร็จ
      // ยังคงใช้ข้อมูลจาก Firebase Authentication ได้
    }
  }

  // ============================================================
  // บันทึก Profile
  // ============================================================

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'กรุณากรอกชื่อที่แสดง',
        isError: true,
      );
      return;
    }

    if (name.length < 2) {
      _showMessage(
        'ชื่อที่แสดงควรมีอย่างน้อย 2 ตัวอักษร',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Firebase Authentication
      await user.updateDisplayName(name);

      // Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'displayName': name,
          'email': user.email ?? '',
          'bio': bio,
          'isPrivate': _isPrivate,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _isEditing = false;
      });

      _showMessage(
        'บันทึกข้อมูลเรียบร้อยแล้ว',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'ไม่สามารถบันทึกข้อมูลได้',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // เปลี่ยน Public / Private
  // ============================================================

  Future<void> _changePrivacy(bool value) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _isPrivate = value;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'isPrivate': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      _showMessage(
        value
            ? 'เปลี่ยนโปรไฟล์เป็นส่วนตัวแล้ว'
            : 'เปลี่ยนโปรไฟล์เป็นสาธารณะแล้ว',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isPrivate = !value;
      });

      _showMessage(
        'ไม่สามารถเปลี่ยนการตั้งค่าได้',
        isError: true,
      );
    }
  }

  // ============================================================
  // Logout
  // ============================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ออกจากระบบ'),
          content: const Text(
            'คุณต้องการออกจากระบบใช่หรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('ออกจากระบบ'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
  }

  // ============================================================
  // Message
  // ============================================================

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
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
    final user = FirebaseAuth.instance.currentUser;

    final displayName =
        _nameController.text.trim().isEmpty
            ? 'ผู้เล่น'
            : _nameController.text.trim();

    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: 'แก้ไขโปรไฟล์',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(
                Icons.edit_outlined,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          40,
        ),
        child: Column(
          children: [
            // ==================================================
            // Profile Header
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFF8E7CFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 52,
                      color: Color(0xFF6C63FF),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.85,
                      ),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPrivate
                              ? Icons.lock_outline
                              : Icons.public,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPrivate
                              ? 'โปรไฟล์ส่วนตัว'
                              : 'โปรไฟล์สาธารณะ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // Edit Profile
            // ==================================================

            if (_isEditing)
              _buildEditProfileCard()
            else
              _buildProfileInfoCard(),

            const SizedBox(height: 14),

            // ==================================================
            // Privacy
            // ==================================================

            _buildPrivacyCard(),

            const SizedBox(height: 14),

            // ==================================================
            // Account
            // ==================================================

            _buildAccountCard(),

            const SizedBox(height: 20),

            // ==================================================
            // Logout
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed:
                    _isSaving ? null : _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(
                    color: Colors.red.shade200,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(
                  Icons.logout_rounded,
                ),
                label: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Profile Info Card
  // ============================================================

  Widget _buildProfileInfoCard() {
    final bio = _bioController.text.trim();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เกี่ยวกับฉัน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (bio.isEmpty)
              const Text(
                'ยังไม่ได้เพิ่มข้อมูลเกี่ยวกับตัวเอง',
                style: TextStyle(
                  color: Colors.grey,
                ),
              )
            else
              Text(
                bio,
                style: const TextStyle(
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 10),

            _InfoRow(
              icon: Icons.email_outlined,
              title: 'อีเมล',
              value:
                  FirebaseAuth.instance.currentUser?.email ??
                      '-',
            ),

            const SizedBox(height: 12),

            _InfoRow(
              icon: Icons.verified_user_outlined,
              title: 'สถานะ',
              value: 'สมาชิก Game Party',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Edit Profile Card
  // ============================================================

  Widget _buildEditProfileCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'แก้ไขโปรไฟล์',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อที่แสดง',
                prefixIcon: Icon(
                  Icons.person_outline,
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'เกี่ยวกับฉัน',
                hintText:
                    'เช่น ชอบเล่นเกมแนว FPS...',
                prefixIcon: Icon(
                  Icons.edit_note_rounded,
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _isEditing = false;
                            });
                          },
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                          ),
                    label: Text(
                      _isSaving
                          ? 'กำลังบันทึก...'
                          : 'บันทึก',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Privacy Card
  // ============================================================

  Widget _buildPrivacyCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 4,
        ),
        secondary: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _isPrivate
                ? Icons.lock_outline
                : Icons.public,
            color: const Color(0xFF6C63FF),
          ),
        ),
        title: const Text(
          'โปรไฟล์ส่วนตัว',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _isPrivate
              ? 'เฉพาะผู้ที่ได้รับอนุญาตเท่านั้น'
              : 'ผู้ใช้คนอื่นสามารถดูโปรไฟล์ได้',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        value: _isPrivate,
        onChanged:
            _isSaving ? null : _changePrivacy,
      ),
    );
  }

  // ============================================================
  // Account Card
  // ============================================================

  Widget _buildAccountCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(
          Icons.security_outlined,
        ),
        title: const Text(
          'บัญชีและความปลอดภัย',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'จัดการข้อมูลบัญชีของคุณ',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
        onTap: () {
          _showMessage(
            'ฟังก์ชันจัดการบัญชีเพิ่มเติมจะเพิ่มในขั้นต่อไป',
            isError: false,
          );
        },
      ),
    );
  }
}

// ============================================================
// Info Row
// ============================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 21,
          color: const Color(0xFF6C63FF),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}