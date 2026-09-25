/// Lightweight localization preparation for Yatra.
///
/// This is NOT a full app translation yet. It establishes the structure the
/// backend/localization phase will build on:
///
///  * a canonical list of supported languages (English + Nepali),
///  * a single lookup table for the NEW frontend feature strings,
///  * a helper ([AppStrings.tr]) that falls back to English.
///
/// No Flutter localization dependency is introduced yet — the app uses vanilla
/// widgets, so strings are resolved at build time from the currently selected
/// language in DemoProfileStore.
///
/// Full Nepali translation of every existing screen is intentionally NOT
/// claimed in this phase. Only the new frontend feature strings are
/// centralized here.
abstract final class AppStrings {
  AppStrings._();

  static const List<String> supportedLanguages = ['English', 'नेपाली'];

  /// Returns the string for [key] in [language], falling back to English for
  /// unknown keys or languages.
  static String tr(String language, String key) {
    final table = _entries[key];

    if (table == null) return key;

    if (language == 'नेपाली') {
      return table['ne'] ?? table['en'] ?? key;
    }

    return table['en'] ?? key;
  }

  static const Map<String, Map<String, String>> _entries = {
    // Home quick access
    'home.planTrip': {'en': 'Plan Trip', 'ne': 'यात्रा योजना'},
    'home.myBookings': {'en': 'My Bookings', 'ne': 'मेरा बुकिङहरू'},
    'home.sos': {'en': 'SOS', 'ne': 'आपतकाल'},
    'home.offline': {'en': 'Offline', 'ne': 'अफलाइन'},

    // My Bookings
    'bookings.title': {'en': 'My Bookings', 'ne': 'मेरा बुकिङहरू'},
    'bookings.emptyTitle': {'en': 'No bookings yet', 'ne': 'कुनै बुकिङ छैन'},
    'bookings.emptyHint': {
      'en': 'Your booked itineraries will appear here.',
      'ne': 'तपाईंका बुक गरिएका यात्रा योजनाहरू यहाँ देखिनेछन्।',
    },
    'bookings.planTripCta': {
      'en': 'Plan a Trip',
      'ne': 'यात्रा योजना बनाउनुहोस्',
    },

    // Booking details
    'bookings.detailsTitle': {'en': 'Booking Details', 'ne': 'बुकिङ विवरण'},
    'bookings.coordinator': {
      'en': 'Travel Coordinator',
      'ne': 'ट्राभल कोर्डिनेटर',
    },
    'bookings.coordinatorNotAssigned': {
      'en': 'Not assigned yet.',
      'ne': 'अझै तोकिएको छैन।',
    },
    'bookings.coordinatorPending': {
      'en': 'Contact information will appear after your booking is reviewed.',
      'ne': 'तपाईंको बुकिङ समीक्षा पछि सम्पर्क जानकारी देखिनेछ।',
    },

    // Admin
    'admin.title': {'en': 'Admin Frontend', 'ne': 'प्रशासक'},
    'admin.dashboard': {'en': 'Dashboard', 'ne': 'ड्यासबोर्ड'},
    'admin.bookings': {'en': 'Booking Requests', 'ne': 'बुकिङ अनुरोधहरू'},

    // SOS
    'sos.title': {'en': 'Emergency Assistance', 'ne': 'आपतकालीन सहायता'},

    // Offline
    'offline.title': {'en': 'Offline Access', 'ne': 'अफलाइन पहुँच'},

    // Profile
    'profile.title': {'en': 'Profile', 'ne': 'प्रोफाइल'},
    'profile.logout': {'en': 'Logout', 'ne': 'लगआउट'},
  };
}
