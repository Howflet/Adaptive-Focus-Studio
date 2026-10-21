import 'package:flutter/material.dart';

class MoodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const MoodChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Colors.grey.shade800,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
        backgroundColor: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade600)),
      ),
    );
  }
}
