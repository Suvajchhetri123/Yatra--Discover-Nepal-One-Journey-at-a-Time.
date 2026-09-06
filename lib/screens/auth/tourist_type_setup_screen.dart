import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../widgets/yatra_components.dart';
import '../home/home_screen.dart';

class TouristTypeSetupScreen extends StatefulWidget {
  const TouristTypeSetupScreen({super.key});

  @override
  State<TouristTypeSetupScreen> createState() =>
      _TouristTypeSetupScreenState();
}

class _TouristTypeSetupScreenState extends State<TouristTypeSetupScreen> {
  final FirestoreService _firestore = FirestoreService();

  String? _selectedTouristType;
  bool _saving = false;

  Future<void> _continue() async {
    if (_selectedTouristType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your tourist type.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _firestore.updateUserProfile({
        'touristType': _selectedTouristType,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save tourist type: $e'),
        ),
      );

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About You'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                'What type of tourist are you?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 10),

              Text(
                'This helps Yatra personalize your travel experience.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              _buildOption(
                title: 'Domestic Tourist',
                subtitle: 'I am travelling within Nepal.',
              ),

              const SizedBox(height: 16),

              _buildOption(
                title: 'International Tourist',
                subtitle: 'I am visiting Nepal from another country.',
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: YatraPrimaryButton(
                  label: _saving ? 'Saving...' : 'Continue',
                  onPressed: _saving ? null : _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedTouristType == title;

    return InkWell(
      onTap: _saving
          ? null
          : () {
              setState(() {
                _selectedTouristType = title;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked :Icons.radio_button_unchecked,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}