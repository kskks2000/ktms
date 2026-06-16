import 'package:flutter/services.dart';

class KtmsNumericInputFormatters {
  const KtmsNumericInputFormatters._();

  static final List<TextInputFormatter> digitsOnly = [
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty || RegExp(r'^\d*$').hasMatch(text)) {
        return newValue;
      }
      return oldValue;
    }),
  ];

  static final List<TextInputFormatter> decimal = [
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty || RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
        return newValue;
      }
      return oldValue;
    }),
  ];

  static final List<TextInputFormatter> signedDecimal = [
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty || RegExp(r'^-?\d*\.?\d*$').hasMatch(text)) {
        return newValue;
      }
      return oldValue;
    }),
  ];

  static List<TextInputFormatter>? forKeyboardType(
    TextInputType? keyboardType, {
    String? label,
  }) {
    if (keyboardType == null) {
      return null;
    }
    if (keyboardType.index == TextInputType.number.index) {
      if (keyboardType.signed == true) {
        return signedDecimal;
      }
      return _allowsDecimal(label) ? decimal : digitsOnly;
    }
    return null;
  }

  static bool _allowsDecimal(String? label) {
    final normalized = label?.toLowerCase() ?? '';
    const decimalKeywords = [
      '%',
      'cbm',
      'cm',
      'kg',
      'km',
      '리드타임',
      '거리',
      '무게',
      '부피',
      '비율',
      '연비',
      '온도',
      '용적',
      '위도',
      '율',
      '중량',
      '좌표',
      '체적',
      '할증',
    ];
    return decimalKeywords.any(normalized.contains);
  }
}
