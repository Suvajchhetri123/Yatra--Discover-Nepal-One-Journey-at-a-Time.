/// Temporary compatibility cache for frontend state.
///
/// Firestore is becoming the permanent source of truth for the user profile.
///
/// This store is temporarily retained because some screens such as SOS,
/// bookings, admin and offline access still consume language/emergency-contact
/// values from it.
///
/// TODO: Remove DemoProfileStore after all consumers are migrated to the
/// Firestore-backed profile/repository layer.
class DemoProfileStore {
  DemoProfileStore._();

  static final DemoProfileStore instance = DemoProfileStore._();

  String? name;
  String? phone;

  String? emergencyContactName;
  String? emergencyContactPhone;

  /// Default/profile tourist classification.
  ///
  /// Each trip still stores its own tourist type independently.
  String? touristType;

  String language = 'English';

  void setProfile({String? name, String? phone, bool clearMissing = false}) {
    if (name != null || clearMissing) {
      this.name = name;
    }

    if (phone != null || clearMissing) {
      this.phone = phone;
    }
  }

  void setEmergencyContact({
    String? name,
    String? phone,
    bool clearMissing = false,
  }) {
    if (name != null || clearMissing) {
      emergencyContactName = name;
    }

    if (phone != null || clearMissing) {
      emergencyContactPhone = phone;
    }
  }

  void setTouristType(String? touristType) {
    this.touristType = touristType;
  }

  void setLanguage(String language) {
    this.language = language;
  }

  /// Clears only the local runtime cache.
  ///
  /// This does NOT delete the user's Firestore profile.
  void clear() {
    name = null;
    phone = null;

    emergencyContactName = null;
    emergencyContactPhone = null;

    touristType = null;
    language = 'English';
  }
}
