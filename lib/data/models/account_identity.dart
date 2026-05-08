class AccountIdentity {
  const AccountIdentity({
    required this.isConfigured,
    required this.isAnonymous,
    this.email,
    this.emailConfirmedAt,
  });

  final bool isConfigured;
  final bool isAnonymous;
  final String? email;
  final String? emailConfirmedAt;

  bool get hasEmail => email != null && email!.isNotEmpty;
  bool get isEmailConfirmed =>
      emailConfirmedAt != null && emailConfirmedAt!.isNotEmpty;
  bool get isRecoverable => !isAnonymous && hasEmail && isEmailConfirmed;
}
