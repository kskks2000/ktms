import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'master_api.dart';

class UserAccessMasterPage extends StatefulWidget {
  const UserAccessMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<UserAccessMasterPage> createState() => _UserAccessMasterPageState();
}

class _UserAccessMasterPageState extends State<UserAccessMasterPage> {
  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _mobileController = TextEditingController();
  final _departmentController = TextEditingController();
  final _businessUnitController = TextEditingController();
  final _roleCodeController = TextEditingController();
  final _roleNameController = TextEditingController();
  final _roleDescriptionController = TextEditingController();
  final _dataScopeController = TextEditingController();
  final _expiresAtController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_UserAccessRecord> _records;
  _RoleProfile? _profileFilter;
  _RoleProfile _selectedProfile = _RoleProfile.operator;
  _UserStatus _selectedStatus = _UserStatus.active;
  String _statusFilter = 'ALL';
  String _query = '';
  int? _selectedId;
  bool _isActive = true;
  bool _mfaEnabled = true;
  bool _allowWeb = true;
  bool _allowMobile = true;
  bool _requireApproval = false;
  Set<String> _selectedPermissions = {};

  @override
  void initState() {
    super.initState();
    _records = List<_UserAccessRecord>.from(_seedUsers);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _departmentController.dispose();
    _businessUnitController.dispose();
    _roleCodeController.dispose();
    _roleNameController.dispose();
    _roleDescriptionController.dispose();
    _dataScopeController.dispose();
    _expiresAtController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_UserAccessRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesProfile =
          _profileFilter == null || record.profile == _profileFilter;
      final matchesStatus =
          _statusFilter == 'ALL' || record.status.code == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.fullName.toLowerCase().contains(normalizedQuery) ||
          record.loginId.toLowerCase().contains(normalizedQuery) ||
          record.email.toLowerCase().contains(normalizedQuery) ||
          record.roleName.toLowerCase().contains(normalizedQuery) ||
          record.departmentName.toLowerCase().contains(normalizedQuery);
      return matchesProfile && matchesStatus && matchesQuery;
    }).toList();
  }

  _UserAccessRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_UserAccessRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedProfile = record.profile;
      _selectedStatus = record.status;
      _loginController.text = record.loginId;
      _emailController.text = record.email;
      _nameController.text = record.fullName;
      _phoneController.text = record.phone;
      _mobileController.text = record.mobile;
      _departmentController.text = record.departmentName;
      _businessUnitController.text = record.businessUnitName;
      _roleCodeController.text = record.roleCode;
      _roleNameController.text = record.roleName;
      _roleDescriptionController.text = record.roleDescription;
      _dataScopeController.text = record.dataScope;
      _expiresAtController.text = record.expiresAt;
      _memoController.text = record.memo;
      _isActive = record.isActive;
      _mfaEnabled = record.mfaEnabled;
      _allowWeb = record.allowWeb;
      _allowMobile = record.allowMobile;
      _requireApproval = record.requireApproval;
      _selectedPermissions = Set<String>.from(record.permissions);
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    final profile = _profileFilter ?? _RoleProfile.operator;
    _selectedId = null;
    _selectedProfile = profile;
    _selectedStatus = _UserStatus.invited;
    _loginController.text = _nextLoginId(profile);
    _emailController.clear();
    _nameController.clear();
    _phoneController.clear();
    _mobileController.clear();
    _departmentController.text = profile.departmentHint;
    _businessUnitController.text = 'KCASTLE 본사';
    _roleCodeController.text = profile.roleCode;
    _roleNameController.text = profile.roleName;
    _roleDescriptionController.text = profile.description;
    _dataScopeController.text = profile.dataScope;
    _expiresAtController.clear();
    _memoController.clear();
    _isActive = true;
    _mfaEnabled = true;
    _allowWeb = true;
    _allowMobile = profile != _RoleProfile.admin;
    _requireApproval = profile == _RoleProfile.admin;
    _selectedPermissions = Set<String>.from(profile.defaultPermissions);
  }

  String _nextLoginId(_RoleProfile profile) {
    final count =
        _records.where((record) => record.profile == profile).length + 1;
    return '${profile.prefix}${count.toString().padLeft(3, '0')}@kcastle.net';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  void _applyProfile(_RoleProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _roleCodeController.text = profile.roleCode;
      _roleNameController.text = profile.roleName;
      _roleDescriptionController.text = profile.description;
      _dataScopeController.text = profile.dataScope;
      _selectedPermissions = Set<String>.from(profile.defaultPermissions);
      if (_selectedId == null) {
        _loginController.text = _nextLoginId(profile);
        _departmentController.text = profile.departmentHint;
      }
    });
  }

  Future<void> _saveRecord() async {
    final fullName = _nameController.text.trim();
    final loginId = _loginController.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용자명을 입력하세요.')));
      return;
    }
    if (loginId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 ID를 입력하세요.')));
      return;
    }

    final record = _UserAccessRecord(
      id: _selectedId ?? _nextRecordId(),
      profile: _selectedProfile,
      status: _selectedStatus,
      loginId: loginId,
      email: _emailController.text.trim().isEmpty
          ? loginId
          : _emailController.text.trim(),
      fullName: fullName,
      phone: _phoneController.text.trim(),
      mobile: _mobileController.text.trim(),
      departmentName: _departmentController.text.trim(),
      businessUnitName: _businessUnitController.text.trim(),
      roleCode: _roleCodeController.text.trim(),
      roleName: _roleNameController.text.trim(),
      roleDescription: _roleDescriptionController.text.trim(),
      dataScope: _dataScopeController.text.trim(),
      expiresAt: _expiresAtController.text.trim(),
      permissions: _selectedPermissions.toList()..sort(),
      isActive: _isActive,
      mfaEnabled: _mfaEnabled,
      allowWeb: _allowWeb,
      allowMobile: _allowMobile,
      requireApproval: _requireApproval,
      memo: _memoController.text.trim(),
    );

    setState(() {
      final index = _records.indexWhere((item) => item.id == record.id);
      if (index == -1) {
        _records.insert(0, record);
      } else {
        _records[index] = record;
      }
      _selectedId = record.id;
    });

    final result = await MasterApi.instance.saveUserAccess(
      record.toApiPayload(),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.fullName} 사용자/권한 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.fullName} 사용자/권한 마스터가 반영되었습니다.',
        ),
      ),
    );
  }

  int _nextRecordId() {
    return _records.map((record) => record.id).reduce((a, b) => a > b ? a : b) +
        1;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filteredRecords;
    final selectedRecord = _selectedRecord;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1140 && !widget.compact;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 16 : 24,
            widget.compact ? 18 : 22,
            widget.compact ? 16 : 24,
            widget.compact ? 90 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccessHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _AccessStats(records: _records),
              const SizedBox(height: 16),
              _RoleProfileSelector(
                selectedProfile: _profileFilter,
                counts: {
                  for (final profile in _RoleProfile.values)
                    profile: _records
                        .where((record) => record.profile == profile)
                        .length,
                },
                onSelect: (profile) => setState(() {
                  _profileFilter = _profileFilter == profile ? null : profile;
                  final records = _filteredRecords;
                  if (records.isNotEmpty) {
                    _selectRecord(records.first, notify: false);
                  }
                }),
              ),
              const SizedBox(height: 12),
              _AccessToolbar(
                query: _query,
                statusFilter: _statusFilter,
                onQueryChanged: (value) => setState(() => _query = value),
                onStatusChanged: (value) =>
                    setState(() => _statusFilter = value),
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _UserDirectoryPanel(
                        records: filteredRecords,
                        selectedId: _selectedId,
                        onSelect: _selectRecord,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 468,
                      child: _UserEditorPanel(
                        selectedRecord: selectedRecord,
                        loginController: _loginController,
                        emailController: _emailController,
                        nameController: _nameController,
                        phoneController: _phoneController,
                        mobileController: _mobileController,
                        departmentController: _departmentController,
                        businessUnitController: _businessUnitController,
                        roleCodeController: _roleCodeController,
                        roleNameController: _roleNameController,
                        roleDescriptionController: _roleDescriptionController,
                        dataScopeController: _dataScopeController,
                        expiresAtController: _expiresAtController,
                        memoController: _memoController,
                        selectedProfile: _selectedProfile,
                        selectedStatus: _selectedStatus,
                        selectedPermissions: _selectedPermissions,
                        isActive: _isActive,
                        mfaEnabled: _mfaEnabled,
                        allowWeb: _allowWeb,
                        allowMobile: _allowMobile,
                        requireApproval: _requireApproval,
                        onProfileChanged: _applyProfile,
                        onStatusChanged: (value) =>
                            setState(() => _selectedStatus = value),
                        onPermissionChanged: (code, selected) => setState(() {
                          if (selected) {
                            _selectedPermissions.add(code);
                          } else {
                            _selectedPermissions.remove(code);
                          }
                        }),
                        onActiveChanged: (value) =>
                            setState(() => _isActive = value),
                        onMfaChanged: (value) =>
                            setState(() => _mfaEnabled = value),
                        onWebChanged: (value) =>
                            setState(() => _allowWeb = value),
                        onMobileChanged: (value) =>
                            setState(() => _allowMobile = value),
                        onApprovalChanged: (value) =>
                            setState(() => _requireApproval = value),
                        onSave: _saveRecord,
                      ),
                    ),
                  ],
                )
              else ...[
                _UserEditorPanel(
                  selectedRecord: selectedRecord,
                  loginController: _loginController,
                  emailController: _emailController,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  mobileController: _mobileController,
                  departmentController: _departmentController,
                  businessUnitController: _businessUnitController,
                  roleCodeController: _roleCodeController,
                  roleNameController: _roleNameController,
                  roleDescriptionController: _roleDescriptionController,
                  dataScopeController: _dataScopeController,
                  expiresAtController: _expiresAtController,
                  memoController: _memoController,
                  selectedProfile: _selectedProfile,
                  selectedStatus: _selectedStatus,
                  selectedPermissions: _selectedPermissions,
                  isActive: _isActive,
                  mfaEnabled: _mfaEnabled,
                  allowWeb: _allowWeb,
                  allowMobile: _allowMobile,
                  requireApproval: _requireApproval,
                  onProfileChanged: _applyProfile,
                  onStatusChanged: (value) =>
                      setState(() => _selectedStatus = value),
                  onPermissionChanged: (code, selected) => setState(() {
                    if (selected) {
                      _selectedPermissions.add(code);
                    } else {
                      _selectedPermissions.remove(code);
                    }
                  }),
                  onActiveChanged: (value) => setState(() => _isActive = value),
                  onMfaChanged: (value) => setState(() => _mfaEnabled = value),
                  onWebChanged: (value) => setState(() => _allowWeb = value),
                  onMobileChanged: (value) =>
                      setState(() => _allowMobile = value),
                  onApprovalChanged: (value) =>
                      setState(() => _requireApproval = value),
                  onSave: _saveRecord,
                ),
                const SizedBox(height: 16),
                _UserDirectoryPanel(
                  records: filteredRecords,
                  selectedId: _selectedId,
                  onSelect: _selectRecord,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AccessHeader extends StatelessWidget {
  const _AccessHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Color(0xFF7C3AED),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사용자/권한 마스터',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Firebase 인증 사용자와 KTMS 역할, 권한, 접속 정책을 관리합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
            label: const Text('사용자 등록'),
          ),
        ],
      ),
    );
  }
}

