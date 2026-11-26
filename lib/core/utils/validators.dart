abstract final class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _codeRegex = RegExp(r'^[a-z0-9]{3,}(-[a-z0-9]{2,})*$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter an email address';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String extractMeetingCode(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => trimmed,
      );
    }
    return trimmed.replaceAll(' ', '');
  }

  static String? meetingCode(String? value) {
    final code = extractMeetingCode(value ?? '');
    if (code.isEmpty) {
      return 'Enter a meeting code or link';
    }
    if (code.length < 6 || !_codeRegex.hasMatch(code)) {
      return 'Enter a valid code (e.g. abc-defg-hij)';
    }
    return null;
  }

  static String? requiredField(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }
}
