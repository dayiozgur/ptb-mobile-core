/// Form doğrulama yardımcıları
///
/// Form alanları için standart doğrulama fonksiyonları.
/// TextFormField validator parametresiyle kullanılabilir.
class Validators {
  Validators._();

  // ============================================
  // EMAIL
  // ============================================

  /// Email doğrulama (doğrudan validator olarak kullanılabilir)
  static String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email adresi gerekli';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Geçerli bir email adresi girin';
    }

    return null;
  }

  /// Email doğrulama (factory - özel mesaj ile)
  static String? Function(String?) email([String? errorMessage]) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return errorMessage ?? 'Email adresi gerekli';
      }

      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );

      if (!emailRegex.hasMatch(value)) {
        return errorMessage ?? 'Geçerli bir email adresi girin';
      }

      return null;
    };
  }

  // ============================================
  // PASSWORD
  // ============================================

  /// Şifre doğrulama (factory - validator fonksiyonu döndürür)
  ///
  /// [minLength] - Minimum karakter sayısı (varsayılan: 8)
  /// [requireNumber] - Rakam gerekli mi (varsayılan: true)
  /// [requireSpecialChar] - Özel karakter gerekli mi (varsayılan: true)
  /// [requireUppercase] - Büyük harf gerekli mi (varsayılan: true)
  /// [requireLowercase] - Küçük harf gerekli mi (varsayılan: true)
  static String? Function(String?) password({
    int minLength = 8,
    bool requireNumber = true,
    bool requireSpecialChar = true,
    bool requireUppercase = true,
    bool requireLowercase = true,
  }) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Şifre gerekli';
      }

      if (value.length < minLength) {
        return 'Şifre en az $minLength karakter olmalı';
      }

      if (requireNumber && !RegExp(r'[0-9]').hasMatch(value)) {
        return 'Şifre en az bir rakam içermeli';
      }

      if (requireSpecialChar &&
          !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
        return 'Şifre en az bir özel karakter içermeli';
      }

      if (requireUppercase && !RegExp(r'[A-Z]').hasMatch(value)) {
        return 'Şifre en az bir büyük harf içermeli';
      }

      if (requireLowercase && !RegExp(r'[a-z]').hasMatch(value)) {
        return 'Şifre en az bir küçük harf içermeli';
      }

      return null;
    };
  }

  /// Basit şifre doğrulama (sadece minimum uzunluk)
  static String? Function(String?) passwordSimple({int minLength = 6}) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Şifre gerekli';
      }

      if (value.length < minLength) {
        return 'Şifre en az $minLength karakter olmalı';
      }

      return null;
    };
  }

  /// Şifre eşleştirme doğrulama
  static String? Function(String?) passwordMatch(String password) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Şifre tekrarı gerekli';
      }

      if (value != password) {
        return 'Şifreler eşleşmiyor';
      }

      return null;
    };
  }

  // ============================================
  // REQUIRED
  // ============================================

  /// Zorunlu alan doğrulama (factory - validator fonksiyonu döndürür)
  static String? Function(String?) required([String? errorMessage]) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return errorMessage ?? 'Bu alan gerekli';
      }
      return null;
    };
  }

  /// Zorunlu alan doğrulama (doğrudan kullanım)
  static String? requiredField(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName gerekli' : 'Bu alan gerekli';
    }
    return null;
  }

  // ============================================
  // LENGTH
  // ============================================

  /// Minimum uzunluk doğrulama
  static String? Function(String?) minLength(int length, {String? fieldName}) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null; // required ile birlikte kullanılmalı
      }

      if (value.length < length) {
        final name = fieldName ?? 'Bu alan';
        return '$name en az $length karakter olmalı';
      }

      return null;
    };
  }

  /// Maksimum uzunluk doğrulama
  static String? Function(String?) maxLength(int length, {String? fieldName}) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }

      if (value.length > length) {
        final name = fieldName ?? 'Bu alan';
        return '$name en fazla $length karakter olabilir';
      }

      return null;
    };
  }

  /// Uzunluk aralığı doğrulama
  static String? Function(String?) lengthRange(
    int min,
    int max, {
    String? fieldName,
  }) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }

      final name = fieldName ?? 'Bu alan';

      if (value.length < min) {
        return '$name en az $min karakter olmalı';
      }

      if (value.length > max) {
        return '$name en fazla $max karakter olabilir';
      }

      return null;
    };
  }

  // ============================================
  // PHONE
  // ============================================

  /// Telefon numarası doğrulama (Türkiye formatı)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Telefon numarası gerekli';
    }

    // Sadece rakamları al
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Türkiye telefon numarası: 10 veya 11 haneli
    if (digits.length < 10 || digits.length > 11) {
      return 'Geçerli bir telefon numarası girin';
    }

    return null;
  }

  /// Uluslararası telefon numarası doğrulama
  static String? phoneInternational(String? value) {
    if (value == null || value.isEmpty) {
      return 'Telefon numarası gerekli';
    }

    final phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}$');
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');

    if (!phoneRegex.hasMatch(digits)) {
      return 'Geçerli bir telefon numarası girin';
    }

    return null;
  }

  // ============================================
  // URL
  // ============================================

  /// URL doğrulama
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL gerekli';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Geçerli bir URL girin';
    }

    return null;
  }

  // ============================================
  // NUMERIC
  // ============================================

  /// Sayı doğrulama
  static String? numeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (double.tryParse(value) == null) {
      final name = fieldName ?? 'Bu alan';
      return '$name sayı olmalı';
    }

    return null;
  }

  /// Tam sayı doğrulama
  static String? integer(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (int.tryParse(value) == null) {
      final name = fieldName ?? 'Bu alan';
      return '$name tam sayı olmalı';
    }

    return null;
  }

  /// Minimum değer doğrulama
  static String? Function(String?) minValue(num min, {String? fieldName}) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }

      final number = num.tryParse(value);
      if (number == null) {
        return 'Geçerli bir sayı girin';
      }

      if (number < min) {
        final name = fieldName ?? 'Değer';
        return '$name en az $min olmalı';
      }

      return null;
    };
  }

  /// Maksimum değer doğrulama
  static String? Function(String?) maxValue(num max, {String? fieldName}) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }

      final number = num.tryParse(value);
      if (number == null) {
        return 'Geçerli bir sayı girin';
      }

      if (number > max) {
        final name = fieldName ?? 'Değer';
        return '$name en fazla $max olabilir';
      }

      return null;
    };
  }

  // ============================================
  // CUSTOM
  // ============================================

  /// Regex ile özel doğrulama
  static String? Function(String?) regex(
    String pattern, {
    String? errorMessage,
  }) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }

      if (!RegExp(pattern).hasMatch(value)) {
        return errorMessage ?? 'Geçersiz format';
      }

      return null;
    };
  }

  /// Birden fazla validator birleştirme
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }
}
