import 'package:emailchat/pages/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import  'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../pages/address_book_page.dart';
import '../pages/notes_page.dart';
import '../pages/otp_page.dart';
import '../services/auth/auth_service.dart';
import '../pages/settings_page.dart';



class MyDrawer extends StatelessWidget {
  final Function(List<String>) onAddressBookEmailsChanged;


  MyDrawer ({super.key, required this.onAddressBookEmailsChanged});


  final AuthService _authService = AuthService();

  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }

  Future<void> logout() async {
    //get auth service
    final auth = AuthService();
    await DatabaseHelper.instance.clearDatabase();

    auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        backgroundColor: Theme.of(context).colorScheme.background,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(children: [
                // logo
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                        Icons.person,
                       // color: Theme.of(context).colorScheme.primary,
                        size: 40,) ,
                        onPressed: () {
                          Navigator.pop(context);

                          Navigator.push( // Navigate to the ProfilePage
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(),
                            ),
                          );
                        }

                      ),


                      const SizedBox(height: 15), // Spacer between Icon and Text

                      if (getCurrentUser() != null) // Check if user is logged in
                        Text(
                          '${getCurrentUser()!.email}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                    ],
                  ),
                ),

                // const SizedBox(height: 8), // Spacer between Icon and Text
                // const Text(
                //   '',
                //   style: TextStyle(
                //     fontSize: 20,
                //     fontWeight: FontWeight.bold,
                //     color: Colors.black,
                //   ),
                // ),

                // const SizedBox(height: 8), // Spacer between Icon and Text
                //  if (getCurrentUser() != null) // Check if user is logged in
                //    Text(
                //      'Logged in as: ${getCurrentUser()!.email}',
                //      style: const TextStyle(
                //        fontSize: 16,
                //        color: Colors.black,
                //      ),
                //    ),

                //home list title
                Padding(
                  padding: const EdgeInsets.only(left:25.0),
                  child: ListTile(
                    title: const Text("H O M E"),
                    leading: const Icon(Icons.home),
                    onTap: () {
                      // pop the drawer
                      Navigator.pop(context);
                    },
                  ),
                ),

                // Address book list title
                Padding(
                  padding: const EdgeInsets.only(left:25.0),
                  child: ListTile(
                    title: const Text("A D D R E S S  B O O K"),
                    leading: const Icon(Icons.mail_lock),
                    onTap: () async {
                      Navigator.pop(context);
                      List<String>? result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddressBookPage(onEmailsChanged: onAddressBookEmailsChanged,),
                        ),
                      );
                      if (result != null) {
                        onAddressBookEmailsChanged(result); // Pass the result to the callback function
                      }

                    },
                  ),
                ),

                //Notes list title
                Padding(
                  padding: const EdgeInsets.only(left:25.0),
                  child: ListTile(
                    title: const Text("N O T E S"),
                    leading: const Icon(Icons.edit_note),
                    onTap: () {
                      // pop the drawer
                      Navigator.pop(context);

                      // navigate to settings page
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context)=> const NotesPage(),
                      ));

                    },
                  ),
                ),


                // settings list title
                Padding(
                  padding: const EdgeInsets.only(left:25.0, bottom: 25),
                  child: ListTile(
                    title: const Text("S E T T I N G S"),
                    leading: const Icon(Icons.settings),
                    onTap: () {
                      // pop the drawer
                      Navigator.pop(context);

                      // navigate to settings page
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context)=> const SettingsPage(),
                      ));
                    },
                  ),
                ),
              ],
              ),


              // logout list title
              Padding(
                  padding: const EdgeInsets.only(left:25.0),
                  child: ListTile(
                    title: const Text("L O G O U T"),
                    leading: const Icon(Icons.logout),
                    onTap: logout,
                  )
              )
            ]
        )
    );
  }

}
