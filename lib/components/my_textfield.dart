import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final String hintText;
  final bool obscuredText;
  final TextEditingController controller;
  final Function(String) onChanged; // Added onChanged function parameter

  const MyTextField({
    super.key,
    required this.hintText,
    this.obscuredText = false, // Set obscuredText as optional with a default value of false
    required this.controller,
    required this.onChanged, // Ensure onChanged is passed in
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: TextField(
        obscureText: obscuredText,
        controller: controller,
        onChanged: onChanged, // Hook up the onChanged callback to the TextField
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
          ),
          fillColor: Theme.of(context).colorScheme.surface, // Adjusted fill color
          filled: true,
          hintText: hintText,
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface), // Adjusted hint color
        ),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface), // Ensure text is visible
      ),
    );
  }
}
