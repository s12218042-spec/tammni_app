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

  String searchText = '';
  String selectedRole = 'all'; // all / teacher / nursery_staff

  Future<List<Map<String, dynamic>>> fetchAdminContacts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore.collection('users').get();

    final users = snapshot.docs
        .map((doc) {
          final data = doc.data();

          return {
            'docId': doc.id,
            'uid': (data['uid'] ?? doc.id).toString(),
            'name':
                (data['name'] ??
                        data['displayName'] ??
                        data['fullName'] ??
                        data['username'] ??
                        'مستخدم')
                    .toString(),
            'username': (data['username'] ?? '').toString(),
            'role': (data['role'] ?? '').toString().trim().toLowerCase(),
            'section': (data['section'] ?? '').toString(),
            'isActive': (data['isActive'] ?? true) == true,
          };
        })
        .where((user) {
          final uid = (user['uid'] ?? '').toString();
          final role = (user['role'] ?? '').toString();
          final name = (user['name'] ?? '').toString().toLowerCase();
          final username = (user['username'] ?? '').toString().toLowerCase();
          final isActive = user['isActive'] == true;

          if (!isActive) return false;
          if (uid == currentUser.uid) return false;

          // ✅ الأدمن يتواصل فقط مع المعلمات وموظفات الحضانة
          if (role != 'teacher' && role != 'nursery_staff') return false;

          if (selectedRole != 'all' && role != selectedRole) return false;

          final query = searchText.trim().toLowerCase();
          if (query.isNotEmpty &&
              !name.contains(query) &&
              !username.contains(query)) {
            return false;
          }

          return true;
        })
        .toList();

    users.sort((a, b) {
      final roleA = (a['role'] ?? '').toString();
      final roleB = (b['role'] ?? '').toString();

      // نخلي المعلمات أولًا ثم موظفات الحضانة
      if (roleA != roleB) {
        if (roleA == 'teacher') return -1;
        if (roleB == 'teacher') return 1;
      }

      final nameA = (a['name'] ?? '').toString();
      final nameB = (b['name'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return users;
  }

  String roleLabel(String role) {
    switch (role) {
      case 'teacher':
        return 'معلمة';
      case 'nursery_staff':
        return 'موظفة حضانة';
      default:
        return role;
    }
  }

  Color roleColor(String role) {
    switch (role) {
      case 'teacher':
        return Colors.blue;
      case 'nursery_staff':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData roleIcon(String role) {
    switch (role) {
      case 'teacher':
        return Icons.school_rounded;
      case 'nursery_staff':
        return Icons.child_care_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'ابحثي بالاسم أو اسم المستخدم...',
            prefixIcon: Icon(Icons.search),
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
            DropdownMenuItem(value: 'all', child: Text('الكل')),
            DropdownMenuItem(value: 'teacher', child: Text('المعلمات')),
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
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAdminContacts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل جهات الاتصال:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final users = snapshot.data ?? [];

              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد معلمات أو موظفات حضانة مطابقات حاليًا',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final uid = (user['uid'] ?? '').toString();
                  final name = (user['name'] ?? 'مستخدم').toString();
                  final role = (user['role'] ?? '').toString();
                  final section = (user['section'] ?? '').toString();
                  final username = (user['username'] ?? '').toString();

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: roleColor(role).withOpacity(0.12),
                        child: Icon(roleIcon(role), color: roleColor(role)),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${roleLabel(role)}'
                        '${section.isNotEmpty ? ' • $section' : ''}'
                        '${username.isNotEmpty ? '\n@$username' : ''}',
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessagesPage(
                              child: null,
                              targetRole: role,
                              targetUserId: uid,
                              targetUserName: name,
                              targetSection: section,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
