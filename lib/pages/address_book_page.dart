import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/user_tile.dart';
import '../data/database_helper.dart';
class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key, required this.onEmailsChanged});

  final Function(List<String>) onEmailsChanged;

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  final TextEditingController _emailController = TextEditingController();
  List<String> _emails = [];

  @override
  void initState() {
    super.initState();
    _loadEmailsFromDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Address Book"),
      ),
      body: ListView.builder(
        itemCount: _emails.length,
        itemBuilder: (context, index) {
          return UserTile(
            text: _emails[index],
            onTap: () {
              _showOptionsBottomSheet(context, _emails[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showEmailInputDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEmailInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter Email Address"),
          content: TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email Address'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                // Retrieve the entered email address
                String email = _emailController.text;
                bool exists = await _checkEmailExists(email); // Check if email exists in Firestore
                if (exists) {
                  setState(() {
                    _emails.add(email);// Add the entered email to the list
                    _saveEmailToDatabase(email);

                  });
                }
                else {
                  // Handle case where email does not exist in Firestore
                  // For example, show an error message
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Email address does not exist.'),
                  ));
                }
                _emailController.clear(); // Clear the text field
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkEmailExists(String email) async {

    var querySnapshot = await FirebaseFirestore.instance
        .collection("user's")
        .where('email', isEqualTo: email)
        .get();

    return querySnapshot.docs.isNotEmpty; // Return true if email exists, false otherwise
  }


  void _showOptionsBottomSheet(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Update'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showUpdateDialog(context, email);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  deleteEmail(email); // Await the deletion operation
                  _loadEmailsFromDatabase(); // Reload emails after deletion
                },
              ),
            ],
          ),
        );
      },
    );
  }


  void _showUpdateDialog(BuildContext context, String oldEmail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController newEmailController = TextEditingController();
        return AlertDialog(
          title: const Text("Update Email Address"),
          content: TextField(
            controller: newEmailController,
            decoration: InputDecoration(labelText: 'New Email Address', hintText: oldEmail),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                //_updateEmail(oldEmail, _newEmailController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void deleteEmail(String email) async {
    await DatabaseHelper.instance.deleteEmail(email);
    _loadEmailsFromDatabase();
    widget.onEmailsChanged(_emails); // Notify the parent widget about the updated emails
  }



  void _loadEmailsFromDatabase() async {
    List<String> emails = await DatabaseHelper.instance.queryAllEmails();
    setState(() {
      _emails = emails;
    });
    widget.onEmailsChanged(_emails); // Notify the parent widget about the updated emails
  }


  void _saveEmailToDatabase(String email) async {
    await DatabaseHelper.instance.insertEmail(email);
    _loadEmailsFromDatabase();
    widget.onEmailsChanged(_emails); // Notify the parent widget about the updated emails
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}