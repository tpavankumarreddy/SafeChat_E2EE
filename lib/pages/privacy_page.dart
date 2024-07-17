import 'package:flutter/material.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  _PrivacyPageState createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String _selectedOption = 'Select an option';
  final List<String> _options = ['X3DH , AES', 'X3DH , Serpent', 'X3DH , Salsa20', 'X3DH , ChaCha20' , 'X3DH , Blowfish'];

  void _showOptionSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Security Encryption'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _options.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(_options[index]),
                  onTap: () {
                    setState(() {
                      _selectedOption = _options[index];
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        children: [

          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security Encryption'),
            trailing: const Icon(Icons.arrow_downward),
            onTap: () {
              _showOptionSelectionDialog(context);
            },
          ),
        ],
      ),
    );
  }
}