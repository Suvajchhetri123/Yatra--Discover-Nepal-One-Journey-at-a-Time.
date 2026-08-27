class TravelPlan {
  int? availableDays;

  DateTime? departureDate;
  DateTime? returnDate;

  int? age;

  String? travelType;
  int groupSize = 1;

  String? currency;
  double? budget;

  String? transportation;
  String? destination;

  String? season;
  String? suitability;
  String? seasonMessage;

  TravelPlan({
    this.availableDays,
    this.departureDate,
    this.returnDate,
    this.age,
    this.travelType,
    this.groupSize = 1,
    this.currency,
    this.budget,
    this.transportation,
    this.destination,
    this.season,
    this.suitability,
    this.seasonMessage,
  });

  int? get tripDuration {
    if (departureDate == null || returnDate == null) {
      return availableDays;
    }

    return returnDate!.difference(departureDate!).inDays;
  }
}
