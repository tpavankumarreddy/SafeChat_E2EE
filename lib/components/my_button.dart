import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  final double fontSize; // New parameter for text size

  const MyButton({
    super.key,
    required this.text,
    required this.onTap,
    this.fontSize = 16, // Default font size
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(80),
        ),
        padding: const EdgeInsets.all(25),
        margin: const EdgeInsets.symmetric(horizontal: 25),
        child: Center(
          child: Text(text, style: TextStyle(fontSize: fontSize)),
        ),
      ),
    );
  }
}
