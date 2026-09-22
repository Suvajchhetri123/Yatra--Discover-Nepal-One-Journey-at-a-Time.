/// A per-stop plan describing how many days the traveller wants to stay and
/// explore at an intermediate (or final) route location.
class JourneyStopPlan {
  /// Canonical location name, e.g. `Jomsom` or `Kagbeni`.
  final String location;

  /// Number of days the traveller wants to stay / explore at [location].
  final int explorationDays;

  const JourneyStopPlan({
    required this.location,
    required this.explorationDays,
  });
}
