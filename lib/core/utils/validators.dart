abstract final class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _codeRegex = RegExp(r'^[a-z0-9]{3}-[a-z0-9]{4}-[a-z0-9]{3}$');

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

  static String? password(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Enter a password';
    }
    if (raw.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? fullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter your full name';
    }
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String expectedPassword) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Confirm your password';
    }
    if (raw != expectedPassword) {
      return 'Passwords do not match';
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
    if (!_codeRegex.hasMatch(code)) {
      return 'Enter a valid code (xxx-xxxx-xxx)';
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
