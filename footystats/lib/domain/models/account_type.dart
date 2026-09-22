/// Signed-in account kinds stored on `players.account_type`.
enum AccountType {
  player,
  technicalStaff;

  static AccountType fromDb(String? raw) {
    if (raw == 'technical_staff') return AccountType.technicalStaff;
    return AccountType.player;
  }

  String get dbValue => switch (this) {
    AccountType.player => 'player',
    AccountType.technicalStaff => 'technical_staff',
  };
}

/// Technical-staff specialisation stored on `players.staff_role`.
enum StaffRole {
  coach,
  scout,
  agent,
  other;

  static const labels = <StaffRole, String>{
    StaffRole.coach: 'Coach',
    StaffRole.scout: 'Scout',
    StaffRole.agent: 'Agent',
    StaffRole.other: 'Other',
  };

  static StaffRole? fromDb(String? raw) {
    return switch (raw) {
      'coach' => StaffRole.coach,
      'scout' => StaffRole.scout,
      'agent' => StaffRole.agent,
      'other' => StaffRole.other,
      _ => null,
    };
  }

  String get dbValue => name;

  String get label => labels[this] ?? name;
}