class _AccessStats extends StatelessWidget {
  const _AccessStats({required this.records});

  final List<_UserAccessRecord> records;

  @override
  Widget build(BuildContext context) {
    final active = records
        .where((record) => record.status == _UserStatus.active)
        .length;
    final mfa = records.where((record) => record.mfaEnabled).length;
    final admins = records
        .where((record) => record.profile == _RoleProfile.admin)
        .length;
    final mobile = records.where((record) => record.allowMobile).length;
    final metrics = [
      _AccessMetric(
        '활성 사용자',
        '$active',
        Icons.verified_user_rounded,
        AppTheme.teal,
      ),
      _AccessMetric(
        'MFA 적용',
        '$mfa',
        Icons.security_rounded,
        const Color(0xFF2563EB),
      ),
      _AccessMetric(
        '관리자',
        '$admins',
        Icons.admin_panel_settings_rounded,
        const Color(0xFF7C3AED),
      ),
      _AccessMetric(
        '모바일 허용',
        '$mobile',
        Icons.phone_iphone_rounded,
        AppTheme.amber,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) =>
                    SizedBox(width: width, child: _AccessMetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _RoleProfileSelector extends StatelessWidget {
  const _RoleProfileSelector({
    required this.selectedProfile,
    required this.counts,
    required this.onSelect,
  });

  final _RoleProfile? selectedProfile;
  final Map<_RoleProfile, int> counts;
  final ValueChanged<_RoleProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _RoleProfile.values
              .map(
                (profile) => SizedBox(
                  width: width,
                  child: _ProfileCard(
                    profile: profile,
                    count: counts[profile] ?? 0,
                    selected: selectedProfile == profile,
                    onTap: () => onSelect(profile),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AccessToolbar extends StatelessWidget {
  const _AccessToolbar({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final search = TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              labelText: '이름, 로그인, 역할, 부서 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          );
          final status = DropdownButtonFormField<String>(
            initialValue: statusFilter,
            decoration: const InputDecoration(
              labelText: '상태',
              prefixIcon: Icon(Icons.filter_alt_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('전체')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('활성')),
              DropdownMenuItem(value: 'INVITED', child: Text('초대')),
              DropdownMenuItem(value: 'LOCKED', child: Text('잠김')),
              DropdownMenuItem(value: 'INACTIVE', child: Text('중지')),
            ],
            onChanged: (value) {
              if (value != null) {
                onStatusChanged(value);
              }
            },
          );
          if (narrow) {
            return Column(
              children: [search, const SizedBox(height: 10), status],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: status),
            ],
          );
        },
      ),
    );
  }
}

class _UserDirectoryPanel extends StatelessWidget {
  const _UserDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_UserAccessRecord> records;
  final int? selectedId;
  final ValueChanged<_UserAccessRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.people_alt_rounded,
            title: '사용자 디렉터리',
            subtitle: 'app_users / roles / permissions',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
              dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              columns: const [
                DataColumn(label: Text('상태')),
                DataColumn(label: Text('사용자')),
                DataColumn(label: Text('로그인 ID')),
                DataColumn(label: Text('역할')),
                DataColumn(label: Text('부서')),
                DataColumn(label: Text('권한')),
                DataColumn(label: Text('접속')),
              ],
              rows: records
                  .map(
                    (record) => DataRow(
                      selected: record.id == selectedId,
                      onSelectChanged: (_) => onSelect(record),
                      cells: [
                        DataCell(_StatusChip(status: record.status)),
                        DataCell(Text(record.fullName)),
                        DataCell(Text(record.loginId)),
                        DataCell(_ProfilePill(profile: record.profile)),
                        DataCell(Text(record.departmentName)),
                        DataCell(Text('${record.permissions.length}개')),
                        DataCell(Text(record.accessSummary)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserEditorPanel extends StatelessWidget {
  const _UserEditorPanel({
    required this.selectedRecord,
    required this.loginController,
    required this.emailController,
    required this.nameController,
    required this.phoneController,
    required this.mobileController,
    required this.departmentController,
    required this.businessUnitController,
    required this.roleCodeController,
    required this.roleNameController,
    required this.roleDescriptionController,
    required this.dataScopeController,
    required this.expiresAtController,
    required this.memoController,
    required this.selectedProfile,
    required this.selectedStatus,
    required this.selectedPermissions,
    required this.isActive,
    required this.mfaEnabled,
    required this.allowWeb,
    required this.allowMobile,
    required this.requireApproval,
    required this.onProfileChanged,
    required this.onStatusChanged,
    required this.onPermissionChanged,
    required this.onActiveChanged,
    required this.onMfaChanged,
    required this.onWebChanged,
    required this.onMobileChanged,
    required this.onApprovalChanged,
    required this.onSave,
  });

  final _UserAccessRecord? selectedRecord;
  final TextEditingController loginController;
  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController mobileController;
  final TextEditingController departmentController;
  final TextEditingController businessUnitController;
  final TextEditingController roleCodeController;
  final TextEditingController roleNameController;
  final TextEditingController roleDescriptionController;
  final TextEditingController dataScopeController;
  final TextEditingController expiresAtController;
  final TextEditingController memoController;
  final _RoleProfile selectedProfile;
  final _UserStatus selectedStatus;
  final Set<String> selectedPermissions;
  final bool isActive;
  final bool mfaEnabled;
  final bool allowWeb;
  final bool allowMobile;
  final bool requireApproval;
  final ValueChanged<_RoleProfile> onProfileChanged;
  final ValueChanged<_UserStatus> onStatusChanged;
  final void Function(String code, bool selected) onPermissionChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onMfaChanged;
  final ValueChanged<bool> onWebChanged;
  final ValueChanged<bool> onMobileChanged;
  final ValueChanged<bool> onApprovalChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PanelTitle(
                  icon: Icons.manage_accounts_rounded,
                  title: selectedRecord == null ? '신규 사용자 등록' : '사용자 상세',
                  subtitle: selectedRecord?.loginId ?? 'app_users',
                  compact: true,
                ),
              ),
              Switch(value: isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 14),
          _SectionLabel(icon: Icons.person_rounded, label: '사용자 프로필'),
          _EditorGrid(
            children: [
              _AccessTextField(
                controller: loginController,
                label: '로그인 ID',
                icon: Icons.alternate_email_rounded,
              ),
              _AccessTextField(
                controller: emailController,
                label: '이메일',
                icon: Icons.mail_rounded,
              ),
              _AccessTextField(
                controller: nameController,
                label: '사용자명',
                icon: Icons.person_rounded,
              ),
              _AccessTextField(
                controller: mobileController,
                label: '모바일',
                icon: Icons.phone_iphone_rounded,
              ),
              _AccessTextField(
                controller: phoneController,
                label: '전화',
                icon: Icons.call_rounded,
              ),
              _AccessTextField(
                controller: departmentController,
                label: '부서',
                icon: Icons.groups_rounded,
              ),
              _AccessTextField(
                controller: businessUnitController,
                label: 'Business Unit',
                icon: Icons.account_tree_rounded,
              ),
              DropdownButtonFormField<_UserStatus>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: '상태',
                  prefixIcon: Icon(Icons.verified_rounded),
                ),
                items: _UserStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(icon: Icons.admin_panel_settings_rounded, label: '역할'),
          _EditorGrid(
            children: [
              DropdownButtonFormField<_RoleProfile>(
                initialValue: selectedProfile,
                decoration: const InputDecoration(
                  labelText: '권한 프로필',
                  prefixIcon: Icon(Icons.security_rounded),
                ),
                items: _RoleProfile.values
                    .map(
                      (profile) => DropdownMenuItem(
                        value: profile,
                        child: Text(profile.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onProfileChanged(value);
                  }
                },
              ),
              _AccessTextField(
                controller: roleCodeController,
                label: '역할 코드',
                icon: Icons.key_rounded,
              ),
              _AccessTextField(
                controller: roleNameController,
                label: '역할명',
                icon: Icons.badge_rounded,
              ),
              _AccessTextField(
                controller: dataScopeController,
                label: '데이터 범위',
                icon: Icons.hub_rounded,
              ),
              _AccessTextField(
                controller: expiresAtController,
                label: '권한 만료일',
                icon: Icons.event_busy_rounded,
              ),
              _AccessTextField(
                controller: roleDescriptionController,
                label: '역할 설명',
                icon: Icons.description_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AccessSwitchTile(
            label: 'MFA 필수',
            value: mfaEnabled,
            onChanged: onMfaChanged,
            icon: Icons.enhanced_encryption_rounded,
          ),
          _AccessSwitchTile(
            label: '웹 접속 허용',
            value: allowWeb,
            onChanged: onWebChanged,
            icon: Icons.language_rounded,
          ),
          _AccessSwitchTile(
            label: '모바일 앱 허용',
            value: allowMobile,
            onChanged: onMobileChanged,
            icon: Icons.phone_android_rounded,
          ),
          _AccessSwitchTile(
            label: '승인 후 활성화',
            value: requireApproval,
            onChanged: onApprovalChanged,
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 16),
          _SectionLabel(icon: Icons.rule_rounded, label: '권한 매트릭스'),
          _PermissionMatrix(
            selectedPermissions: selectedPermissions,
            onChanged: onPermissionChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: memoController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '운영 메모',
              prefixIcon: Icon(Icons.edit_note_rounded),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_rounded),
            label: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({
    required this.selectedPermissions,
    required this.onChanged,
  });

  final Set<String> selectedPermissions;
  final void Function(String code, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _permissionGroups
          .map(
            (group) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(group.icon, color: group.color, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        group.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.graphite,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: group.permissions
                        .map(
                          (permission) => FilterChip(
                            selected: selectedPermissions.contains(
                              permission.code,
                            ),
                            label: Text(permission.label),
                            avatar: Icon(permission.icon, size: 17),
                            onSelected: (selected) =>
                                onChanged(permission.code, selected),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _RoleProfile profile;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? profile.color.withValues(alpha: 0.09)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? profile.color : AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: profile.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(profile.icon, color: profile.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: profile.color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED), size: compact ? 20 : 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorGrid extends StatelessWidget {
  const _EditorGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _AccessTextField extends StatelessWidget {
  const _AccessTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _AccessSwitchTile extends StatelessWidget {
  const _AccessSwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? const Color(0xFF7C3AED) : AppTheme.slate,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AccessMetricCard extends StatelessWidget {
  const _AccessMetricCard(this.metric);

  final _AccessMetric metric;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.profile});

  final _RoleProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: profile.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        profile.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: profile.color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _UserStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: status.color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

enum _RoleProfile {
  admin,
  manager,
  operator,
  settlement;

  String get label => switch (this) {
    _RoleProfile.admin => '시스템 관리자',
    _RoleProfile.manager => '운영 관리자',
    _RoleProfile.operator => '배차 운영자',
    _RoleProfile.settlement => '정산 담당자',
  };

  String get roleCode => switch (this) {
    _RoleProfile.admin => 'SYS_ADMIN',
    _RoleProfile.manager => 'TMS_MANAGER',
    _RoleProfile.operator => 'DISPATCH_OPERATOR',
    _RoleProfile.settlement => 'SETTLEMENT_STAFF',
  };

  String get roleName => label;

  String get prefix => switch (this) {
    _RoleProfile.admin => 'admin',
    _RoleProfile.manager => 'manager',
    _RoleProfile.operator => 'operator',
    _RoleProfile.settlement => 'settlement',
  };

  String get description => switch (this) {
    _RoleProfile.admin => '시스템 설정과 권한을 포함한 전체 관리',
    _RoleProfile.manager => '운영 현황과 배차, 마스터 관리',
    _RoleProfile.operator => '오더, 편성, 배차, 트래킹 실행',
    _RoleProfile.settlement => '실적 확정, 정산, 거래명세서 관리',
  };

  String get departmentHint => switch (this) {
    _RoleProfile.admin => 'IT운영팀',
    _RoleProfile.manager => '물류운영팀',
    _RoleProfile.operator => '배차관제팀',
    _RoleProfile.settlement => '운임정산팀',
  };

  String get dataScope => switch (this) {
    _RoleProfile.admin => 'ALL',
    _RoleProfile.manager => 'COMPANY',
    _RoleProfile.operator => 'BUSINESS_UNIT',
    _RoleProfile.settlement => 'SETTLEMENT',
  };

  List<String> get defaultPermissions => switch (this) {
    _RoleProfile.admin => _permissionOptions.map((item) => item.code).toList(),
    _RoleProfile.manager => [
      'DASHBOARD.READ',
      'ORDER.READ',
      'ORDER.WRITE',
      'PLANNING.WRITE',
      'DISPATCH.WRITE',
      'TRACKING.READ',
      'MASTER.WRITE',
      'REPORT.READ',
    ],
    _RoleProfile.operator => [
      'DASHBOARD.READ',
      'ORDER.READ',
      'ORDER.WRITE',
      'PLANNING.WRITE',
      'DISPATCH.WRITE',
      'TRACKING.READ',
    ],
    _RoleProfile.settlement => [
      'DASHBOARD.READ',
      'ORDER.READ',
      'SETTLEMENT.APPROVE',
      'INVOICE.WRITE',
      'REPORT.READ',
    ],
  };

  IconData get icon => switch (this) {
    _RoleProfile.admin => Icons.admin_panel_settings_rounded,
    _RoleProfile.manager => Icons.manage_accounts_rounded,
    _RoleProfile.operator => Icons.route_rounded,
    _RoleProfile.settlement => Icons.receipt_long_rounded,
  };

  Color get color => switch (this) {
    _RoleProfile.admin => const Color(0xFF7C3AED),
    _RoleProfile.manager => AppTheme.teal,
    _RoleProfile.operator => const Color(0xFF2563EB),
    _RoleProfile.settlement => AppTheme.amber,
  };
}

enum _UserStatus {
  active,
  invited,
  locked,
  inactive;

  String get label => switch (this) {
    _UserStatus.active => '활성',
    _UserStatus.invited => '초대',
    _UserStatus.locked => '잠김',
    _UserStatus.inactive => '중지',
  };

  String get code => switch (this) {
    _UserStatus.active => 'ACTIVE',
    _UserStatus.invited => 'INVITED',
    _UserStatus.locked => 'LOCKED',
    _UserStatus.inactive => 'INACTIVE',
  };

  Color get color => switch (this) {
    _UserStatus.active => AppTheme.teal,
    _UserStatus.invited => const Color(0xFF2563EB),
    _UserStatus.locked => AppTheme.amber,
    _UserStatus.inactive => const Color(0xFFDC2626),
  };
}

class _PermissionGroup {
  const _PermissionGroup(this.label, this.icon, this.color, this.permissions);

  final String label;
  final IconData icon;
  final Color color;
  final List<_PermissionOption> permissions;
}

class _PermissionOption {
  const _PermissionOption(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;
}

class _AccessMetric {
  const _AccessMetric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _UserAccessRecord {
  const _UserAccessRecord({
    required this.id,
    required this.profile,
    required this.status,
    required this.loginId,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.mobile,
    required this.departmentName,
    required this.businessUnitName,
    required this.roleCode,
    required this.roleName,
    required this.roleDescription,
    required this.dataScope,
    required this.expiresAt,
    required this.permissions,
    required this.isActive,
    required this.mfaEnabled,
    required this.allowWeb,
    required this.allowMobile,
    required this.requireApproval,
    required this.memo,
  });

  final int id;
  final _RoleProfile profile;
  final _UserStatus status;
  final String loginId;
  final String email;
  final String fullName;
  final String phone;
  final String mobile;
  final String departmentName;
  final String businessUnitName;
  final String roleCode;
  final String roleName;
  final String roleDescription;
  final String dataScope;
  final String expiresAt;
  final List<String> permissions;
  final bool isActive;
  final bool mfaEnabled;
  final bool allowWeb;
  final bool allowMobile;
  final bool requireApproval;
  final String memo;

  String get accessSummary {
    final channels = [
      if (allowWeb) 'Web',
      if (allowMobile) 'App',
      if (mfaEnabled) 'MFA',
    ];
    return channels.join(' / ');
  }

  Map<String, Object?> toApiPayload() {
    return {
      'login_id': loginId,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'mobile': mobile,
      'department_name': departmentName,
      'business_unit_name': businessUnitName,
      'language_code': 'ko',
      'timezone_name': 'Asia/Seoul',
      'status': status.code,
      'mfa_enabled': mfaEnabled,
      'is_active': isActive,
      'role_code': roleCode,
      'role_name': roleName,
      'role_description': roleDescription,
      'role_profile': profile.name.toUpperCase(),
      'data_scope': dataScope,
      'permissions': permissions,
      'allow_web': allowWeb,
      'allow_mobile': allowMobile,
      'require_approval': requireApproval,
      'expires_at': expiresAt,
      'memo': memo,
      'metadata': {
        'auth_provider': 'FIREBASE',
        'role_profile': profile.name.toUpperCase(),
        'access_summary': accessSummary,
      },
    };
  }
}

const _permissionOptions = [
  _PermissionOption('DASHBOARD.READ', '대시보드', Icons.dashboard_rounded),
  _PermissionOption('ORDER.READ', '오더 조회', Icons.search_rounded),
  _PermissionOption('ORDER.WRITE', '오더 등록', Icons.add_road_rounded),
  _PermissionOption('PLANNING.WRITE', '편성', Icons.alt_route_rounded),
  _PermissionOption('DISPATCH.WRITE', '배차', Icons.local_shipping_rounded),
  _PermissionOption('TRACKING.READ', '트래킹', Icons.map_rounded),
  _PermissionOption('SETTLEMENT.APPROVE', '정산 확정', Icons.fact_check_rounded),
  _PermissionOption('INVOICE.WRITE', '거래명세서', Icons.receipt_long_rounded),
  _PermissionOption('MASTER.WRITE', '마스터', Icons.dataset_rounded),
  _PermissionOption(
    'USER_ADMIN.WRITE',
    '사용자 권한',
    Icons.admin_panel_settings_rounded,
  ),
  _PermissionOption('REPORT.READ', '리포트', Icons.query_stats_rounded),
  _PermissionOption('SYSTEM.CONFIG', '시스템 설정', Icons.tune_rounded),
];

const _permissionGroups = [
  _PermissionGroup('운영 실행', Icons.route_rounded, Color(0xFF2563EB), [
    _PermissionOption('DASHBOARD.READ', '대시보드', Icons.dashboard_rounded),
    _PermissionOption('ORDER.READ', '오더 조회', Icons.search_rounded),
    _PermissionOption('ORDER.WRITE', '오더 등록', Icons.add_road_rounded),
    _PermissionOption('PLANNING.WRITE', '편성', Icons.alt_route_rounded),
    _PermissionOption('DISPATCH.WRITE', '배차', Icons.local_shipping_rounded),
    _PermissionOption('TRACKING.READ', '트래킹', Icons.map_rounded),
  ]),
  _PermissionGroup('정산/분석', Icons.receipt_long_rounded, AppTheme.amber, [
    _PermissionOption('SETTLEMENT.APPROVE', '정산 확정', Icons.fact_check_rounded),
    _PermissionOption('INVOICE.WRITE', '거래명세서', Icons.receipt_long_rounded),
    _PermissionOption('REPORT.READ', '리포트', Icons.query_stats_rounded),
  ]),
  _PermissionGroup(
    '관리',
    Icons.admin_panel_settings_rounded,
    Color(0xFF7C3AED),
    [
      _PermissionOption('MASTER.WRITE', '마스터', Icons.dataset_rounded),
      _PermissionOption(
        'USER_ADMIN.WRITE',
        '사용자 권한',
        Icons.admin_panel_settings_rounded,
      ),
      _PermissionOption('SYSTEM.CONFIG', '시스템 설정', Icons.tune_rounded),
    ],
  ),
];

const _seedUsers = [
  _UserAccessRecord(
    id: 1,
    profile: _RoleProfile.admin,
    status: _UserStatus.active,
    loginId: 'admin@kcastle.net',
    email: 'admin@kcastle.net',
    fullName: '시스템 관리자',
    phone: '02-0000-1000',
    mobile: '010-0000-1000',
    departmentName: 'IT운영팀',
    businessUnitName: 'KCASTLE 본사',
    roleCode: 'SYS_ADMIN',
    roleName: '시스템 관리자',
    roleDescription: '시스템 설정과 권한을 포함한 전체 관리',
    dataScope: 'ALL',
    expiresAt: '',
    permissions: [
      'DASHBOARD.READ',
      'ORDER.READ',
      'ORDER.WRITE',
      'PLANNING.WRITE',
      'DISPATCH.WRITE',
      'TRACKING.READ',
      'SETTLEMENT.APPROVE',
      'INVOICE.WRITE',
      'MASTER.WRITE',
      'USER_ADMIN.WRITE',
      'REPORT.READ',
      'SYSTEM.CONFIG',
    ],
    isActive: true,
    mfaEnabled: true,
    allowWeb: true,
    allowMobile: false,
    requireApproval: true,
    memo: '초기 시스템 관리자 계정.',
  ),
  _UserAccessRecord(
    id: 2,
    profile: _RoleProfile.operator,
    status: _UserStatus.active,
    loginId: 'dispatcher@kcastle.net',
    email: 'dispatcher@kcastle.net',
    fullName: '배차 운영자',
    phone: '02-0000-2000',
    mobile: '010-0000-2000',
    departmentName: '배차관제팀',
    businessUnitName: 'KCASTLE 본사',
    roleCode: 'DISPATCH_OPERATOR',
    roleName: '배차 운영자',
    roleDescription: '오더, 편성, 배차, 트래킹 실행',
    dataScope: 'BUSINESS_UNIT',
    expiresAt: '',
    permissions: [
      'DASHBOARD.READ',
      'ORDER.READ',
      'ORDER.WRITE',
      'PLANNING.WRITE',
      'DISPATCH.WRITE',
      'TRACKING.READ',
    ],
    isActive: true,
    mfaEnabled: true,
    allowWeb: true,
    allowMobile: true,
    requireApproval: false,
    memo: '수도권 배차 운영 담당.',
  ),
  _UserAccessRecord(
    id: 3,
    profile: _RoleProfile.settlement,
    status: _UserStatus.invited,
    loginId: 'settlement@kcastle.net',
    email: 'settlement@kcastle.net',
    fullName: '정산 담당자',
    phone: '02-0000-3000',
    mobile: '010-0000-3000',
    departmentName: '운임정산팀',
    businessUnitName: 'KCASTLE 본사',
    roleCode: 'SETTLEMENT_STAFF',
    roleName: '정산 담당자',
    roleDescription: '실적 확정, 정산, 거래명세서 관리',
    dataScope: 'SETTLEMENT',
    expiresAt: '',
    permissions: [
      'DASHBOARD.READ',
      'ORDER.READ',
      'SETTLEMENT.APPROVE',
      'INVOICE.WRITE',
      'REPORT.READ',
    ],
    isActive: true,
    mfaEnabled: false,
    allowWeb: true,
    allowMobile: false,
    requireApproval: false,
    memo: 'Firebase 초대 발송 대기.',
  ),
];
