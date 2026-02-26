import 'package:flutter/material.dart';
import '../services/native_vibration_service.dart';
import '../models/destination.dart';
import '../widgets/emoji_icons.dart'; 

class VibrationPicker extends StatefulWidget {
  final String currentPattern;
  final ValueChanged<String> onPatternSelected;

  const VibrationPicker({
    super.key,
    required this.currentPattern,
    required this.onPatternSelected,
  });

  @override
  State<VibrationPicker> createState() => _VibrationPickerState();
}

class _VibrationPickerState extends State<VibrationPicker> {
  late String _selectedPattern;
  final NativeVibrationService _vibration = NativeVibrationService();

  @override
  void initState() {
    super.initState();
    _selectedPattern = widget.currentPattern;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Vibration Pattern',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'POCKET MODE - Strong vibrations you will feel',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: NativeVibrationService.pocketPatterns.keys.map((patternName) {
                    final isSelected = _selectedPattern == patternName;
                    return _buildPatternTile(patternName, isSelected);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context, _selectedPattern);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatternTile(String patternName, bool isSelected) {
    final pattern = NativeVibrationService.pocketPatterns[patternName]!;
    final totalDuration = pattern.reduce((a, b) => a + b);
    final seconds = (totalDuration / 1000).toStringAsFixed(1);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Radio<String>(
          value: patternName,
          groupValue: _selectedPattern,
          activeColor: Colors.blue,
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedPattern = value);
            }
          },
        ),
        title: Text(
          patternName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isSelected ? Colors.blue : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_getPatternDescription(patternName, pattern)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$seconds sec total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: EmojiIcons.vibration(color: Colors.blue),
          onPressed: () => _vibration.testPocketPattern(patternName),
          tooltip: 'TEST - Put phone in pocket',
        ),
        onTap: () {
          setState(() => _selectedPattern = patternName);
        },
      ),
    );
  }

  String _getPatternDescription(String patternName, List<int> pattern) {
    // Count only the vibration elements (even indices: 0, 2, 4, ...)
    final actualVibrationCount = (pattern.length / 2).ceil();
    // Show one less in the description
    final displayCount = actualVibrationCount - 1;
    final firstVibe = pattern[0];
    
    if (patternName == 'Single') {
        return 'One continuous ${firstVibe}ms vibration';
    } else if (patternName == 'Double') {
        return 'Two ${firstVibe}ms vibrations';
    } else if (patternName == 'Rapid') {
        return '${displayCount} quick strong bursts';
    } else {
        return '${displayCount} strong ${firstVibe}ms vibrations';
    }
  }
}