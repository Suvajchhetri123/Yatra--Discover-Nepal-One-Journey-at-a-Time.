import 'package:flutter/material.dart';
import '../destination/destination_screen.dart';

class TransportationScreen extends StatefulWidget {
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;
  final DateTime departureDate;
  final DateTime returnDate;

  const TransportationScreen({
    super.key,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.travelType,
    required this.groupSize,
    required this.departureDate,
    required this.returnDate,
  });

  @override
  State<TransportationScreen> createState() => _TransportationScreenState();
}

class _TransportationScreenState extends State<TransportationScreen> {
  String? selectedTransportation;

  final List<Map<String, dynamic>> options = [
    {
      'name': 'Bus',
      'icon': Icons.directions_bus,
      'description': 'Budget-friendly and widely available',
      'details': 'Best choice for economical travel',
    },
    {
      'name': 'Private Vehicle',
      'icon': Icons.directions_car,
      'description': 'Comfortable and flexible',
      'details': 'Suitable for families and groups',
    },
    {
      'name': 'Jeep',
      'icon': Icons.directions_car_filled,
      'description': 'Suitable for mountain roads',
      'details': 'Recommended for remote destinations',
    },
    {
      'name': 'Motorbike',
      'icon': Icons.two_wheeler,
      'description': 'Flexible for short and scenic routes',
      'details': 'Best suited for experienced riders',
    },
    {
      'name': 'Flight',
      'icon': Icons.flight,
      'description': 'Fastest travel option',
      'details': 'Usually costs more than road travel',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transportation'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How would you like to travel?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                'Choose the transportation option that '
                'best matches your budget and comfort.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),

              const SizedBox(height: 25),

              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final name = option['name'] as String;

                    final selected = selectedTransportation == name;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTransportation = name;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                            color: selected
                                ? Colors.deepPurple.withValues(alpha: 0.05)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: selected
                                      ? Colors.deepPurple
                                      : Colors.grey.shade100,
                                ),
                                child: Icon(
                                  option['icon'] as IconData,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  size: 28,
                                ),
                              ),

                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      option['description'] as String,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      option['details'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: selected
                                    ? Colors.deepPurple
                                    : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: selectedTransportation == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationScreen(
                                currency: widget.currency,
                                budget: widget.budget,
                                ages: widget.ages,
                                travelType: widget.travelType,
                                groupSize: widget.groupSize,
                                departureDate: widget.departureDate,
                                returnDate: widget.returnDate,
                              ),
                            ),
                          );
                        },
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
