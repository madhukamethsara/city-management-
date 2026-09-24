/// A small, replaceable translation catalogue. English is the initial product
/// language; Sinhala and Tamil keys can be completed without rewriting UI code.
class AppCopy {
  AppCopy._();

  static const Map<String, Map<String, String>> _catalogue = {
    'en': {
      'appName': 'Smart Sabha',
      'tagline': 'Connecting Communities. Building Better Local Government.',
      'home': 'Home',
      'explore': 'Explore',
      'report': 'Report',
      'projects': 'Projects',
      'notifications': 'Notifications',
      'profile': 'Profile',
      'save': 'Save',
      'cancel': 'Cancel',
      'continue': 'Continue',
      'back': 'Back',
      'search': 'Search',
      'viewAll': 'View all',
      'submit': 'Submit',
      'close': 'Close',
    },
    'si': {
      'appName': 'ස්මාර්ට් සභා',
      'home': 'මුල් පිටුව',
      'projects': 'ව්‍යාපෘති',
      'report': 'වාර්තා කරන්න',
      'notifications': 'දැනුම්දීම්',
      'profile': 'පැතිකඩ',
    },
    'ta': {
      'appName': 'ஸ்மார்ட் சபா',
      'home': 'முகப்பு',
      'projects': 'திட்டங்கள்',
      'report': 'புகாரளி',
      'notifications': 'அறிவிப்புகள்',
      'profile': 'சுயவிவரம்',
    },
  };

  static String text(String key, {String locale = 'en'}) {
    return _catalogue[locale]?[key] ?? _catalogue['en']?[key] ?? key;
  }
}
