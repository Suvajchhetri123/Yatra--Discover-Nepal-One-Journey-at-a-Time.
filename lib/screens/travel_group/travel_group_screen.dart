import 'package:flutter/material.dart';
import '../age/age_screen.dart';

class TravelGroupScreen extends StatefulWidget {
  final DateTime departureDate;
  final DateTime returnDate;

  const TravelGroupScreen({
    super.key,
    required this.departureDate,
    required this.returnDate,
  });

  @override
  State<TravelGroupScreen> createState() => _TravelGroupScreenState();
}

class _TravelGroupScreenState extends State<TravelGroupScreen> {
  String? selectedTravelType;
  int adultCount = 1;
  int childCount = 0;

  int get groupSize => adultCount + childCount;

  void selectTravelType(String type) {
    setState(() {
      selectedTravelType = type;

      if (type == 'Solo') {
        adultCount = 1;
        childCount = 0;
      } else {
        adultCount = 2;
        childCount = 0;
      }
    });
  }

  void continueToAgeScreen() {
    if (selectedTravelType == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgeScreen(
          travelType: selectedTravelType!,
          adultCount: adultCount,
          childCount: childCount,
          departureDate: widget.departureDate,
          returnDate: widget.returnDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Group'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How are you travelling?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                'Tell us who you are travelling with.',
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              _TravelTypeCard(
                title: 'Solo',
                subtitle: 'I am travelling alone',
                icon: Icons.person,
                selected: selectedTravelType == 'Solo',
                onTap: () => selectTravelType('Solo'),
              ),

              const SizedBox(height: 16),

              _TravelTypeCard(
                title: 'Group',
                subtitle: 'I am travelling with others',
                icon: Icons.groups,
                selected: selectedTravelType == 'Group',
                onTap: () => selectTravelType('Group'),
              ),

              if (selectedTravelType == 'Group') ...[
                const SizedBox(height: 30),

                const Text(
                  'Who is travelling?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                _TravellerCounter(
                  label: 'Adults',
                  subtitle: '18 years and above',
                  value: adultCount,
                  onRemove: adultCount > 1
                      ? () => setState(() => adultCount--)
                      : null,
                  onAdd: groupSize < 20
                      ? () => setState(() => adultCount++)
                      : null,
                ),

                const SizedBox(height: 12),

                _TravellerCounter(
                  label: 'Children',
                  subtitle: 'Under 18 years',
                  value: childCount,
                  onRemove: childCount > 0
                      ? () => setState(() => childCount--)
                      : null,
                  onAdd: groupSize < 20
                      ? () => setState(() => childCount++)
                      : null,
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: selectedTravelType == null
                      ? null
                      : continueToAgeScreen,
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

class _TravelTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TravelTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? Colors.deepPurple : Colors.grey,
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(subtitle, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),

            if (selected)
              const Icon(Icons.check_circle, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}

class _TravellerCounter extends StatelessWidget {
  final String label;
  final String subtitle;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;

  const _TravellerCounter({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontSize: 20)),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
