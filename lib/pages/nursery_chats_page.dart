import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'messages_page.dart';
import 'temporary_staff_chat_page.dart';

class NurseryChatsPage extends StatefulWidget {
  final List<ChildModel> children;

  const NurseryChatsPage({
    super.key,
    required this.children,
  });

  @override
  State<NurseryChatsPage> createState() => _NurseryChatsPageState();
}

class _NurseryChatsPageState extends State<NurseryChatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessageService _messageService = MessageService();
  final TextEditingController searchCtrl = TextEditingController();

  Future<Map<String, dynamic>?>? _adminFuture;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  List<ChildModel> get activeChildren {
    return widget.children.where((child) => child.isActiveChild).toList();
  }

  List<ChildModel> get temporaryChildren {
    return activeChildren.where((child) {
      return child.isTemporaryChild || child.isTrialChild;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _adminFuture = _fetchAdminContact();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    switch (value) {
      case 'nursery':
      case 'nursery_staff':
      case 'nursery staff':
      case 'staff':
      case 'employee':
      case 'teacher':
      case 'موظفة':
      case 'موظفة حضانة':
      case 'حضانة':
        return 'nursery_staff';

      case 'admin':
      case 'manager':
      case 'مدير':
      case 'مدير النظام':
      case 'ادمن':
      case 'أدمن':
        return 'admin';

      case 'parent':
      case 'ولي امر':
      case 'ولي أمر':
      case 'ولي الامر':
      case 'ولي الأمر':
        return 'parent';

      default:
        return value;
    }
  }

  String _roleLabel(String role) {
    switch (_normalizeRole(role)) {
      case 'admin':
        return 'الإدارة';

      case 'parent':
        return 'ولي الأمر';

      case 'temporary_parent':
        return 'ولي أمر مؤقت';

      default:
        return role.trim().isEmpty ? 'مستخدم' : role.trim();
    }
  }

  String _firstLetter(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) return 'و';

    return cleanName.substring(0, 1);
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (sameDay) {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);

      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'م' : 'ص';

      return '$hour:$minute $period';
    }

    return '${date.day}/${date.month}';
  }

  Timestamp? _timestampFromDynamic(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);

    return null;
  }

  Future<Map<String, dynamic>?> _fetchAdminContact() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;

      return {
        'key': 'admin_chat',
        'kind': 'admin',
        'id': doc.id,
        'name': 'الإدارة',
        'role': 'admin',
        'subtitle': 'الإدارة',
      };
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _buildParentContacts() {
    final contacts = <Map<String, dynamic>>[];
    final formalKeys = <String>{};
    final temporaryKeys = <String>{};

    for (final child in activeChildren) {
      final isTemporary = child.isTemporaryChild || child.isTrialChild;

      if (isTemporary) {
        final key = 'temporary_${child.id}';

        if (!temporaryKeys.add(key)) continue;

        final parentName = child.parentName.trim().isEmpty
            ? 'ولي أمر مؤقت'
            : child.parentName.trim();

        contacts.add({
          'key': key,
          'kind': 'temporary_parent',
          'id': child.id,
          'name': parentName,
          'role': 'temporary_parent',
          'subtitle': child.isTrialChild ? 'ولي أمر طفل تجربة' : 'ولي أمر مؤقت',
          'child': child,
        });

        continue;
      }

      final parentUid = child.parentUid.trim();
      final parentUsername = child.parentUsername.trim().toLowerCase();

      final fallbackKey = parentUsername.isNotEmpty
          ? parentUsername
          : child.parentName.trim().toLowerCase();

      final uniqueKey =
          parentUid.isNotEmpty ? 'parent_$parentUid' : 'parent_$fallbackKey';

      if (uniqueKey == 'parent_' || !formalKeys.add(uniqueKey)) {
        continue;
      }

      final parentName = child.parentName.trim().isEmpty
          ? 'ولي الأمر'
          : child.parentName.trim();

      contacts.add({
        'key': uniqueKey,
        'kind': 'parent',
        'id': parentUid,
        'username': parentUsername,
        'name': parentName,
        'role': 'parent',
        'subtitle': 'ولي الأمر',
        'child': child,
      });
    }

    return contacts;
  }

  Future<String> _resolveOfficialParentUid(
    Map<String, dynamic> contact,
  ) async {
    final currentUid = _clean(contact['id']);

    if (currentUid.isNotEmpty) {
      return currentUid;
    }

    final username = _clean(contact['username']).toLowerCase();

    if (username.isEmpty) {
      return '';
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return '';

      return snapshot.docs.first.id;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> _loadTemporaryAccessData(
    ChildModel child,
  ) async {
    String accessCodeId = '';
    String accessCode = '';

    try {
      final childDoc =
          await _firestore.collection('children').doc(child.id).get();

      final data = childDoc.data() ?? <String, dynamic>{};

      accessCodeId = _clean(
        data['temporaryAccessCodeId'] ?? data['accessCodeId'],
      );

      accessCode = _clean(
        data['temporaryAccessCode'] ?? data['accessCode'] ?? data['code'],
      );
    } catch (_) {}

    if (accessCodeId.isEmpty || accessCode.isEmpty) {
      try {
        final snapshot = await _firestore
            .collection('temporary_access_codes')
            .where('childId', isEqualTo: child.id)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data();

          accessCodeId = accessCodeId.isEmpty ? doc.id : accessCodeId;
          accessCode =
              accessCode.isEmpty ? _clean(data['code']) : accessCode;
        }
      } catch (_) {}
    }

    return {
      'accessCodeId': accessCodeId,
      'accessCode': accessCode,
    };
  }

  Future<void> _openContact(Map<String, dynamic> contact) async {
    final kind = _clean(contact['kind']);

    if (kind == 'admin') {
      final adminUid = _clean(contact['id']);

      if (adminUid.isEmpty) {
        _showMessage('تعذر العثور على حساب الإدارة');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessagesPage(
            child: null,
            targetRole: 'admin',
            targetUserId: adminUid,
            targetUserName: 'الإدارة',
            targetSection: 'Nursery',
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});

      return;
    }

    if (kind == 'parent') {
      final child = contact['child'] as ChildModel?;
      final parentUid = await _resolveOfficialParentUid(contact);

      if (!mounted) return;

      if (child == null || parentUid.isEmpty) {
        _showMessage('تعذر العثور على حساب ولي الأمر');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessagesPage(
            child: child,
            targetRole: 'parent',
            targetUserId: parentUid,
            targetUserName: _clean(contact['name']).isEmpty
                ? 'ولي الأمر'
                : _clean(contact['name']),
            targetSection: 'Nursery',
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});

      return;
    }

    if (kind == 'temporary_parent') {
      final child = contact['child'] as ChildModel?;

      if (child == null) {
        _showMessage('تعذر تحميل بيانات الطفل');
        return;
      }

      final access = await _loadTemporaryAccessData(child);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TemporaryStaffChatPage(
            accessCodeId: _clean(access['accessCodeId']),
            accessCode: _clean(access['accessCode']),
            childId: child.id,
            childName: child.name,
            parentName: child.parentName,
            parentPhone: '',
            groupId: child.groupId,
            groupName: child.displayGroup,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Map<String, MessageModel> _latestOfficialMessagesByKey(
    List<MessageModel> messages,
  ) {
    final uid = currentUserId ?? '';
    final result = <String, MessageModel>{};

    for (final message in messages) {
      final key = message.conversationKeyFor(uid);
      final old = result[key];

      if (old == null || message.sentAt.compareTo(old.sentAt) > 0) {
        result[key] = message;
      }
    }

    return result;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _temporaryMessagesStream() {
    final childIds = temporaryChildren.map((child) => child.id).toSet().toList();

    if (childIds.isEmpty) return null;

    return _firestore
        .collection('temporary_messages')
        .where('childId', whereIn: childIds)
        .limit(300)
        .snapshots();
  }

  Map<String, Map<String, dynamic>> _latestTemporaryMessagesByKey(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      final data = doc.data();
      final childId = _clean(data['childId']);

      if (childId.isEmpty) continue;

      final key = 'temporary_$childId';
      final old = result[key];

      final currentDate = data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.fromMillisecondsSinceEpoch(0);

      final oldDate = old?['createdAt'] is Timestamp
          ? old!['createdAt'] as Timestamp
          : Timestamp.fromMillisecondsSinceEpoch(0);

      if (old == null || currentDate.compareTo(oldDate) > 0) {
        result[key] = data;
      }
    }

    return result;
  }

  Widget _buildContactCard({
    required Map<String, dynamic> contact,
    MessageModel? officialMessage,
    Map<String, dynamic>? temporaryMessage,
  }) {
    final name = _clean(contact['name']).isEmpty
        ? 'ولي الأمر'
        : _clean(contact['name']);

    final subtitle = _clean(contact['subtitle']);
    final kind = _clean(contact['kind']);

    final isAdmin = kind == 'admin';
    final isTemporary = kind == 'temporary_parent';

    final officialPreview = officialMessage?.displayText.trim() ?? '';
    final temporaryPreview = _clean(
      temporaryMessage?['message'] ??
          temporaryMessage?['text'] ??
          temporaryMessage?['body'],
    );

    final preview = isTemporary ? temporaryPreview : officialPreview;

    final Timestamp? time = isTemporary
        ? _timestampFromDynamic(temporaryMessage?['createdAt'])
        : officialMessage?.sentAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openContact(contact),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFEFA7C8).withOpacity(0.14),
                child: isAdmin
                    ? const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Color(0xFFEFA7C8),
                      )
                    : Text(
                        _firstLetter(name),
                        style: const TextStyle(
                          color: Color(0xFFEFA7C8),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? _roleLabel(_clean(contact['role'])) : subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time is Timestamp)
                    Text(
                      _formatTime(time),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortedContacts(
    List<Map<String, dynamic>> contacts,
    Map<String, MessageModel> officialMessages,
    Map<String, Map<String, dynamic>> temporaryMessages,
  ) {
    final search = searchCtrl.text.trim().toLowerCase();

    final filtered = contacts.where((contact) {
      if (search.isEmpty) return true;

      final key = _clean(contact['key']);
      final kind = _clean(contact['kind']);

      final officialPreview = officialMessages[key]?.displayText ?? '';
      final temporaryPreview = _clean(
        temporaryMessages[key]?['message'] ??
            temporaryMessages[key]?['text'] ??
            temporaryMessages[key]?['body'],
      );

      final values = [
        contact['name'],
        contact['subtitle'],
        contact['username'],
        kind == 'temporary_parent' ? temporaryPreview : officialPreview,
      ].join(' ').toLowerCase();

      return values.contains(search);
    }).toList();

    int compareTime(Map<String, dynamic> a, Map<String, dynamic> b) {
      Timestamp? timestampFor(Map<String, dynamic> contact) {
        final key = _clean(contact['key']);
        final kind = _clean(contact['kind']);

        if (kind == 'temporary_parent') {
          final value = temporaryMessages[key]?['createdAt'];
          return value is Timestamp ? value : null;
        }

        return officialMessages[key]?.sentAt;
      }

      final aTime = timestampFor(a);
      final bTime = timestampFor(b);

      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }

      if (aTime != null) return -1;
      if (bTime != null) return 1;

      final aKind = _clean(a['kind']);
      final bKind = _clean(b['kind']);

      if (aKind == 'admin' && bKind != 'admin') return -1;
      if (aKind != 'admin' && bKind == 'admin') return 1;

      return _clean(a['name']).compareTo(_clean(b['name']));
    }

    filtered.sort(compareTime);

    return filtered;
  }

  Widget _buildSearchField() {
    return TextField(
      controller: searchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'بحث',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchCtrl.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchCtrl.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildChatsList() {
    final uid = currentUserId;

    if (uid == null) {
      return const Center(
        child: Text('تعذر تحميل هوية المستخدم'),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _adminFuture,
      builder: (context, adminSnapshot) {
        final baseContacts = <Map<String, dynamic>>[
          if (adminSnapshot.data != null) adminSnapshot.data!,
          ..._buildParentContacts(),
        ];

        return StreamBuilder<List<MessageModel>>(
          stream: _messageService.getLatestChatsForUser(
            currentUserId: uid,
          ),
          builder: (context, officialSnapshot) {
            if (officialSnapshot.connectionState == ConnectionState.waiting &&
                !officialSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (officialSnapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ أثناء تحميل المحادثات: ${officialSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            final officialMessages = _latestOfficialMessagesByKey(
              officialSnapshot.data ?? [],
            );

            final temporaryStream = _temporaryMessagesStream();

            if (temporaryStream == null) {
              final contacts = _sortedContacts(
                baseContacts,
                officialMessages,
                const {},
              );

              return _buildContactsList(
                contacts: contacts,
                officialMessages: officialMessages,
                temporaryMessages: const {},
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: temporaryStream,
              builder: (context, temporarySnapshot) {
                if (temporarySnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !temporarySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (temporarySnapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل المحادثات المؤقتة: ${temporarySnapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final temporaryMessages = _latestTemporaryMessagesByKey(
                  temporarySnapshot.data?.docs ?? [],
                );

                final contacts = _sortedContacts(
                  baseContacts,
                  officialMessages,
                  temporaryMessages,
                );

                return _buildContactsList(
                  contacts: contacts,
                  officialMessages: officialMessages,
                  temporaryMessages: temporaryMessages,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContactsList({
    required List<Map<String, dynamic>> contacts,
    required Map<String, MessageModel> officialMessages,
    required Map<String, Map<String, dynamic>> temporaryMessages,
  }) {
    if (contacts.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.send_outlined,
                size: 52,
                color: AppColors.textLight,
              ),
              SizedBox(height: 12),
              Text(
                'لا توجد محادثات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final key = _clean(contact['key']);

        return _buildContactCard(
          contact: contact,
          officialMessage: officialMessages[key],
          temporaryMessage: temporaryMessages[key],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'المراسلات',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildChatsList(),
          ),
        ],
      ),
    );
  }
}
