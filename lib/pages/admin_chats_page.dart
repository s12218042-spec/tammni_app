import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'messages_page.dart';

class AdminChatsPage extends StatefulWidget {
  const AdminChatsPage({super.key});

  @override
  State<AdminChatsPage> createState() => _AdminChatsPageState();
}

class _AdminChatsPageState extends State<AdminChatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController searchCtrl = TextEditingController();

  String searchText = '';
  String selectedRole = 'all';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String normalizeRole(dynamic value) {
    final role = (value ?? '').toString().trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    if (role == 'admin') return 'admin';
    if (role == 'parent') return 'parent';

    return role;
  }

  bool isNurseryRole(dynamic value) {
    return normalizeRole(value) == 'nursery_staff';
  }

  String cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = cleanText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> fetchAdminContacts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore.collection('users').get();
    final query = searchText.trim().toLowerCase();

    final users = snapshot.docs.map((doc) {
      final data = doc.data();
      final role = normalizeRole(data['role']);

      final name = firstNonEmpty([
        data['displayName'],
        data['name'],
        data['fullName'],
        data['username'],
        'مستخدم',
      ]);

      return {
        'docId': doc.id,
        'uid': firstNonEmpty([
          data['uid'],
          doc.id,
        ]),
        'name': name,
        'username': cleanText(data['username']),
        'email': cleanText(data['email']),
        'role': role,
        'section': cleanText(data['section']),
        'isActive': (data['isActive'] ?? true) == true,
      };
    }).where((user) {
      final uid = cleanText(user['uid']);
      final role = normalizeRole(user['role']);
      final name = cleanText(user['name']).toLowerCase();
      final username = cleanText(user['username']).toLowerCase();
      final email = cleanText(user['email']).toLowerCase();
      final isActive = user['isActive'] == true;

      if (!isActive) return false;
      if (uid == currentUser.uid) return false;

      // الأدمن يتواصل هنا مع موظفات الحضانة فقط
      if (!isNurseryRole(role)) return false;

      if (selectedRole != 'all' && role != selectedRole) return false;

      if (query.isNotEmpty &&
          !name.contains(query) &&
          !username.contains(query) &&
          !email.contains(query)) {
        return false;
      }

      return true;
    }).toList();

    users.sort((a, b) {
      final nameA = cleanText(a['name']);
      final nameB = cleanText(b['name']);
      return nameA.compareTo(nameB);
    });

    return users;
  }

  String roleLabel(String role) {
    switch (normalizeRole(role)) {
      case 'nursery_staff':
        return 'موظفة حضانة';
      case 'admin':
        return 'الإدارة';
      case 'parent':
        return 'ولي أمر';
      default:
        return role.trim().isEmpty ? 'مستخدم' : role;
    }
  }

  Color roleColor(String role) {
    switch (normalizeRole(role)) {
      case 'nursery_staff':
        return Colors.orange;
      case 'admin':
        return Colors.redAccent;
      case 'parent':
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }

  IconData roleIcon(String role) {
    switch (normalizeRole(role)) {
      case 'nursery_staff':
        return Icons.child_care_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'parent':
        return Icons.family_restroom_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Widget buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحثي بالاسم أو اسم المستخدم أو البريد...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchCtrl.clear();
                          setState(() {
                            searchText = '';
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'تصفية حسب الدور',
                prefixIcon: Icon(Icons.filter_list_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('الكل'),
                ),
                DropdownMenuItem(
                  value: 'nursery_staff',
                  child: Text('موظفات الحضانة'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value ?? 'all';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.10),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'لا توجد موظفات حضانة مطابقات حاليًا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'جرّبي تغيير البحث أو إزالة الفلتر.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildContactCard(Map<String, dynamic> user) {
    final uid = cleanText(user['uid']);
    final name = firstNonEmpty([
      user['name'],
      'مستخدم',
    ]);
    final role = normalizeRole(user['role']);
    final username = cleanText(user['username']);
    final email = cleanText(user['email']);
    final color = roleColor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(
            roleIcon(role),
            color: color,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              roleLabel(role),
              if (username.isNotEmpty) '@$username',
              if (email.isNotEmpty) email,
            ].join('\n'),
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 18,
          color: AppColors.textLight,
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesPage(
                child: null,
                targetRole: role,
                targetUserId: uid,
                targetUserName: name,
                targetSection: 'Nursery',
              ),
            ),
          );

          if (!mounted) return;
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildSearchCard(),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAdminContacts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل جهات الاتصال:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              final users = snapshot.data ?? [];

              if (users.isEmpty) {
                return buildEmptyState();
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  return buildContactCard(users[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}