import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../themes/theme_provider.dart';



class themesPage extends StatelessWidget {

  const themesPage({super.key});

@override

Widget build(BuildContext context) {

  return Scaffold(

      backgroundColor: Theme.of(context).colorScheme.background,

      appBar: AppBar(
        title: const Text("Appearance"),
        backgroundColor:Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),

      body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
          ) , // BoxDecoration

          margin: const EdgeInsets.all(25),
          padding: const EdgeInsets.all(16),

          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
// dark mode
                const Text("Dark Mode"),
  // switch toggle
                CupertinoSwitch(
                    value:
                    Provider.of<ThemeProvider>(context, listen: false).isDarkmode,
                    onChanged: (value) => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                ), // CupertinoSwitch
              ],
      ), // Row
   )
  );
}
}