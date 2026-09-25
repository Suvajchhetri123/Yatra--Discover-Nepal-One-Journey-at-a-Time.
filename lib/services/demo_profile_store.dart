/// A tiny in-memory holder for frontend-only profile state.
///
/// DEMO STATE ONLY — holds what the current app session can support without a
/// backend: a frontend-editable name/phone, the emergency contact used by the
/// SOS screen, and the selected UI language (English / Nepali). None of this
/// is persisted; it will be replaced by the Firebase user profile in the
/// backend phase.
class DemoProfileStore {
  DemoProfileStore._();

  static final DemoProfileStore instance = DemoProfileStore._();

  /// Frontend-edited display name. When null the UI falls back to the
  /// Firebase display name.
  String? name;

  /// Frontend-edited phone. Firebase currently stores no phone, so this is
  /// session-only.
  String? phone;

  /// Emergency contact consumed by the SOS screen.
  String? emergencyContactName;
  String? emergencyContactPhone;

  /// Tourist type chosen while planning (Domestic / International). Read-only
  /// in Profile; it comes from the trip being planned, not from this store.
  String? touristType;

  /// Selected UI language. English until the user picks Nepali.
  String language = 'English';

  void setProfile({String? name, String? phone}) {
    if (name != null) this.name = name;
    if (phone != null) this.phone = phone;
  }

  void setEmergencyContact({String? name, String? phone}) {
    if (name != null) emergencyContactName = name;
    if (phone != null) emergencyContactPhone = phone;
  }

  void setTouristType(String? touristType) {
    this.touristType = touristType;
  }

  void setLanguage(String language) {
    this.language = language;
  }

  /// Resets all demo state. Used by tests and by an explicit demo reset.
  void clear() {
    name = null;
    phone = null;
    emergencyContactName = null;
    emergencyContactPhone = null;
    touristType = null;
    language = 'English';
  }
}
