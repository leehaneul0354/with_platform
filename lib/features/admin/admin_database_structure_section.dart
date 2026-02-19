// 목적: ERD 기반 실시간 DB 컨트롤 타워 - 다크 모드, 무한 드래그/줌, 실시간 CRUD, FK 관계 설정
// 흐름: AdminMainScreen의 '데이터베이스 구조' 카테고리 선택 시 표시
// 워터폴 로딩: 300ms 지연 적용하여 Firestore 스트림 충돌 방지

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/auth/user_model.dart';
import '../../core/auth/auth_repository.dart';

/// 필드 타입 정의
enum FieldType { string, integer, boolean, foreignKey, enumType }

/// 필드 제약 조건
class FieldConstraint {
  final int? maxLength;
  final int? minValue;
  final int? maxValue;
  final bool? required;
  final String? pattern; // 정규식 패턴 (예: 이메일)
  final List<String>? enumValues; // enum 타입의 경우

  const FieldConstraint({
    this.maxLength,
    this.minValue,
    this.maxValue,
    this.required,
    this.pattern,
    this.enumValues,
  });

  FieldConstraint copyWith({
    int? maxLength,
    int? minValue,
    int? maxValue,
    bool? required,
    String? pattern,
    List<String>? enumValues,
  }) {
    return FieldConstraint(
      maxLength: maxLength ?? this.maxLength,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      required: required ?? this.required,
      pattern: pattern ?? this.pattern,
      enumValues: enumValues ?? this.enumValues,
    );
  }
}

/// 필드 스키마 정의
class FieldSchema {
  final String fieldName; // Firestore 실제 필드명
  final FieldType type;
  final String description; // 한글 설명
  final FieldConstraint constraint;
  final String? targetCollection; // FK인 경우

  const FieldSchema({
    required this.fieldName,
    required this.type,
    required this.description,
    required this.constraint,
    this.targetCollection,
  });

  FieldSchema copyWith({
    String? fieldName,
    FieldType? type,
    String? description,
    FieldConstraint? constraint,
    String? targetCollection,
  }) {
    return FieldSchema(
      fieldName: fieldName ?? this.fieldName,
      type: type ?? this.type,
      description: description ?? this.description,
      constraint: constraint ?? this.constraint,
      targetCollection: targetCollection ?? this.targetCollection,
    );
  }
}

/// 컬렉션 노드 정의 (ERD 기반)
class CollectionNode {
  final String name;
  final String collectionId;
  final Color color;
  final IconData icon;
  final Offset position; // 캔버스 상 위치
  final List<String> primaryKeys;
  final Map<String, String> foreignKeys; // {fieldName: targetCollection}
  final List<FieldSchema> fields; // 필드 스키마 정의

  const CollectionNode({
    required this.name,
    required this.collectionId,
    required this.color,
    required this.icon,
    required this.position,
    required this.primaryKeys,
    this.foreignKeys = const {},
    this.fields = const [],
  });
}

class AdminDatabaseStructureSection extends StatefulWidget {
  const AdminDatabaseStructureSection({super.key});

  @override
  State<AdminDatabaseStructureSection> createState() => _AdminDatabaseStructureSectionState();
}

class _AdminDatabaseStructureSectionState extends State<AdminDatabaseStructureSection> {
  bool _streamReady = false;
  bool _authConfirmed = false;

