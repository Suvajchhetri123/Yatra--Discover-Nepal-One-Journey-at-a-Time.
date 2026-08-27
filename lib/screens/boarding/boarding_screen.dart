import 'package:flutter/material.dart';
import '../../models/travel_route_model.dart';
import '../recommendation/recommendation_screen.dart';

class BoardingScreen extends StatefulWidget {
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final String season;
  final String suitability;
  final String currency;
  final double budget;
  final List<int> ages;
  final String travelType;
  final int groupSize;
  final String seasonMessage;

  const BoardingScreen({
    super.key,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.season,
    required this.suitability,
    required this.currency,
    required this.budget,
    required this.ages,
    required this.travelType,
    required this.groupSize,
    required this.seasonMessage,
  });

  @override
  State<BoardingScreen> createState() => _BoardingScreenState();
}

class _BoardingScreenState extends State<BoardingScreen> {
  List<String> get locations {
    switch (widget.destination) {
      case 'Mustang':
        return const ['Kathmandu', 'Pokhara', 'Jomsom', 'Mustang'];
      case 'Everest':
        return const ['Kathmandu', 'Everest'];
      case 'Annapurna':
        return const ['Kathmandu', 'Pokhara', 'Annapurna'];
      case 'Chitwan':
        return const ['Kathmandu', 'Chitwan'];
      case 'Pokhara':
        return const ['Kathmandu', 'Pokhara'];
      case 'Kathmandu':
      default:
        return const ['Kathmandu'];
    }
  }

  final List<String> transportationOptions = const [
    'Bus',
    'Flight',
    'Jeep',
    'Private Vehicle',
    'Motorbike',
    'Hybrid',
  ];

  String? boardingPoint;
  String? endingPoint;

  final List<RouteSegment> segments = [];

  String? selectedFrom;
  String? selectedTo;
  String? selectedTransportation;

  @override
  void initState() {
    super.initState();
    endingPoint = widget.destination;
  }

  void _addSegment() {
    if (selectedFrom == null ||
        selectedTo == null ||
        selectedTransportation == null) {
      _showMessage(
        'Please select starting point, destination and transportation.',
      );
      return;
    }

    if (selectedFrom == selectedTo) {
      _showMessage('Starting point and destination cannot be the same.');
      return;
    }

    if (boardingPoint == null) {
      _showMessage('Please select your boarding point first.');
      return;
    }

    final expectedStartingPoint = segments.isEmpty
        ? boardingPoint
        : segments.last.to;

    if (selectedFrom != expectedStartingPoint) {
      _showMessage('This route must continue from $expectedStartingPoint.');
      return;
    }

    final segment = RouteSegment(
      from: selectedFrom!,
      to: selectedTo!,
      transportation: selectedTransportation!,
    );

    setState(() {
      segments.add(segment);

      selectedFrom = selectedTo;
      selectedTo = null;
      selectedTransportation = null;
    });
  }

  void _removeSegment(int index) {
    setState(() {
      segments.removeAt(index);

      if (segments.isEmpty) {
        selectedFrom = boardingPoint;
      } else {
        selectedFrom = segments.last.to;
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _continue() {
    if (boardingPoint == null) {
      _showMessage('Please select your boarding point.');
      return;
    }

    if (endingPoint == null) {
      _showMessage('Please select your ending point.');
      return;
    }

    if (boardingPoint == endingPoint) {
      _showMessage('Boarding and ending points cannot be the same.');
      return;
    }

    if (segments.isEmpty) {
      _showMessage('Please add at least one transportation route.');
      return;
    }

    if (segments.first.from != boardingPoint) {
      _showMessage('The first route must start at your boarding point.');
      return;
    }

    if (segments.last.to != endingPoint) {
      _showMessage('The final route must end at your ending point.');
      return;
    }

    final route = TravelRoute(
      boardingPoint: boardingPoint!,
      destination: endingPoint!,
      segments: List.unmodifiable(segments),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendationScreen(
          destination: widget.destination,
          departureDate: widget.departureDate,
          returnDate: widget.returnDate,
          season: widget.season,
          suitability: widget.suitability,
          currency: widget.currency,
          budget: widget.budget,
          ages: widget.ages,
          travelType: widget.travelType,
          groupSize: widget.groupSize,
          seasonMessage: widget.seasonMessage,
          route: route,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _routeText() {
    if (segments.isEmpty) {
      return boardingPoint ?? 'No route selected';
    }

    final points = <String>[
      segments.first.from,
      ...segments.map((segment) => segment.to),
    ];

    return points.join(' → ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Route'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan Your Route',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose where your journey starts and how you want to travel.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),

              const SizedBox(height: 25),

              _dropdown(
                label: 'Boarding / Starting Point',
                value: boardingPoint,
                items: locations,
                onChanged: (value) {
                  setState(() {
                    boardingPoint = value;

                    if (segments.isEmpty) {
                      selectedFrom = value;
                    }
                  });
                },
              ),

              const SizedBox(height: 18),

              _dropdown(
                label: 'Ending Point',
                value: endingPoint,
                items: locations,
                onChanged: (value) {
                  setState(() {
                    endingPoint = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              const Text(
                'Transportation Route',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'You can combine different transportation methods.',
                style: TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 18),

              _dropdown(
                label: 'From',
                value: selectedFrom,
                items: locations,
                onChanged: (value) {
                  setState(() {
                    selectedFrom = value;
                  });
                },
              ),

              const SizedBox(height: 15),

              _dropdown(
                label: 'To',
                value: selectedTo,
                items: locations,
                onChanged: (value) {
                  setState(() {
                    selectedTo = value;
                  });
                },
              ),

              const SizedBox(height: 15),

              _dropdown(
                label: 'Transportation',
                value: selectedTransportation,
                items: transportationOptions,
                onChanged: (value) {
                  setState(() {
                    selectedTransportation = value;
                  });
                },
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addSegment,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Route'),
                ),
              ),

              const SizedBox(height: 25),

              if (segments.isNotEmpty) ...[
                const Text(
                  'Your Route',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                ...segments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final segment = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.directions),
                      title: Text(
                        '${segment.from} → ${segment.to}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(segment.transportation),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeSegment(index),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete Route',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _routeText(),
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _continue,
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
