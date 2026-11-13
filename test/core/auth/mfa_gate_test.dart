import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Configurable [MfaGateBackend] double.
class FakeMfaBackend implements MfaGateBackend {
  FakeMfaBackend({
    this.requirement,
    this.requirementError,
    this.aal = 'aal1',
    this.emailOk = false,
    this.totpId,
    this.emailEnabled = false,
  });

  MfaRequirement? requirement;
  Object? requirementError;
  String? aal;
  bool emailOk;
  String? totpId;
  bool emailEnabled;
  int requirementCalls = 0;

  @override
  Future<MfaRequirement> myRequirement() async {
    requirementCalls++;
    if (requirementError != null) throw requirementError!;
    return requirement!;
  }

  @override
  Future<String?> currentAal() async => aal;

  @override
  Future<bool> emailSatisfied() async => emailOk;

  @override
  Future<String?> verifiedTotpFactorId() async => totpId;

  @override
  Future<bool> emailFactorEnabled() async => emailEnabled;
}

MfaRequirement req({
  bool privileged = false,
  bool required = false,
  bool hasFactor = false,
  List<String> factors = const ['totp'],
}) =>
    MfaRequirement(
      privileged: privileged,
      required: required,
      allowedFactors: factors,
      hasVerifiedFactor: hasFactor,
    );

MfaRequirement admin({bool hasFactor = false}) => req(
    privileged: true,
    required: true,
    hasFactor: hasFactor,
    factors: const ['email', 'totp']);

void main() {
  final gate = MfaGate.instance;

  setUp(gate.clear);

  group('MfaRequirement.fromJson (fn_my_mfa_requirement payload)', () {
    test('parses the server object', () {
      final r = MfaRequirement.fromJson({
        'privileged': true,
        'required': true,
        'allowed_factors': ['email', 'totp'],
        'has_verified_factor': false,
      });
      expect(r.privileged, isTrue);
      expect(r.required, isTrue);
      expect(r.allowsEmail, isTrue);
      expect(r.hasVerifiedFactor, isFalse);
    });

    test('missing factors default to totp only', () {
      final r = MfaRequirement.fromJson({'required': false});
      expect(r.allowedFactors, ['totp']);
      expect(r.required, isFalse);
    });

    test('a non-object payload throws (never read as "not required")', () {
      expect(() => MfaRequirement.fromJson(null), throwsFormatException);
      expect(() => MfaRequirement.fromJson('x'), throwsFormatException);
    });
  });

  group('MfaGate.evaluate — outcomes', () {
    test('administrator without a tenant policy and no factor → enrolment',
        () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(requirement: admin()));
      expect(gate.state, MfaStepUp.enroll);
      expect(gate.privileged, isTrue);
      expect(gate.policyAllowsEmail, isTrue);
      expect(gate.redirectFor('/main'), '/mfa-gate');
    });

    test('administrator with an authenticator, aal1 session → challenge',
        () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(
              requirement: admin(hasFactor: true), totpId: 'factor-1'));
      expect(gate.state, MfaStepUp.challenge);
      expect(gate.challengeFactorId, 'factor-1');
    });

    test('administrator with only the e-mail factor → e-mail challenge',
        () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(
              requirement: admin(hasFactor: true), emailEnabled: true));
      expect(gate.state, MfaStepUp.emailChallenge);
    });

    test('administrator, unknown aal → still challenged (fail closed)',
        () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(
              requirement: admin(hasFactor: true), aal: null, totpId: 'f'));
      expect(gate.state, MfaStepUp.challenge);
    });

    test('aal2 session → none', () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(
              requirement: admin(hasFactor: true), aal: 'aal2', totpId: 'f'));
      expect(gate.state, MfaStepUp.none);
      expect(gate.redirectFor('/main'), isNull);
    });

    test('mailed code already passed for this session → none', () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(
              requirement: admin(hasFactor: true), emailOk: true));
      expect(gate.state, MfaStepUp.none);
    });

    test('ordinary member, no tenant policy → none', () async {
      await gate.evaluate(
          role: CoarseRoles.user, backend: FakeMfaBackend(requirement: req()));
      expect(gate.state, MfaStepUp.none);
    });

    test('member of a tenant with all_members policy → challenge', () async {
      await gate.evaluate(
          role: CoarseRoles.user,
          backend: FakeMfaBackend(
              requirement: req(required: true, hasFactor: true), totpId: 't'));
      expect(gate.state, MfaStepUp.challenge);
      expect(gate.privileged, isFalse);
    });

    test('member (tenant policy), unknown aal → none (historical fail-open)',
        () async {
      await gate.evaluate(
          role: CoarseRoles.user,
          backend: FakeMfaBackend(
              requirement: req(required: true, hasFactor: true),
              aal: null,
              totpId: 't'));
      expect(gate.state, MfaStepUp.none);
    });

    test('the server says privileged even if the local role is not admin',
        () async {
      // Platform operators may carry a non-admin coarse role.
      await gate.evaluate(
          role: CoarseRoles.user,
          backend: FakeMfaBackend(requirement: admin()));
      expect(gate.state, MfaStepUp.enroll);
    });
  });

  group('MfaGate.evaluate — requirement cannot be read', () {
    test('administrator → unavailable (retry state), never a silent pass',
        () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(requirementError: Exception('network')));
      expect(gate.state, MfaStepUp.unavailable);
      expect(gate.redirectFor('/main'), '/mfa-gate');
    });

    test('ordinary member → none (fail open)', () async {
      await gate.evaluate(
          role: CoarseRoles.user,
          backend: FakeMfaBackend(requirementError: Exception('network')));
      expect(gate.state, MfaStepUp.none);
    });

    test('malformed payload for an administrator → unavailable', () async {
      await gate.evaluate(
          role: CoarseRoles.admin,
          backend: FakeMfaBackend(
              requirementError: const FormatException('bad payload')));
      expect(gate.state, MfaStepUp.unavailable);
    });

    test('retry re-reads with the same role and clears once it succeeds',
        () async {
      final backend = FakeMfaBackend(requirementError: Exception('timeout'));
      await gate.evaluate(role: CoarseRoles.admin, backend: backend);
      expect(gate.state, MfaStepUp.unavailable);

      backend
        ..requirementError = null
        ..requirement = admin(hasFactor: true)
        ..totpId = 'f';
      await gate.retry(backend: backend);
      expect(backend.requirementCalls, 2);
      expect(gate.state, MfaStepUp.challenge);
    });
  });
}