  // ERD 노드 정의 (ERD 이미지 기반 배치 + 필드 스키마)
  static final List<CollectionNode> _nodes = [
    CollectionNode(
      name: 'users',
      collectionId: FirestoreCollections.users,
      color: const Color(0xFF4A90E2), // 파란색
      icon: Icons.people_outlined,
      position: const Offset(200, 150),
      primaryKeys: ['id'],
      foreignKeys: {},
      fields: [
        FieldSchema(
          fieldName: FirestoreUserKeys.nickname,
          type: FieldType.string,
          description: '닉네임',
          constraint: FieldConstraint(required: true, maxLength: 20),
        ),
        FieldSchema(
          fieldName: FirestoreUserKeys.type,
          type: FieldType.enumType,
          description: '권한',
          constraint: FieldConstraint(
            enumValues: ['admin', 'patient', 'donor', 'viewer'],
            required: true,
          ),
        ),
        FieldSchema(
          fieldName: FirestoreUserKeys.email,
          type: FieldType.string,
          description: '이메일',
          constraint: FieldConstraint(
            pattern: r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
          ),
        ),
      ],
    ),
    CollectionNode(
      name: 'donations',
      collectionId: FirestoreCollections.donations,
      color: const Color(0xFF50C878), // 초록색
      icon: Icons.volunteer_activism_outlined,
      position: const Offset(600, 150),
      primaryKeys: ['id'],
      foreignKeys: {
        DonationKeys.userId: FirestoreCollections.users, // sender_user_id -> users
        DonationKeys.postId: FirestoreCollections.posts,
      },
      fields: [
        FieldSchema(
          fieldName: DonationKeys.amount,
          type: FieldType.integer,
          description: '후원금액',
          constraint: FieldConstraint(minValue: 1000, required: true),
        ),
        FieldSchema(
          fieldName: 'message', // 실제 필드명 (없으면 추가 필요)
          type: FieldType.string,
          description: '응원메시지',
          constraint: FieldConstraint(maxLength: 30),
        ),
        FieldSchema(
          fieldName: DonationKeys.userId,
          type: FieldType.foreignKey,
          description: '후원자 연결',
          constraint: FieldConstraint(required: true),
          targetCollection: FirestoreCollections.users,
        ),
        FieldSchema(
          fieldName: 'status', // 실제 필드명 (없으면 추가 필요)
          type: FieldType.boolean,
          description: '입금확인 여부',
          constraint: FieldConstraint(),
        ),
      ],
    ),
    CollectionNode(
      name: 'posts',
      collectionId: FirestoreCollections.posts,
      color: const Color(0xFFFF6B6B), // 빨간색
      icon: Icons.article_outlined,
      position: const Offset(200, 400),
      primaryKeys: ['id'],
      foreignKeys: {
        FirestorePostKeys.patientId: FirestoreCollections.users, // patient_profile_id -> users
      },
      fields: [
        FieldSchema(
          fieldName: FirestorePostKeys.title,
          type: FieldType.string,
          description: '제목',
          constraint: FieldConstraint(maxLength: 20, required: true),
        ),
        FieldSchema(
          fieldName: FirestorePostKeys.content,
          type: FieldType.string,
          description: '내용',
          constraint: FieldConstraint(maxLength: 50),
        ),
        FieldSchema(
          fieldName: FirestorePostKeys.neededItems,
          type: FieldType.string,
          description: '필요물품',
          constraint: FieldConstraint(),
        ),
        FieldSchema(
          fieldName: FirestorePostKeys.patientName,
          type: FieldType.string,
          description: '환자명/ID',
          constraint: FieldConstraint(required: true),
        ),
        FieldSchema(
          fieldName: FirestorePostKeys.patientId,
          type: FieldType.foreignKey,
          description: '환자 프로필 연결',
          constraint: FieldConstraint(),
          targetCollection: FirestoreCollections.users,
        ),
      ],
    ),
    CollectionNode(
      name: 'recharges',
      collectionId: FirestoreCollections.recharges,
      color: const Color(0xFFFFD93D), // 노란색
      icon: Icons.account_balance_wallet_outlined,
      position: const Offset(600, 400),
      primaryKeys: ['id'],
      foreignKeys: {
        RechargeKeys.userId: FirestoreCollections.users,
      },
      fields: [
        FieldSchema(
          fieldName: RechargeKeys.amount,
          type: FieldType.integer,
          description: '충전 금액',
          constraint: FieldConstraint(minValue: 1000, required: true),
        ),
        FieldSchema(
          fieldName: RechargeKeys.userId,
          type: FieldType.foreignKey,
          description: '사용자 연결',
          constraint: FieldConstraint(required: true),
          targetCollection: FirestoreCollections.users,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _initializeStreams();
  }

  Future<void> _checkAuth() async {
    // 관리자 세션 완전 확인
    int attempts = 0;
    while (attempts < 50) {
      final user = AuthRepository.instance.currentUser;
      if (user != null && user.isAdmin) {
        if (mounted) {
          setState(() {
            _authConfirmed = true;
          });
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  void _initializeStreams() {
    // 워터폴 로딩: 300ms 지연
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _authConfirmed) {
        setState(() {
          _streamReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 인증 가드: 관리자 세션 완전 확인 전까지 로딩
    if (!_authConfirmed) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A), // 다크 배경
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A), // 다크 모드 배경
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 (다크 모드)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree_outlined, color: Color(0xFFFFD93D), size: 28),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'DB 컨트롤 타워',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '💡 캔버스 더블 클릭: 초기 위치로 복귀',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // 관계도 영역
          Expanded(
            child: !_streamReady
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _DatabaseControlTower(nodes: _nodes),
          ),
        ],
      ),
    );
  }
}

/// DB 컨트롤 타워 캔버스 (드래그 가능)
class _DatabaseControlTower extends StatefulWidget {
  const _DatabaseControlTower({required this.nodes});

  final List<CollectionNode> nodes;

  @override
  State<_DatabaseControlTower> createState() => _DatabaseControlTowerState();
}

class _DatabaseControlTowerState extends State<_DatabaseControlTower> {
  // 각 노드의 현재 위치를 저장하는 맵
  late Map<String, Offset> _nodePositions;
  // 초기 위치 저장 (더블 클릭 복귀용)
  late Map<String, Offset> _initialPositions;
  // 카드 접기 상태
  final Map<String, bool> _cardExpanded = {};

  @override
  void initState() {
    super.initState();
    // 초기 위치 저장
    _nodePositions = {};
    _initialPositions = {};
    for (final node in widget.nodes) {
      _nodePositions[node.collectionId] = node.position;
      _initialPositions[node.collectionId] = node.position;
      _cardExpanded[node.collectionId] = true; // 기본적으로 펼쳐짐
    }
  }

  void _resetPositions() {
    setState(() {
      _nodePositions = Map.from(_initialPositions);
    });
  }

  void _toggleCard(String collectionId) {
    setState(() {
      _cardExpanded[collectionId] = !(_cardExpanded[collectionId] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 충분히 큰 캔버스 크기
    const double canvasWidth = 1200.0;
    const double canvasHeight = 800.0;

    return GestureDetector(
      onDoubleTap: () => _resetPositions(),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
        ),
        child: InteractiveViewer(
          minScale: 0.3,
          maxScale: 3.0,
          constrained: false, // 무한 확장 가능
          boundaryMargin: const EdgeInsets.all(200),
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Stack(
              children: [
                // 관계 선 그리기 (실시간 위치 반영)
                CustomPaint(
                  size: const Size(canvasWidth, canvasHeight),
                  painter: _ConnectionPainter(
                    nodes: widget.nodes,
                    positions: _nodePositions,
                  ),
                ),
                // 노드 배치 (드래그 가능)
                ...widget.nodes.map((node) {
                  final position = _nodePositions[node.collectionId] ?? node.position;
                  return Positioned(
                    left: position.dx,
                    top: position.dy,
                    child: _DraggableCollectionCard(
                      node: node,
                      position: position,
                      isExpanded: _cardExpanded[node.collectionId] ?? true,
                      onPositionChanged: (newPosition) {
                        setState(() {
                          _nodePositions[node.collectionId] = newPosition;
                        });
                      },
                      onToggleExpanded: () => _toggleCard(node.collectionId),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 드래그 가능한 컬렉션 카드
class _DraggableCollectionCard extends StatefulWidget {
  const _DraggableCollectionCard({
    required this.node,
    required this.position,
    required this.isExpanded,
    required this.onPositionChanged,
    required this.onToggleExpanded,
  });

  final CollectionNode node;
  final Offset position;
  final bool isExpanded;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback onToggleExpanded;

  @override
  State<_DraggableCollectionCard> createState() => _DraggableCollectionCardState();
}

class _DraggableCollectionCardState extends State<_DraggableCollectionCard> {
  bool _isDragging = false;
  Offset _dragStartPosition = Offset.zero;
  Offset _cardOffset = Offset.zero;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartPosition = details.globalPosition;
      _cardOffset = widget.position;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final delta = details.globalPosition - _dragStartPosition;
    final newPosition = _cardOffset + delta;
    
    // 캔버스 범위 내로 제한 (카드가 화면 밖으로 사라지지 않도록)
    final constrainedX = newPosition.dx.clamp(0.0, 1200.0 - 320);
    final constrainedY = newPosition.dy.clamp(0.0, 800.0 - 200);
    
    widget.onPositionChanged(Offset(constrainedX, constrainedY));
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque, // 드래그 영역 확대
      child: _CollectionCard(
        node: widget.node,
        isExpanded: widget.isExpanded,
        onToggleExpanded: widget.onToggleExpanded,
      ),
    );
  }
}

/// 컬렉션 카드 (ERD 스타일 + 필드 스키마 뷰어)
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.node,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final CollectionNode node;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(node.collectionId)
          .snapshots(),
      builder: (context, snapshot) {
        final docCount = snapshot.data?.docs.length ?? 0;

        return Container(
          width: 320, // 너비 증가 (필드 스키마 표시 공간 확보)
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: node.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: node.color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 (컬렉션명 + 버튼들)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: node.color.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(node.icon, color: node.color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          node.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: node.color,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: onToggleExpanded,
                          tooltip: isExpanded ? '접기' : '펼치기',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                          onPressed: () => _showCreateDialog(context),
                          tooltip: '새 문서 생성',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 문서 개수
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '$docCount개 문서',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
              // 필드 스키마 뷰어 (최우선 표시 - 더 강조)
              if (node.fields.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F), // 더 어두운 배경
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: node.color.withValues(alpha: 0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: node.color.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schema, size: 18, color: node.color),
                              const SizedBox(width: 8),
                              Text(
                                '필드 스키마',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: node.color,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 18, color: Colors.white70),
                            onPressed: () => _showSchemaEditDialog(context),
                            tooltip: '스키마 편집',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...node.fields.map((field) => _FieldSchemaRow(
                            field: field,
                            node: node,
                          )),
                    ],
                  ),
                ),
              ],
              // 실제 DB 데이터 (접이식으로 하단 배치)
              if (isExpanded) ...[
                const Divider(color: Colors.white30, height: 24),
                ExpansionTile(
                  title: const Text(
                    '최근 문서 데이터',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  initiallyExpanded: false,
                  children: [
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                      ...snapshot.data!.docs.take(5).map((doc) {
                        return _DocumentRow(
                          docId: doc.id,
                          data: doc.data(),
                          node: node,
                        );
                      }),
                    if (snapshot.hasData && snapshot.data!.docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '데이터 없음',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateDocumentDialog(
        collectionId: node.collectionId,
        collectionName: node.name,
        node: node,
      ),
    );
  }

  void _showSchemaEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _SchemaEditDialog(node: node),
    );
  }
}

/// 필드 스키마 행 위젯 (가독성 강화)
class _FieldSchemaRow extends StatelessWidget {
  const _FieldSchemaRow({
    required this.field,
    required this.node,
  });

  final FieldSchema field;
  final CollectionNode node;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타입 Badge (더 크게)
          _TypeBadge(type: field.type),
          const SizedBox(width: 12),
          // 필드명 및 설명 (더 강조)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      field.fieldName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (field.constraint.required == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          '*',
                          style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  field.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 제약 조건 표시 (더 명확하게)
                if (_getConstraintText().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getConstraintText(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConstraintText() {
    final constraints = <String>[];
    if (field.constraint.maxLength != null) {
      constraints.add('글자제한 ${field.constraint.maxLength}자');
    }
    if (field.constraint.minValue != null) {
      constraints.add('최소 ${field.constraint.minValue}');
    }
    if (field.constraint.pattern != null) {
      constraints.add('이메일 형식 필수');
    }
    if (field.constraint.enumValues != null) {
      constraints.add('enum: ${field.constraint.enumValues!.join(", ")}');
    }
    if (field.type == FieldType.foreignKey && field.targetCollection != null) {
      constraints.add('FK → ${field.targetCollection}');
    }
    return constraints.isEmpty ? '' : '(${constraints.join(", ")})';
  }
}

/// 타입 Badge 위젯 (더 크고 강조)
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final FieldType type;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String label;

    switch (type) {
      case FieldType.string:
        badgeColor = Colors.blue;
        label = 'str';
        break;
      case FieldType.integer:
        badgeColor = Colors.green;
        label = 'int';
        break;
      case FieldType.boolean:
        badgeColor = Colors.orange;
        label = 'bool';
        break;
      case FieldType.foreignKey:
        badgeColor = Colors.purple;
        label = 'FK';
        break;
      case FieldType.enumType:
        badgeColor = Colors.teal;
        label = 'enum';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 문서 행 (실시간 CRUD 지원)
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.docId,
    required this.data,
    required this.node,
  });

  final String docId;
  final Map<String, dynamic> data;
  final CollectionNode node;

  @override
  Widget build(BuildContext context) {
    // 주요 필드 추출
    String displayText = _getDisplayText();
    String? fkField = _getFirstForeignKey();

    return InkWell(
      onTap: () => _showEditDialog(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fkField != null) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showForeignKeyDialog(context, fkField!),
                      child: Text(
                        'FK: ${data[fkField]}',
                        style: TextStyle(
                          fontSize: 11,
                          color: node.color,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              onPressed: () => _showDeleteConfirm(context),
              tooltip: '삭제',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayText() {
    switch (node.collectionId) {
      case FirestoreCollections.users:
        return data[FirestoreUserKeys.nickname]?.toString() ?? 
               data[FirestoreUserKeys.id]?.toString() ?? docId;
      case FirestoreCollections.posts:
        return data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
      case FirestoreCollections.donations:
        final amount = data[DonationKeys.amount] ?? 0;
        return '${_formatAmount(amount)}원';
      case FirestoreCollections.recharges:
        final amount = data[RechargeKeys.amount] ?? 0;
        return '${_formatAmount(amount)}원';
      default:
        return docId.substring(0, 8);
    }
  }

  String? _getFirstForeignKey() {
    if (node.foreignKeys.isEmpty) return null;
    return node.foreignKeys.keys.first;
  }

  String _formatAmount(dynamic value) {
    final amount = value is int ? value : (int.tryParse(value.toString()) ?? 0);
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _EditDocumentDialog(
        docId: docId,
        data: data,
        node: node,
      ),
    );
  }

  void _showForeignKeyDialog(BuildContext context, String fkField) {
    final targetCollection = node.foreignKeys[fkField];
    if (targetCollection == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _ForeignKeySelectionDialog(
        docId: docId,
        collectionId: node.collectionId,
        fkField: fkField,
        targetCollection: targetCollection,
        currentValue: data[fkField]?.toString(),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('삭제 확인', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          '이 데이터는 복구할 수 없습니다.\n정말 삭제하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteDocument(context);
    }
  }

  Future<void> _deleteDocument(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection(node.collectionId).doc(docId);
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          transaction.delete(docRef);
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 관계 선 페인터 (실시간 위치 반영)
class _ConnectionPainter extends CustomPainter {
  _ConnectionPainter({
    required this.nodes,
    required this.positions,
  });

  final List<CollectionNode> nodes;
  final Map<String, Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // FK 관계 선 그리기 (실시간 위치 사용)
    for (final node in nodes) {
      for (final entry in node.foreignKeys.entries) {
        final targetNode = nodes.firstWhere(
          (n) => n.collectionId == entry.value,
          orElse: () => node,
        );

        // 현재 위치 사용 (없으면 초기 위치)
        final fromPos = positions[node.collectionId] ?? node.position;
        final toPos = positions[targetNode.collectionId] ?? targetNode.position;

        final fromX = fromPos.dx + 160; // 카드 중앙
        final fromY = fromPos.dy + 100;
        final toX = toPos.dx + 160;
        final toY = toPos.dy + 100;

        paint.color = node.color.withValues(alpha: 0.6);
        _drawArrow(canvas, paint, fromX, fromY, toX, toY);
      }
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, double x1, double y1, double x2, double y2) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

    // 화살표 머리 그리기
    final angle = math.atan2(y2 - y1, x2 - x1);
    const arrowLength = 10.0;
    const arrowAngle = 0.5;

    canvas.drawLine(
      Offset(x2, y2),
      Offset(
        x2 - arrowLength * math.cos(angle - arrowAngle),
        y2 - arrowLength * math.sin(angle - arrowAngle),
      ),
      paint,
    );
    canvas.drawLine(
      Offset(x2, y2),
      Offset(
        x2 - arrowLength * math.cos(angle + arrowAngle),
        y2 - arrowLength * math.sin(angle + arrowAngle),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ConnectionPainter oldDelegate) {
    // 위치가 변경되면 다시 그리기
    return oldDelegate.positions != positions;
  }
}

/// 문서 편집 다이얼로그
class _EditDocumentDialog extends StatefulWidget {
  const _EditDocumentDialog({
    required this.docId,
    required this.data,
    required this.node,
  });

  final String docId;
  final Map<String, dynamic> data;
  final CollectionNode node;

  @override
  State<_EditDocumentDialog> createState() => _EditDocumentDialogState();
}

class _EditDocumentDialogState extends State<_EditDocumentDialog> {
  late final Map<String, TextEditingController> _controllers;
  UserType? _selectedUserType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final key in widget.data.keys) {
      final value = widget.data[key];
      _controllers[key] = TextEditingController(text: value?.toString() ?? '');

      // Users 타입 필드 처리
      if ((key == FirestoreUserKeys.type || key == FirestoreUserKeys.role) && value != null) {
        try {
          _selectedUserType = UserType.values.firstWhere(
            (type) => type.name == value.toString(),
            orElse: () => UserType.viewer,
          );
        } catch (_) {
          _selectedUserType = UserType.viewer;
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.node.name} 편집',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _buildFields(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSaving ? null : _saveDocument,
                  style: FilledButton.styleFrom(backgroundColor: widget.node.color),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final fields = <Widget>[];

    for (final entry in _controllers.entries) {
      final key = entry.key;
      final controller = entry.value;

      // FK 필드는 특별 처리
      if (widget.node.foreignKeys.containsKey(key)) {
        fields.add(
          _ForeignKeyField(
            label: key,
            value: controller.text,
            targetCollection: widget.node.foreignKeys[key]!,
            onTap: () => _showForeignKeySelection(key),
          ),
        );
        continue;
      }

      // Users 타입 필드
      if (key == FirestoreUserKeys.type || key == FirestoreUserKeys.role) {
        fields.add(
          DropdownButtonFormField<UserType>(
            value: _selectedUserType,
            decoration: InputDecoration(
              labelText: key,
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white),
            items: UserType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedUserType = value),
          ),
        );
        continue;
      }

      // 일반 텍스트 필드
      fields.add(
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: key,
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: widget.node.color),
            ),
          ),
        ),
      );
      fields.add(const SizedBox(height: 16));
    }

    return fields;
  }

  void _showForeignKeySelection(String fkField) {
    final targetCollection = widget.node.foreignKeys[fkField];
    if (targetCollection == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _ForeignKeySelectionDialog(
        docId: widget.docId,
        collectionId: widget.node.collectionId,
        fkField: fkField,
        targetCollection: targetCollection,
        currentValue: _controllers[fkField]?.text,
      ),
    ).then((selectedId) {
      if (selectedId != null && mounted) {
        _controllers[fkField]?.text = selectedId;
        setState(() {});
      }
    });
  }

  Future<void> _saveDocument() async {
    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{};

      for (final entry in _controllers.entries) {
        final key = entry.key;
        final value = entry.value.text;

        // Users 타입 처리
        if ((key == FirestoreUserKeys.type || key == FirestoreUserKeys.role) && _selectedUserType != null) {
          updates[key] = _selectedUserType!.name;
          continue;
        }

        // 숫자 필드 처리
        if (key == DonationKeys.amount || key == RechargeKeys.amount) {
          updates[key] = int.tryParse(value) ?? 0;
          continue;
        }

        updates[key] = value;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection(widget.node.collectionId).doc(widget.docId);
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          transaction.update(docRef, updates);
        }
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// FK 필드 위젯
class _ForeignKeyField extends StatelessWidget {
  const _ForeignKeyField({
    required this.label,
    required this.value,
    required this.targetCollection,
    required this.onTap,
  });

  final String label;
  final String value;
  final String targetCollection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '(선택 안됨)' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

/// FK 선택 다이얼로그
class _ForeignKeySelectionDialog extends StatelessWidget {
  const _ForeignKeySelectionDialog({
    required this.docId,
    required this.collectionId,
    required this.fkField,
    required this.targetCollection,
    this.currentValue,
  });

  final String docId;
  final String collectionId;
  final String fkField;
  final String targetCollection;
  final String? currentValue;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$fkField 연결 선택',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(targetCollection)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('에러: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('데이터가 없습니다.', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final docId = doc.id;
                      final isSelected = docId == currentValue;

                      // 표시 이름 추출
                      String displayName = docId;
                      if (targetCollection == FirestoreCollections.users) {
                        displayName = data[FirestoreUserKeys.nickname]?.toString() ?? 
                                     data[FirestoreUserKeys.id]?.toString() ?? docId;
                      }

                      return ListTile(
                        title: Text(displayName, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(docId, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withValues(alpha: 0.2),
                        onTap: () => _updateForeignKey(context, docId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateForeignKey(BuildContext context, String selectedId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection(collectionId).doc(docId);
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          transaction.update(docRef, {fkField: selectedId});
        }
      });

      if (context.mounted) {
        Navigator.of(context).pop(selectedId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('연결이 업데이트되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업데이트 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 스키마 편집 다이얼로그
class _SchemaEditDialog extends StatefulWidget {
  const _SchemaEditDialog({required this.node});

  final CollectionNode node;

  @override
  State<_SchemaEditDialog> createState() => _SchemaEditDialogState();
}

class _SchemaEditDialogState extends State<_SchemaEditDialog> {
  late List<FieldSchema> _editedFields;

  @override
  void initState() {
    super.initState();
    _editedFields = List.from(widget.node.fields);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.node.name} 스키마 편집',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _editedFields.length,
                itemBuilder: (context, index) {
                  final field = _editedFields[index];
                  return _FieldSchemaEditRow(
                    field: field,
                    onChanged: (updatedField) {
                      setState(() {
                        _editedFields[index] = updatedField;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    // 실제로는 노드의 fields를 업데이트해야 하지만,
                    // 현재 구조상 읽기 전용이므로 스낵바로 알림만 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('스키마 편집 기능은 개발 중입니다.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: widget.node.color),
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 필드 스키마 편집 행
class _FieldSchemaEditRow extends StatelessWidget {
  const _FieldSchemaEditRow({
    required this.field,
    required this.onChanged,
  });

  final FieldSchema field;
  final ValueChanged<FieldSchema> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF333333),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: field.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    field.fieldName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, size: 18, color: Colors.white70),
                  onPressed: () => _showConstraintEditDialog(context),
                  tooltip: '제약 조건 편집',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              field.description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            if (_getConstraintText().isNotEmpty)
              Text(
                _getConstraintText(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getConstraintText() {
    final constraints = <String>[];
    if (field.constraint.maxLength != null) {
      constraints.add('글자제한 ${field.constraint.maxLength}자');
    }
    if (field.constraint.minValue != null) {
      constraints.add('최소 ${field.constraint.minValue}');
    }
    if (field.constraint.pattern != null) {
      constraints.add('이메일 형식 필수');
    }
    return constraints.isEmpty ? '' : '(${constraints.join(", ")})';
  }

  void _showConstraintEditDialog(BuildContext context) {
    int? maxLength = field.constraint.maxLength;
    int? minValue = field.constraint.minValue;
    bool required = field.constraint.required ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('제약 조건 편집', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (field.type == FieldType.string) ...[
                TextField(
                  decoration: const InputDecoration(
                    labelText: '최대 글자 수',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => maxLength = int.tryParse(value),
                ),
                const SizedBox(height: 16),
              ],
              if (field.type == FieldType.integer) ...[
                TextField(
                  decoration: const InputDecoration(
                    labelText: '최소값',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => minValue = int.tryParse(value),
                ),
                const SizedBox(height: 16),
              ],
              CheckboxListTile(
                title: const Text('필수 필드', style: TextStyle(color: Colors.white)),
                value: required,
                onChanged: (value) => setState(() => required = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () {
                final updatedConstraint = field.constraint.copyWith(
                  maxLength: maxLength,
                  minValue: minValue,
                  required: required,
                );
                onChanged(field.copyWith(constraint: updatedConstraint));
                Navigator.of(ctx).pop();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 새 문서 생성 다이얼로그
class _CreateDocumentDialog extends StatefulWidget {
  const _CreateDocumentDialog({
    required this.collectionId,
    required this.collectionName,
    required this.node,
  });

  final String collectionId;
  final String collectionName;
  final CollectionNode node;

  @override
  State<_CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<_CreateDocumentDialog> {
  final Map<String, TextEditingController> _controllers = {};
  UserType? _selectedUserType;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // 스키마 기반 컨트롤러 초기화
    for (final fieldSchema in widget.node.fields) {
      final key = fieldSchema.fieldName;
      
      // Enum 필드는 컨트롤러 생성하지 않음
      if (fieldSchema.type == FieldType.enumType && 
          (key == FirestoreUserKeys.type || key == FirestoreUserKeys.role)) {
        _selectedUserType = UserType.viewer;
        continue;
      }
      
      _controllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.collectionName} 새 문서 생성',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _buildFields(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isCreating ? null : _createDocument,
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('생성'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final fields = <Widget>[];

    // 스키마 기반 필드 생성
    for (final fieldSchema in widget.node.fields) {
      final key = fieldSchema.fieldName;
      
      // FK 필드 처리
      if (fieldSchema.type == FieldType.foreignKey) {
        final controller = _controllers[key] ?? TextEditingController();
        _controllers[key] = controller;
        
        fields.add(
          _ForeignKeyField(
            label: fieldSchema.description,
            value: controller.text,
            targetCollection: fieldSchema.targetCollection ?? '',
            onTap: () => _showForeignKeySelection(key, fieldSchema.targetCollection ?? ''),
          ),
        );
        fields.add(const SizedBox(height: 16));
        continue;
      }

      // Enum 필드 처리
      if (fieldSchema.type == FieldType.enumType) {
        if (key == FirestoreUserKeys.type || key == FirestoreUserKeys.role) {
          fields.add(
            DropdownButtonFormField<UserType>(
              value: _selectedUserType,
              decoration: InputDecoration(
                labelText: '${fieldSchema.description} *',
                labelStyle: const TextStyle(color: Colors.white70),
                helperText: _getConstraintText(fieldSchema),
                helperStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white),
              items: UserType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedUserType = value),
            ),
          );
          fields.add(const SizedBox(height: 16));
          continue;
        }
      }

      // 일반 필드 처리
      final controller = _controllers[key] ?? TextEditingController();
      _controllers[key] = controller;

      // 실시간 검증을 위한 상태 변수
      String? errorText;

      fields.add(
        StatefulBuilder(
          builder: (context, setState) => TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '${fieldSchema.description}${fieldSchema.constraint.required == true ? " *" : ""}',
              labelStyle: const TextStyle(color: Colors.white70),
              helperText: _getConstraintText(fieldSchema),
              helperStyle: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              errorText: errorText,
              errorStyle: const TextStyle(color: Colors.red),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            keyboardType: fieldSchema.type == FieldType.integer
                ? TextInputType.number
                : TextInputType.text,
            maxLength: fieldSchema.constraint.maxLength,
            onChanged: (value) {
              final error = _validateFieldValue(fieldSchema, value);
              setState(() {
                errorText = error;
              });
            },
          ),
        ),
      );
      fields.add(const SizedBox(height: 16));
    }

    return fields;
  }

  String? _validateFieldValue(FieldSchema field, String value) {
    // 필수 필드 검증
    if (field.constraint.required == true && value.isEmpty) {
      return '필수 필드입니다.';
    }

    // 최대 길이 검증
    if (field.constraint.maxLength != null && value.length > field.constraint.maxLength!) {
      return '최대 ${field.constraint.maxLength}자까지 입력 가능합니다.';
    }

    // 최소값 검증
    if (field.type == FieldType.integer && field.constraint.minValue != null) {
      final intValue = int.tryParse(value);
      if (intValue != null && intValue < field.constraint.minValue!) {
        return '최소 ${field.constraint.minValue} 이상 입력해야 합니다.';
      }
    }

    // 패턴 검증 (이메일 등)
    if (field.constraint.pattern != null && value.isNotEmpty) {
      final regex = RegExp(field.constraint.pattern!);
      if (!regex.hasMatch(value)) {
        return '올바른 형식이 아닙니다.';
      }
    }

    return null;
  }

  String _getConstraintText(FieldSchema field) {
    final constraints = <String>[];
    if (field.constraint.maxLength != null) {
      constraints.add('글자제한 ${field.constraint.maxLength}자');
    }
    if (field.constraint.minValue != null) {
      constraints.add('최소 ${field.constraint.minValue}');
    }
    if (field.constraint.pattern != null) {
      constraints.add('이메일 형식 필수');
    }
    return constraints.isEmpty ? '' : '(${constraints.join(", ")})';
  }

  void _showForeignKeySelection(String fkField, String targetCollection) {
    showDialog(
      context: context,
      builder: (ctx) => _ForeignKeySelectionDialog(
        docId: '', // 새 문서이므로 빈 문자열
        collectionId: widget.collectionId,
        fkField: fkField,
        targetCollection: targetCollection,
        currentValue: _controllers[fkField]?.text,
      ),
    ).then((selectedId) {
      if (selectedId != null && mounted) {
        _controllers[fkField]?.text = selectedId;
        setState(() {});
      }
    });
  }

  Future<void> _createDocument() async {
    // 스키마 기반 실시간 검증
    final validationErrors = <String, String>{};
    for (final fieldSchema in widget.node.fields) {
      final key = fieldSchema.fieldName;
      final value = _controllers[key]?.text ?? '';
      final error = _validateFieldValue(fieldSchema, value);
      if (error != null) {
        validationErrors[key] = error;
      }
    }

    if (validationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('검증 실패: ${validationErrors.values.first}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_validateRequiredFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 필드를 모두 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final data = <String, dynamic>{
        _getCreatedAtField(): FieldValue.serverTimestamp(),
      };

      // 스키마 기반 데이터 생성
      for (final fieldSchema in widget.node.fields) {
        final key = fieldSchema.fieldName;
        final value = _controllers[key]?.text ?? '';

        // Enum 필드 처리
        if (fieldSchema.type == FieldType.enumType && 
            (key == FirestoreUserKeys.type || key == FirestoreUserKeys.role)) {
          if (_selectedUserType != null) {
            data[key] = _selectedUserType!.name;
          }
          continue;
        }

        // FK 필드는 이미 선택된 값 사용
        if (fieldSchema.type == FieldType.foreignKey) {
          if (value.isNotEmpty) {
            data[key] = value;
          }
          continue;
        }

        // 숫자 필드 처리
        if (fieldSchema.type == FieldType.integer) {
          data[key] = int.tryParse(value) ?? 0;
          continue;
        }

        // 불린 필드 처리
        if (fieldSchema.type == FieldType.boolean) {
          data[key] = value.toLowerCase() == 'true' || value == '1';
          continue;
        }

        // 문자열 필드
        if (value.isNotEmpty) {
          data[key] = value;
        }
      }

      // 컬렉션별 기본값 설정
      switch (widget.collectionId) {
        case FirestoreCollections.users:
          if (!data.containsKey(FirestoreUserKeys.trustScore)) {
            data[FirestoreUserKeys.trustScore] = 0;
          }
          if (!data.containsKey(FirestoreUserKeys.isVerified)) {
            data[FirestoreUserKeys.isVerified] = false;
          }
          break;
        case FirestoreCollections.posts:
          if (!data.containsKey(FirestorePostKeys.status)) {
            data[FirestorePostKeys.status] = FirestorePostKeys.pending;
          }
          break;
        case FirestoreCollections.recharges:
          if (!data.containsKey(RechargeKeys.paymentMethod)) {
            data[RechargeKeys.paymentMethod] = 'admin';
          }
          break;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection(widget.collectionId).doc();
        transaction.set(docRef, data);
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('문서가 생성되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validateRequiredFields() {
    // 스키마 기반 검증
    for (final fieldSchema in widget.node.fields) {
      if (fieldSchema.constraint.required == true) {
        final key = fieldSchema.fieldName;
        final value = _controllers[key]?.text ?? '';
        
        // Enum 필드 특별 처리
        if (fieldSchema.type == FieldType.enumType && 
            (key == FirestoreUserKeys.type || key == FirestoreUserKeys.role)) {
          if (_selectedUserType == null) return false;
          continue;
        }
        
        if (value.isEmpty) return false;
      }
    }
    return true;
  }

  String _getCreatedAtField() {
    switch (widget.collectionId) {
      case FirestoreCollections.users:
        return FirestoreUserKeys.createdAt;
      case FirestoreCollections.posts:
        return FirestorePostKeys.createdAt;
      case FirestoreCollections.donations:
        return DonationKeys.createdAt;
      case FirestoreCollections.recharges:
        return RechargeKeys.createdAt;
      default:
        return 'createdAt';
    }
  }
}
