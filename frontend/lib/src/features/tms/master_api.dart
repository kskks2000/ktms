import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';

class MasterSaveResult {
  const MasterSaveResult({
    required this.persisted,
    required this.skipped,
    required this.message,
  });

  factory MasterSaveResult.persisted([String message = 'saved']) {
    return MasterSaveResult(persisted: true, skipped: false, message: message);
  }

  factory MasterSaveResult.skipped() {
    return const MasterSaveResult(
      persisted: false,
      skipped: true,
      message: 'API base URL is not configured.',
    );
  }

  factory MasterSaveResult.failed(String message) {
    return MasterSaveResult(persisted: false, skipped: false, message: message);
  }

  final bool persisted;
  final bool skipped;
  final String message;

  bool get failed => !persisted && !skipped;
}

class BusinessPartnerOption {
  const BusinessPartnerOption({
    required this.id,
    required this.partnerCode,
    required this.partnerName,
    required this.partnerShortName,
    required this.partnerType,
    required this.status,
    required this.isActive,
    this.paymentTerms,
    this.phone,
    this.email,
  });

  final int id;
  final String partnerCode;
  final String partnerName;
  final String partnerShortName;
  final String partnerType;
  final String status;
  final bool isActive;
  final String? paymentTerms;
  final String? phone;
  final String? email;

  factory BusinessPartnerOption.fromJson(Map<String, dynamic> json) {
    return BusinessPartnerOption(
      id: json['partner_id'] as int? ?? 0,
      partnerCode: json['partner_code']?.toString() ?? '',
      partnerName: json['partner_name']?.toString() ?? '',
      partnerShortName: json['partner_short_name']?.toString() ?? '',
      partnerType: json['partner_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      paymentTerms: json['payment_terms']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }

  String get typeLabel => switch (partnerType) {
    'CUSTOMER' => '고객사',
    'SHIPPER' => '화주',
    'CARRIER' => '운송사',
    _ => partnerType,
  };

  String get displayName {
    if (partnerShortName.trim().isEmpty || partnerShortName == partnerName) {
      return partnerName;
    }
    return '$partnerShortName · $partnerName';
  }
}

class MasterApi {
  const MasterApi();

  static const instance = MasterApi();
  static const _configuredBaseUrl = AppConfig.apiBaseUrl;

  Future<MasterSaveResult> saveBusinessPartner(Map<String, Object?> payload) {
    return _post('/masters/business-partners', payload);
  }

  Future<MasterSaveResult> saveLocation(Map<String, Object?> payload) {
    return _post('/masters/locations', payload);
  }

  Future<MasterSaveResult> saveGeoZone(Map<String, Object?> payload) {
    return _post('/masters/geo-zones', payload);
  }

  Future<MasterSaveResult> saveTransportRoute(Map<String, Object?> payload) {
    return _post('/masters/transport-routes', payload);
  }

  Future<MasterSaveResult> saveVehicle(Map<String, Object?> payload) {
    return _post('/masters/vehicles', payload);
  }

  Future<MasterSaveResult> saveDriver(Map<String, Object?> payload) {
    return _post('/masters/drivers', payload);
  }

  Future<MasterSaveResult> saveItem(Map<String, Object?> payload) {
    return _post('/masters/items', payload);
  }

  Future<MasterSaveResult> saveRateAgreement(Map<String, Object?> payload) {
    return _post('/masters/rate-agreements', payload);
  }

  Future<MasterSaveResult> saveUserAccess(Map<String, Object?> payload) {
    return _post('/masters/user-access', payload);
  }

  Future<MasterSaveResult> saveCommonCode(Map<String, Object?> payload) {
    return _post('/masters/common-codes', payload);
  }

  Future<MasterSaveResult> saveTransportOrder(Map<String, Object?> payload) {
    return _post('/orders/transport-orders', payload);
  }

  Future<MasterSaveResult> saveTrackingPosition(Map<String, Object?> payload) {
    return _post('/tracking/positions', payload);
  }

  Future<MasterSaveResult> confirmCarrierDispatch(
    Map<String, Object?> payload,
  ) {
    return _post('/carrier/dispatch-confirmations', payload);
  }

  Future<List<BusinessPartnerOption>> fetchBusinessPartners({
    String? partnerType,
    String? query,
    int limit = 80,
  }) async {
    final endpoint = _endpoint('/masters/business-partners');
    if (endpoint == null) {
      return const [];
    }

    final uri = endpoint.replace(
      queryParameters: {
        if (partnerType != null && partnerType.trim().isNotEmpty)
          'partner_type': partnerType.trim().toUpperCase(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit.toString(),
      },
    );

    try {
      final response = await http
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawItems = decoded is Map<String, dynamic>
          ? decoded['items']
          : decoded is List<dynamic>
          ? decoded
          : const [];
      if (rawItems is! List) {
        return const [];
      }

      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(BusinessPartnerOption.fromJson)
          .where((item) => item.partnerName.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<MasterSaveResult> _post(
    String path,
    Map<String, Object?> payload,
  ) async {
    final endpoint = _endpoint(path);
    if (endpoint == null) {
      return MasterSaveResult.skipped();
    }

    try {
      final response = await http
          .post(
            endpoint,
            headers: const {
              'content-type': 'application/json; charset=utf-8',
              'accept': 'application/json',
            },
            body: jsonEncode(_stripNulls(payload)),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return MasterSaveResult.persisted(response.body);
      }

      return MasterSaveResult.failed(_errorMessage(response));
    } on TimeoutException {
      return MasterSaveResult.failed('API 응답 시간이 초과되었습니다.');
    } catch (error) {
      return MasterSaveResult.failed(error.toString());
    }
  }

  Uri? _endpoint(String path) {
    final base = _apiBaseUri();
    if (base == null) {
      return null;
    }

    final normalizedBasePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(path: '$normalizedBasePath$normalizedPath');
  }

  Uri? _apiBaseUri() {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return Uri.parse(configured);
    }

    if (kIsWeb && Uri.base.hasAuthority) {
      return Uri(
        scheme: Uri.base.scheme,
        host: Uri.base.host,
        port: Uri.base.port == 0 ? null : Uri.base.port,
        path: '/api',
      );
    }

    return null;
  }

  Map<String, Object?> _stripNulls(Map<String, Object?> payload) {
    return Map<String, Object?>.fromEntries(
      payload.entries.where((entry) => entry.value != null).map((entry) {
        final value = entry.value;
        if (value is Map<String, Object?>) {
          return MapEntry(entry.key, _stripNulls(value));
        }
        return entry;
      }),
    );
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // Fall through to the compact raw response below.
    }

    final raw = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (raw.isEmpty) {
      return 'HTTP ${response.statusCode}';
    }
    return raw.length > 180 ? '${raw.substring(0, 180)}...' : raw;
  }
}
