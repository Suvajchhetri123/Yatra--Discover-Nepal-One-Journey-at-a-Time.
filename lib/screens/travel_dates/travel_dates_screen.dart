import 'package:flutter/material.dart';
import '../travel_group/travel_group_screen.dart';

class TravelDatesScreen extends StatefulWidget {
  const TravelDatesScreen({super.key});

  @override
  State<TravelDatesScreen> createState() => _TravelDatesScreenState();
}

class _TravelDatesScreenState extends State<TravelDatesScreen> {
  DateTime? departureDate;
  DateTime? returnDate;

  Future<void> selectDepartureDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        departureDate = selectedDate;

        if (returnDate != null && returnDate!.isBefore(selectedDate)) {
          returnDate = null;
        }
      });
    }
  }

  Future<void> selectReturnDate() async {
    if (departureDate == null) return;

    final selectedDate = await showDatePicker(
      context: context,
      firstDate: departureDate!,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: departureDate!.add(const Duration(days: 1)),
    );

    if (selectedDate != null) {
      setState(() {
        returnDate = selectedDate;
      });
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    return '${date.day}/${date.month}/${date.year}';
  }

  int? get tripDuration {
    if (departureDate == null || returnDate == null) {
      return null;
    }

    return returnDate!.difference(departureDate!).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Dates'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'When are you travelling?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                'Select your departure and return dates.',
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 35),

              const Text(
                'Departure Date',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: selectDepartureDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    formatDate(departureDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Return Date',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: selectReturnDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    formatDate(returnDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              if (tripDuration != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.deepPurple.withValues(alpha: 0.08),
                    ),
                    child: Text(
                      'Trip Duration: ${tripDuration!} '
                      '${tripDuration == 1 ? 'day' : 'days'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: departureDate != null && returnDate != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TravelGroupScreen(
                                departureDate: departureDate!,
                                returnDate: returnDate!,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
