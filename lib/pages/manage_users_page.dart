import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/account_model.dart';
import '../widgets/app_bar_widget.dart';

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

  void openAddDialog() {
    displayNameCtrl.clear();
    usernameCtrl.clear();
    emailCtrl.clear();
    passwordCtrl.clear();
    role = 'parent';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'الإيميل'),
              ),
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'parent', child: Text('ولي أمر')),
                  DropdownMenuItem(value: 'nursery', child: Text('موظف/ة حضانة')),
                  DropdownMenuItem(value: 'teacher', child: Text('معلمة روضة')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير النظام')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'parent'),
                decoration: const InputDecoration(labelText: 'الدور'),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('املي كل الحقول')),
                );
                return;
              }

              if (DummyData.usernameExists(username)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اسم المستخدم مستخدم مسبقاً')),
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
            },
            child: const Text('إضافة'),
          ),
        ],
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        floatingActionButton: FloatingActionButton(
          onPressed: openAddDialog,
          backgroundColor: const Color(0xFF8E97FD),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final u = users[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF8E97FD),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${roleLabel(u.role)} • ${u.email ?? ""}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => deleteUser(u.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}