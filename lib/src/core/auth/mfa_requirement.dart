/// The caller's second-factor requirement as returned by the server function
/// `fn_my_mfa_requirement()` (web: `MfaService.getMyRequirement`).
///
/// - [privileged]: platform operator or an active rbac `admin` / `super_admin`
///   role — always required, no tenant policy needed.
/// - [required]: privileged, or the tenant's `mfa_policy` asks for it
///   (`all_members`, or `admins_only` for privileged users).
/// - [allowedFactors]: `totp` and/or `email`; privileged users always get both
///   (the mailed code is the recovery path for a lost authenticator).
/// - [hasVerifiedFactor]: a verified authenticator factor or an active,
///   verified e-mail factor exists.
class MfaRequirement {
  const MfaRequirement({
    required this.privileged,
    required this.required,
    required this.allowedFactors,
    required this.hasVerifiedFactor,
  });

  final bool privileged;
  final bool required;
  final List<String> allowedFactors;
  final bool hasVerifiedFactor;

  bool get allowsEmail => allowedFactors.contains('email');

  /// Parses the RPC payload. Throws [FormatException] when the payload is not
  /// an object — an unreadable requirement must never be read as "not required".
  factory MfaRequirement.fromJson(Object? data) {
    if (data is! Map) {
      throw const FormatException('MFA_REQUIREMENT_UNAVAILABLE');
    }
    final raw = data['allowed_factors'];
    final factors = raw is List
        ? raw.map((e) => e.toString().toLowerCase()).toList()
        : <String>[];
    return MfaRequirement(
      privileged: data['privileged'] == true,
      required: data['required'] == true,
      allowedFactors: factors.isEmpty ? const ['totp'] : factors,
      hasVerifiedFactor: data['has_verified_factor'] == true,
    );
  }

  @override
  String toString() => 'MfaRequirement(privileged: $privileged, '
      'required: $required, allowed: $allowedFactors, '
      'hasVerifiedFactor: $hasVerifiedFactor)';
}
