

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailchat/components/chat_bubble.dart';
import 'package:emailchat/components/my_textfield.dart';
import 'package:emailchat/services/auth/auth_service.dart';
import 'package:emailchat/services/chat/chat_services.dart';
import 'package:flutter/material.dart';


class ChatPage extends StatelessWidget {
  final String receiverEmail;
  final String receiverID;


   ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
  });

  // text controller
  final TextEditingController _messageController = TextEditingController();

  //chat &  auth services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();


  // send Message
  void sendMessage() async {
    // if there is something inside the textfield
    if (_messageController.text.isNotEmpty) {
      // send the message
      await _chatService.sendMessage(receiverID, _messageController.text);


      // clear text controller
     _messageController.clear();

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(receiverEmail)),
      body: Column(
        children: [
          // display all messages

          Expanded(
            child: _buildMessageList(),
          ),

          // user input
          _buildUserInput(),
        ],
      ),
    );
  }


  // build message list
  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;
    return StreamBuilder(
        stream: _chatService.getMessages(receiverID, senderID),
        builder: (context, snapshot) {
          // error
          if (snapshot.hasError){
            return const Text("Error");
          }

          //loading
          if (snapshot.connectionState == ConnectionState.waiting){
            return const Text("Loading..");
          }

          //return list view
          return ListView(
            children: snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
          );
        },
    );
  }

  // build message item
  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String,dynamic>;

    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;

    // if current user then align messages to right

    var alignment= isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      child: Container(
          alignment: alignment,
          child: Column(
            crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,

            children: [
              ChatBubble(message: data["message"], isCurrentUser: isCurrentUser)
            ],


          ),


        // child: Text(
          //     data["message"],
          //   style: const TextStyle(
          //   fontSize: 20,
          //   fontWeight: FontWeight.bold,
          //   //fontStyle: FontStyle.italic,
          //   color: Colors.blue,
          //   //decoration: TextDecoration.underline,
          //   decorationColor: Colors.red,
          //   decorationThickness: 2,
          // ),
          // )
      ),
    );
  }

  // build message input
  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [

          // text-field should take up most of the space
          Expanded(child: MyTextField(
            controller: _messageController,
            hintText: "Type a message",
            obscuredText: false,
          ),
      ),

        // send button
        Container(
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle

          ),
          margin: const EdgeInsets.only(right: 25),
          child: IconButton(
            onPressed: sendMessage,
            icon: const Icon(Icons.arrow_upward,color: Colors.white,),
          ),
        ),
      ],
      ),
    );
}
}