class SeasonResult {
  final String season;
  final String suitability;
  final String message;

  const SeasonResult({
    required this.season,
    required this.suitability,
    required this.message,
  });
}

class SeasonService {
  static SeasonResult analyze({
    required String destination,
    required DateTime departureDate,
  }) {
    final month = departureDate.month;

    String season;

    if (month >= 3 && month <= 5) {
      season = 'Spring';
    } else if (month >= 6 && month <= 8) {
      season = 'Monsoon';
    } else if (month >= 9 && month <= 11) {
      season = 'Autumn';
    } else {
      season = 'Winter';
    }

    return _analyzeDestination(
      destination: destination,
      season: season,
    );
  }

  static SeasonResult _analyzeDestination({
    required String destination,
    required String season,
  }) {
    switch (destination) {
      case 'Mustang':
        if (season == 'Monsoon') {
          return const SeasonResult(
            season: 'Monsoon',
            suitability: 'Less Suitable',
            message:
                'Monsoon can bring rainfall, difficult road conditions and possible landslides. Travel may require extra planning.',
          );
        }

        if (season == 'Autumn' || season == 'Spring') {
          return SeasonResult(
            season: season,
            suitability: 'Highly Suitable',
            message:
                '$season is generally a favorable period for visiting Mustang.',
          );
        }

        return SeasonResult(
          season: season,
          suitability: 'Moderately Suitable',
          message:
              'Winter can bring colder temperatures and challenging conditions in higher areas. Check local conditions before travelling.',
        );

      case 'Pokhara':
        if (season == 'Monsoon') {
          return const SeasonResult(
            season: 'Monsoon',
            suitability: 'Moderately Suitable',
            message:
                'Rain may affect outdoor activities and visibility. Plan activities with weather conditions in mind.',
          );
        }

        return SeasonResult(
          season: season,
          suitability: 'Suitable',
          message:
              '$season can be a good time to visit Pokhara. Check the weather before outdoor activities.',
        );

      case 'Chitwan':
        if (season == 'Monsoon') {
          return const SeasonResult(
            season: 'Monsoon',
            suitability: 'Moderately Suitable',
            message:
                'Rain can affect outdoor activities and safari conditions.',
          );
        }

        return SeasonResult(
          season: season,
          suitability: 'Suitable',
          message:
              '$season can be a suitable period for visiting Chitwan.',
        );

      case 'Everest':
      case 'Annapurna':
        if (season == 'Monsoon') {
          return const SeasonResult(
            season: 'Monsoon',
            suitability: 'Less Suitable',
            message:
                'Rain, clouds and trail conditions can make trekking more challenging during monsoon.',
          );
        }

        if (season == 'Autumn' || season == 'Spring') {
          return SeasonResult(
            season: season,
            suitability: 'Highly Suitable',
            message:
                '$season is generally a favorable trekking period. Always check current trail and weather conditions.',
          );
        }

        return SeasonResult(
          season: season,
          suitability: 'Moderately Suitable',
          message:
              '$season may bring colder conditions at higher elevations. Preparation and current weather information are important.',
        );

      case 'Kathmandu':
      default:
        return SeasonResult(
          season: season,
          suitability: 'Suitable',
          message:
              '$season can be a suitable time to explore Kathmandu. Check the weather when planning outdoor activities.',
        );
    }
  }
}