import 'package:flutter/material.dart';

class SearchAddBar extends StatelessWidget {
  final String hintText;
  final String buttonText;
  final VoidCallback onAddPressed;
  final ValueChanged<String>? onChanged;

  const SearchAddBar({
    super.key,
    required this.hintText,
    required this.buttonText,
    required this.onAddPressed,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search Field
        Expanded(
          child: TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ),
        if (buttonText.isNotEmpty && onAddPressed != null) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              buttonText,
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F489E), // Dark blue
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
