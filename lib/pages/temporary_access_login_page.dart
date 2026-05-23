import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'temporary_child_view_page.dart';

class TemporaryAccessLoginPage extends StatefulWidget {
  const TemporaryAccessLoginPage({super.key});

  @override
  State<TemporaryAccessLoginPage> createState() =>
      _TemporaryAccessLoginPageState();
}

class _TemporaryAccessLoginPageState extends State<TemporaryAccessLoginPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController codeCtrl = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isExpired(dynamic value) {
    final date = _dateFromDynamic(value);
    if (date == null) return false;
    return DateTime.now().isAfter(date);
  }

  bool _isBlockedStatus(String status) {
    final cleanStatus = status.trim().toLowerCase();

    return cleanStatus == 'cancelled' ||
        cleanStatus == 'disabled' ||
        cleanStatus == 'expired' ||
        cleanStatus == 'archived' ||
        cleanStatus == 'rejected_after_trial' ||
        cleanStatus == 'withdrawn' ||
        cleanStatus == 'inactive';
  }

  bool _isAllowedChildType(Map<String, dynamic> childData) {
    final childType = _cleanText(childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(childData['enrollmentType']).toLowerCase();
    final childStatus = _cleanText(childData['childStatus']).toLowerCase();
    final isTemporaryChild = childData['isTemporaryChild'] == true;

    if (isTemporaryChild) return true;

    return childType == 'temporary' ||
        childType == 'trial' ||
        enrollmentType == 'temporary' ||
        enrollmentType == 'trial' ||
        childStatus == 'temporary' ||
        childStatus == 'trial';
  }

  Future<Map<String, dynamic>?> _findAccessByCode(String code) async {
    final normalized = code.trim();

    final accessSnapshot = await _firestore
        .collection('temporary_access_codes')
        .where('code', isEqualTo: normalized)
        .limit(1)
        .get();

    if (accessSnapshot.docs.isNotEmpty) {
      final doc = accessSnapshot.docs.first;
      return {
        'accessCodeId': doc.id,
        'accessData': doc.data(),
      };
    }

    final childSnapshot = await _firestore
        .collection('children')
        .where('temporaryAccessCode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (childSnapshot.docs.isNotEmpty) {
      final childDoc = childSnapshot.docs.first;
      final childData = childDoc.data();

      if (!_isAllowedChildType(childData)) {
        return null;
      }

      return {
        'accessCodeId': childDoc.id,
        'accessData': {
          'code': normalized,
          'childId': childDoc.id,
          'childName': childData['childName'] ?? childData['name'],
          'parentName': childData['parentName'],
          'parentPhone': childData['parentPhone'],
          'parentUid': childData['parentUid'],
          'parentUsername': childData['parentUsername'],
          'groupId': childData['groupId'],
          'groupName': childData['groupName'] ?? childData['group'],
          'childType': childData['childType'],
          'enrollmentType': childData['enrollmentType'],
          'childStatus': childData['childStatus'],
          'isTemporaryChild': childData['isTemporaryChild'],
          'accessStartAt': childData['temporaryAccessStartAt'] ??
              childData['temporaryStartAt'] ??
              childData['temporaryStartDate'] ??
              childData['trialStartAt'],
          'accessEndAt': childData['temporaryAccessEndAt'] ??
              childData['temporaryEndAt'] ??
              childData['temporaryEndDate'] ??
              childData['trialEndAt'],
          'status': childData['temporaryAccessStatus'] ??
              childData['childStatus'] ??
              'active',
        },
      };
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadChildDoc(
    Map<String, dynamic> accessData,
  ) async {
    final childId = _cleanText(accessData['childId']);

    if (childId.isNotEmpty) {
      final doc = await _firestore.collection('children').doc(childId).get();
      if (doc.exists) return doc;
    }

    final code = _cleanText(accessData['code']);
    if (code.isEmpty) return null;

    final snapshot = await _firestore
        .collection('children')
        .where('temporaryAccessCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }

  Future<void> _login() async {
    final code = codeCtrl.text.trim();

    if (code.isEmpty || isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final accessResult = await _findAccessByCode(code);

      if (accessResult == null) {
        _showMessage('كود الدخول غير صحيح');
        return;
      }

      final accessCodeId = _cleanText(accessResult['accessCodeId']);
      final accessData =
          Map<String, dynamic>.from(accessResult['accessData'] as Map);

      final status = _cleanText(accessData['status']).toLowerCase();
      final isActive = accessData['isActive'] != false;

      if (!isActive || _isBlockedStatus(status)) {
        _showMessage('كود الدخول غير فعّال');
        return;
      }

      if (_isExpired(
        accessData['accessEndAt'] ??
            accessData['temporaryAccessEndAt'] ??
            accessData['temporaryEndAt'] ??
            accessData['temporaryEndDate'] ??
            accessData['trialEndAt'] ??
            accessData['expiresAt'],
      )) {
        _showMessage('انتهت صلاحية كود الدخول');
        return;
      }

      final childDoc = await _loadChildDoc(accessData);

      if (childDoc == null || !childDoc.exists) {
        _showMessage('بيانات الطفل غير موجودة');
        return;
      }

      final childData = childDoc.data() ?? <String, dynamic>{};

      final childStatus = _cleanText(childData['childStatus']).toLowerCase();
      final childIsActive = childData['isActive'] != false;

      if (!childIsActive || _isBlockedStatus(childStatus)) {
        _showMessage('حساب الطفل غير فعّال');
        return;
      }

      if (!_isAllowedChildType(childData)) {
        _showMessage('هذا الكود مخصص للأطفال المؤقتين أو أطفال التجربة فقط');
        return;
      }

      if (_isExpired(
        childData['temporaryAccessEndAt'] ??
            childData['temporaryEndAt'] ??
            childData['temporaryEndDate'] ??
            childData['trialEndAt'],
      )) {
        _showMessage('انتهت صلاحية الدخول لهذا الطفل');
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TemporaryChildViewPage(
            accessCodeId: accessCodeId,
            accessData: accessData,
            childId: childDoc.id,
            childData: childData,
          ),
        ),
      );
    } catch (_) {
      _showMessage('تعذر الدخول، حاولي مرة أخرى');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.key_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'الدخول المؤقت',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: codeCtrl,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'كود الدخول',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _login,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(isLoading ? 'جاري الدخول...' : 'دخول'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الدخول المؤقت',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 35),
          _buildLoginCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}