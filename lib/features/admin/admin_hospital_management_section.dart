// 목적: 병원/기관 관리 섹션 - 협약된 병원 목록 및 정산 계좌 관리
// 흐름: AdminMainScreen의 '병원/기관 관리' 카테고리 선택 시 표시

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AdminHospitalManagementSection extends StatelessWidget {
  const AdminHospitalManagementSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '병원/기관 관리',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  // 병원 추가 기능 (추후 구현)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('병원 추가 기능은 준비 중입니다.')),
                  );
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('병원 추가'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // 콘텐츠
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_hospital_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '병원/기관 관리 기능은 준비 중입니다.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '추후 협약 병원 목록 및 정산 계좌 관리 기능이 추가될 예정입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
