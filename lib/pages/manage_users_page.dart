import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/account_model.dart';
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

  String role = 'parent';

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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
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

                    if (DummyData.usernameExists(username)) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('اسم المستخدم مستخدم مسبقًا'),
                        ),
                      );
                      return;
                    }

                    DummyData.addAccount(
                      AccountModel(
                        id: DummyData.newId('acc'),
                        username: username,
                        password: password,
                        role: role,
                        displayName: displayName,
                        email: email,
                        invitationVerified: true,
                      ),
                    );

                    setState(() {});
                    Navigator.pop(context);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة المستخدم بنجاح ✅'),
                      ),
                    );
                  },
                  child: const Text('إضافة'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void deleteUser(String id) {
    DummyData.accounts.removeWhere((a) => a.id == id);
    setState(() {});
  }

    @override
  Widget build(BuildContext context) {
    final users = DummyData.accounts;

    return AppPageScaffold(
      title: 'إدارة المستخدمين',
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: ListView(
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
          if (users.isEmpty)
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
            ...users.map(
              (u) => _UserCard(
                name: u.displayName,
                email: u.email ?? '',
                roleText: roleLabel(u.role),
                roleColor: roleColor(u.role),
                icon: roleIcon(u.role),
                username: u.username,
                onDelete: () => deleteUser(u.id),
              ),
            ),
        ],
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