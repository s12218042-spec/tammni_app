import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final displayNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  String role = 'parent';
  bool isAdding = false;

  @override
  void dispose() {
    displayNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  String roleLabel(String r) {
    switch (r) {
      case 'parent':
        return 'ولي أمر';
      case 'nursery':
        return 'موظف/ة حضانة';
      case 'teacher':
        return 'معلمة روضة';
      default:
        return 'مدير النظام';
    }
  }

  Color roleColor(String r) {
    switch (r) {
      case 'parent':
        return Colors.teal;
      case 'nursery':
        return Colors.orange;
      case 'teacher':
        return Colors.indigo;
      default:
        return Colors.redAccent;
    }
  }

  IconData roleIcon(String r) {
    switch (r) {
      case 'parent':
        return Icons.family_restroom;
      case 'nursery':
        return Icons.child_friendly;
      case 'teacher':
        return Icons.school;
      default:
        return Icons.admin_panel_settings;
    }
  }

  bool isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  bool isValidPassword(String value) {
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    return value.length >= 8 && hasUpper && hasLower && hasNumber;
  }

  Future<bool> usernameExists(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void openAddDialog() {
    displayNameCtrl.clear();
    usernameCtrl.clear();
    emailCtrl.clear();
    passwordCtrl.clear();
    role = 'parent';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('إضافة مستخدم'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'الإيميل',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'الدور',
                        prefixIcon: Icon(Icons.assignment_ind_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'parent',
                          child: Text('ولي أمر'),
                        ),
                        DropdownMenuItem(
                          value: 'nursery',
                          child: Text('موظف/ة حضانة'),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text('معلمة روضة'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('مدير النظام'),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          role = v ?? 'parent';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          final displayName = displayNameCtrl.text.trim();
                          final username = usernameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final password = passwordCtrl.text.trim();

                          if (displayName.isEmpty ||
                              username.isEmpty ||
                              email.isEmpty ||
                              password.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('املئي جميع الحقول'),
                              ),
                            );
                            return;
                          }

                          if (!isValidEmail(email)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('الإيميل غير صالح'),
                              ),
                            );
                            return;
                          }

                          if (!isValidPassword(password)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي حرف كبير وحرف صغير ورقم',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isAdding = true;
                          });
                          setDialogState(() {});

                          try {
                            final exists = await usernameExists(username);

                            if (exists) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('اسم المستخدم مستخدم مسبقًا'),
                                ),
                              );
                              setState(() {
                                isAdding = false;
                              });
                              setDialogState(() {});
                              return;
                            }

                            final user = await _authService.register(
                              email: email,
                              password: password,
                            );

                            if (user == null) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('فشل إنشاء الحساب'),
                                ),
                              );
                              setState(() {
                                isAdding = false;
                              });
                              setDialogState(() {});
                              return;
                            }

                            await _firestore.collection('users').doc(user.uid).set({
                              'uid': user.uid,
                              'displayName': displayName,
                              'username': username,
                              'email': email,
                              'role': role,
                              'invitationVerified': true,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (!mounted) return;

                            Navigator.pop(context);

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة المستخدم بنجاح ✅'),
                              ),
                            );
                          } on FirebaseException catch (e) {
                            String message = 'حدث خطأ أثناء إنشاء المستخدم';

                            if (e.code == 'email-already-in-use') {
                              message = 'هذا الإيميل مستخدم مسبقًا';
                            } else if (e.code == 'invalid-email') {
                              message = 'الإيميل غير صالح';
                            } else if (e.code == 'weak-password') {
                              message = 'كلمة المرور ضعيفة';
                            }

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('حدث خطأ: $e')),
                            );
                          }

                          if (!mounted) return;

                          setState(() {
                            isAdding = false;
                          });
                          setDialogState(() {});
                        },
                  child: isAdding
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('إضافة'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة المستخدمين',
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            children: [
              Text(
                'إدارة الحسابات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'إضافة وحذف ومراجعة حسابات المستخدمين داخل النظام',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 20),
              if (docs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا يوجد مستخدمون حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...docs.map((doc) {
                  final u = doc.data();
                  final role = u['role'] ?? '';
                  return _UserCard(
                    name: u['displayName'] ?? '',
                    email: u['email'] ?? '',
                    roleText: roleLabel(role),
                    roleColor: roleColor(role),
                    icon: roleIcon(role),
                    username: u['username'] ?? '',
                    onDelete: () async {
                      await deleteUser(doc.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف المستخدم من النظام ✅'),
                        ),
                      );
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final String username;
  final String email;
  final String roleText;
  final Color roleColor;
  final IconData icon;
  final VoidCallback onDelete;

  const _UserCard({
    required this.name,
    required this.username,
    required this.email,
    required this.roleText,
    required this.roleColor,
    required this.icon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: roleColor.withOpacity(0.15),
              child: Icon(icon, color: roleColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اسم المستخدم: $username',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$roleText • $email',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'حذف المستخدم',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }
}