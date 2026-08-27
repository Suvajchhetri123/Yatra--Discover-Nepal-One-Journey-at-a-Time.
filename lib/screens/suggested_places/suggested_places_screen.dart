import 'package:flutter/material.dart';
import '../../models/place_model.dart';

class SuggestedPlacesScreen extends StatelessWidget {
  final String destination;
  final List<Place> places;

  const SuggestedPlacesScreen({
    super.key,
    required this.destination,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggested Places'), centerTitle: true),
      body: SafeArea(
        child: places.isEmpty
            ? const Center(
                child: Text(
                  'No places available for this destination yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            place.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            place.description,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Entry Fee: ${place.entryFee == 0 ? 'Free' : 'NPR ${place.entryFee.toStringAsFixed(0)}'}',
                            style: const TextStyle(fontSize: 14),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Opening Hours: ${place.openingHours}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
