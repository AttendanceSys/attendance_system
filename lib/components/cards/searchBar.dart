//search bar

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color addBgColor = isDark
        ? const Color(0xFF4234A4) // keep dark-mode button as set
        : const Color(0xFF8372FE); // restore original light-mode background

    Widget searchField() {
      return TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
      );
    }

    Widget addButton() {
      return ElevatedButton.icon(
        onPressed: onAddPressed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(buttonText, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: addBgColor,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasButton = buttonText.isNotEmpty;
        final useStacked = hasButton && constraints.maxWidth < 520;

        if (useStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField(),
              const SizedBox(height: 10),
              SizedBox(height: 48, child: addButton()),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField()),
            if (hasButton) ...[
              const SizedBox(width: 12),
              addButton(),
            ],
          ],
        );
      },
    );
  }
}
