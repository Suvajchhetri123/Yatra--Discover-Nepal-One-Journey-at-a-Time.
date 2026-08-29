import 'package:flutter/material.dart';

import '../boarding/boarding_screen.dart';

class TransportationScreen extends StatefulWidget {
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String season;
  final String suitability;
  final String seasonMessage;
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;

  const TransportationScreen({
    super.key,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.season,
    required this.suitability,
    required this.seasonMessage,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.travelType,
    required this.groupSize,
  });

  @override
  State<TransportationScreen> createState() =>
      _TransportationScreenState();
}

class _TransportationScreenState
    extends State<TransportationScreen> {
  String? selectedTransportation;

  List<Map<String, dynamic>> get options {
    final destination = widget.destination.toLowerCase();

    if (destination.contains('everest')) {
      return [
        {
          'name': 'Flight',
          'icon': Icons.flight,
          'description': 'Flight to Lukla is the usual starting option',
          'details': 'Available for the Everest trekking route',
          'available': true,
        },
        {
          'name': 'Jeep',
          'icon': Icons.directions_car_filled,
          'description': 'Useful for road sections of the journey',
          'details': 'Available on selected routes toward the Everest region',
          'available': true,
        },
        {
          'name': 'Bus',
          'icon': Icons.directions_bus,
          'description': 'Available for road sections',
          'details': 'Usually combined with other transportation',
          'available': true,
        },
        {
          'name': 'Motorbike',
          'icon': Icons.two_wheeler,
          'description': 'Possible on accessible road sections',
          'details': 'Not suitable for the trekking sections',
          'available': true,
        },
        {
          'name': 'Private Vehicle',
          'icon': Icons.directions_car,
          'description': 'Available for accessible road sections',
          'details': 'Does not replace the trekking portion',
          'available': true,
        },
      ];
    }

    if (destination.contains('mustang')) {
      return [
        {
          'name': 'Jeep',
          'icon': Icons.directions_car_filled,
          'description': 'Common option for Mustang mountain roads',
          'details': 'Recommended for remote and rough road sections',
          'available': true,
        },
        {
          'name': 'Bus',
          'icon': Icons.directions_bus,
          'description': 'Available on major road sections',
          'details': 'Budget-friendly option where routes are available',
          'available': true,
        },
        {
          'name': 'Flight',
          'icon': Icons.flight,
          'description': 'Flights are available to Jomsom',
          'details': 'Useful for reducing road travel time',
          'available': true,
        },
        {
          'name': 'Motorbike',
          'icon': Icons.two_wheeler,
          'description': 'Possible for experienced riders',
          'details': 'Mountain roads require extra caution',
          'available': true,
        },
        {
          'name': 'Private Vehicle',
          'icon': Icons.directions_car,
          'description': 'Comfortable option for road travel',
          'details': 'Suitable for families and groups',
          'available': true,
        },
      ];
    }

    if (destination.contains('annapurna')) {
      return [
        {
          'name': 'Bus',
          'icon': Icons.directions_bus,
          'description': 'Available for major road sections',
          'details': 'Often combined with trekking',
          'available': true,
        },
        {
          'name': 'Jeep',
          'icon': Icons.directions_car_filled,
          'description': 'Useful for mountain road sections',
          'details': 'Common for reaching trekking starting points',
          'available': true,
        },
        {
          'name': 'Private Vehicle',
          'icon': Icons.directions_car,
          'description': 'Comfortable for road sections',
          'details': 'Suitable for families and groups',
          'available': true,
        },
        {
          'name': 'Motorbike',
          'icon': Icons.two_wheeler,
          'description': 'Possible on accessible roads',
          'details': 'Recommended for experienced riders',
          'available': true,
        },
      ];
    }

    if (destination.contains('pokhara')) {
      return [
        {
          'name': 'Bus',
          'icon': Icons.directions_bus,
          'description': 'Widely available from Kathmandu',
          'details': 'Budget-friendly option',
          'available': true,
        },
        {
          'name': 'Flight',
          'icon': Icons.flight,
          'description': 'Fastest option from Kathmandu',
          'details': 'Useful when time is limited',
          'available': true,
        },
        {
          'name': 'Private Vehicle',
          'icon': Icons.directions_car,
          'description': 'Comfortable and flexible',
          'details': 'Good for families and groups',
          'available': true,
        },
        {
          'name': 'Motorbike',
          'icon': Icons.two_wheeler,
          'description': 'Suitable for experienced riders',
          'details': 'Scenic road journey',
          'available': true,
        },
      ];
    }

    if (destination.contains('chitwan')) {
      return [
        {
          'name': 'Bus',
          'icon': Icons.directions_bus,
          'description': 'Widely available road connection',
          'details': 'Budget-friendly option',
          'available': true,
        },
        {
          'name': 'Flight',
          'icon': Icons.flight,
          'description': 'Flights are available to Bharatpur',
          'details': 'Useful for faster travel',
          'available': true,
        },
        {
          'name': 'Private Vehicle',
          'icon': Icons.directions_car,
          'description': 'Comfortable road travel',
          'details': 'Suitable for families and groups',
          'available': true,
        },
        {
          'name': 'Motorbike',
          'icon': Icons.two_wheeler,
          'description': 'Possible by road',
          'details': 'Suitable for experienced riders',
          'available': true,
        },
      ];
    }

    return [
      {
        'name': 'Bus',
        'icon': Icons.directions_bus,
        'description': 'Widely available road transportation',
        'details': 'Budget-friendly option',
        'available': true,
      },
      {
        'name': 'Flight',
        'icon': Icons.flight,
        'description': 'Available for major domestic routes',
        'details': 'Fastest option for suitable destinations',
        'available': true,
      },
      {
        'name': 'Private Vehicle',
        'icon': Icons.directions_car,
        'description': 'Comfortable and flexible',
        'details': 'Suitable for families and groups',
        'available': true,
      },
      {
        'name': 'Motorbike',
        'icon': Icons.two_wheeler,
        'description': 'Available for road travel',
        'details': 'Best suited for experienced riders',
        'available': true,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transportation'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How will you travel to ${widget.destination}?',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Choose from transportation options available '
                'for your selected destination.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.deepPurple.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Destination: ${widget.destination}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];

                    final String name =
                        option['name'] as String;

                    final bool selected =
                        selectedTransportation == name;

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTransportation = name;
                          });
                        },
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                            color: selected
                                ? Colors.deepPurple
                                    .withValues(alpha: 0.05)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(15),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style:
                                                const TextStyle(
                                              fontSize: 18,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(8),
                                            color: Colors.green
                                                .withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                          child: const Text(
                                            'Available',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      option['description']
                                          as String,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            Colors.grey.shade700,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      option['details'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons
                                        .radio_button_unchecked,
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
                  onPressed:
                      selectedTransportation == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BoardingScreen(
                                    destination:
                                        widget.destination,
                                    departureDate:
                                        widget.departureDate,
                                    returnDate:
                                        widget.returnDate,
                                    season: widget.season,
                                    suitability:
                                        widget.suitability,
                                    currency: widget.currency,
                                    budget: widget.budget,
                                    ages: widget.ages,
                                    travelType:
                                        widget.travelType,
                                    groupSize:
                                        widget.groupSize,
                                    seasonMessage:
                                        widget.seasonMessage,
                                  ),
                                ),
                              );
                            },
                  child: const Text(
                    'Continue to Boarding',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
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