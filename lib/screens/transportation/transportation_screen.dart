import 'package:flutter/material.dart';

import '../../data/transportation_data.dart';
import '../../models/transportation_option_model.dart';
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

  List<TransportationOption> get options {
    return transportOptionsFor(widget.destination);
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

                    final String name = option.name;

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
                                  option.icon,
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
                                      option.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            Colors.grey.shade700,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      option.details,
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