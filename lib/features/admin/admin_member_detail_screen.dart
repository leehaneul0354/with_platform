// 목적: 회원 상세 정보 확인 및 Trust Score·인증 완료 관리. 관리자만 사용.
// 흐름: AdminMainScreen에서 상세보기 → 수정 후 AuthRepository.updateUser 저장.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/util/birth_date_util.dart';

class AdminMemberDetailScreen extends StatefulWidget {
  const AdminMemberDetailScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<AdminMemberDetailScreen> createState() => _AdminMemberDetailScreenState();
}

class _AdminMemberDetailScreenState extends State<AdminMemberDetailScreen> {
  late UserModel _user;
  late TextEditingController _trustScoreController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _trustScoreController = TextEditingController(text: '${_user.trustScore}');
  }

  @override
  void dispose() {
    _trustScoreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final score = int.tryParse(_trustScoreController.text.trim());
    if (score != null && (score < 0 || score > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신뢰도는 0~100 사이로 입력해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    final updated = _user.copyWith(
      trustScore: score ?? _user.trustScore,
    );
    await AuthRepository.instance.updateUser(updated);
    if (mounted) {
      setState(() {
        _user = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다.')),
      );
    }
  }

  Future<void> _toggleVerified() async {
    final updated = _user.copyWith(isVerified: !_user.isVerified);
    await AuthRepository.instance.updateUser(updated);
    if (mounted) {
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_user.isVerified ? '인증 완료 처리되었습니다.' : '인증 대기로 변경되었습니다.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '회원 상세',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: '기본 정보',
              children: [
                _InfoRow(label: '닉네임(아이디)', value: '${_user.nickname} (${_user.id})'),
                _InfoRow(label: '역할', value: _user.type.label),
                _InfoRow(label: '이메일', value: _user.email.isEmpty ? '-' : _user.email),
                _InfoRow(label: '생년월일', value: BirthDateUtil.formatBirthDateForDisplay(_user.birthDate)),
                _InfoRow(
                  label: '가입일',
                  value: _user.joinedAt != null
                      ? _formatDate(_user.joinedAt!)
                      : '-',
                ),
                _InfoRow(label: '상태', value: _user.status.label),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '플랫폼 신뢰도 (Trust Score)',
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _trustScoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '0 ~ 100',
                      border: OutlineInputBorder(),
                      suffixText: '점',
                    ),
                  ),
                ),
              ],
            ),
            if (_user.type == UserType.patient) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: '투병 기록',
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '증빙 서류·기록 검토 영역 (추후 API 연동)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('인증 완료'),
                    subtitle: const Text('환자 증빙 서류 검토 후 체크'),
                    value: _user.isVerified,
                    onChanged: (_) => _toggleVerified(),
                    activeColor: AppColors.yellow,
                  ),
                ],
              ),
            ],
            if (_user.type == UserType.donor) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: '후원 내역',
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '후원 내역 목록 (추후 API 연동)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
