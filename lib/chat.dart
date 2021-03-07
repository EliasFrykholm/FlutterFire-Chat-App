import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/colors.dart';

class Chat extends StatelessWidget {
  Chat({Key key}) : super(key: key);

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
      ),
      body: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  ChatScreen({Key key}) : super(key: key);

  @override
  State createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  _ChatScreenState({Key key});

  String id;

  int _limit = 20;
  int _limitIncrement = 20;
  SharedPreferences prefs;

  bool isLoading;
  bool isShowSticker;
  String imageUrl;

  final TextEditingController textEditingController = TextEditingController();
  final ScrollController listScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  _scrollListener() {
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    listScrollController.addListener(_scrollListener);

    isLoading = false;
    readLocal();
  }

  readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
  }

  void onSendMessage(String content, int type) {
    // type: 0 = text, 1 = image, 2 = sticker
    if (content.trim() != '') {
      textEditingController.clear();

      var documentReference = FirebaseFirestore.instance
          .collection('messages')
          .doc(DateTime.now().millisecondsSinceEpoch.toString());

      FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(
          documentReference,
          {
            'idFrom': id,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': content,
          },
        );
      });
      //listScrollController.animateTo(0.0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // List of messages
              buildListMessage(),

              // Input content
              buildInput(),
            ],
          ),

          // Loading
          //buildLoading()
        ],
      ),
    );
  }

  Widget buildInput() {
    return Container(
      child: Row(
        children: <Widget>[
          // Edit text
          Flexible(
            child: Container(
              child: TextField(
                onSubmitted: (value) {
                  onSendMessage(textEditingController.text, 0);
                },
                style: TextStyle(color: Colors.white, fontSize: 15.0),
                controller: textEditingController,
                decoration: InputDecoration.collapsed(
                  hintText: 'Type your message...',
                ),
                focusNode: focusNode,
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              padding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),

          // Button send message
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                icon: Icon(Icons.send, color: primaryColor),
                onPressed: () => onSendMessage(textEditingController.text, 0),
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
      width: double.infinity,
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: primaryColor, width: 1))),
    );
  }

  Widget buildChatItem(int index, DocumentSnapshot document) {
    if (document.data()['idFrom'] == id) {
      // Right (my message)
      return Container(
        child: Row(
          children: <Widget>[buildChatMessage(true, document)],
          mainAxisAlignment: MainAxisAlignment.end,
        ),
        margin: EdgeInsets.only(bottom: 10.0, right: 10.0),
      );
    } else {
      // Left (peer message)
      return Container(
        child: Row(
          children: <Widget>[buildChatMessage(false, document)],
          mainAxisAlignment: MainAxisAlignment.start,
        ),
        margin: EdgeInsets.only(bottom: 10.0, left: 10.0),
      );
    }
  }

  Widget buildChatMessage(bool you, DocumentSnapshot document) {
    return Column(
      crossAxisAlignment:
          you ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(you ? "You" : document.data()['idFrom']),
        Container(
          child: Text(
            document.data()['content'],
          ),
          padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
          constraints: BoxConstraints(
              minWidth: 200, maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
              color: you ? primaryColor : null,
              border: Border.all(color: primaryColor, width: 1),
              borderRadius: BorderRadius.circular(8.0)),
        ),
        Text(
          document.data()['timestamp'],
          style: TextStyle(fontSize: 8, fontStyle: FontStyle.italic),
        )
      ],
    );
  }

  Widget buildListMessage() {
    return Flexible(
        child: StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_limit)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor)));
        } else {
          return ListView.builder(
            padding: EdgeInsets.all(10.0),
            itemBuilder: (context, index) =>
                buildChatItem(index, snapshot.data.docs[index]),
            itemCount: snapshot.data.docs.length,
            reverse: true,
            controller: listScrollController,
          );
        }
      },
    ));
  }
}
