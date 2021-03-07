
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat.dart';
import 'theme/colors.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Trigger the authentication flow
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  User currentUser;

  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => ChatPage(currentUserId: prefs.getString('id'))),
      // );
    }

    this.setState(() {
      isLoading = false;
    });
  }

  Future<Null> handleSignIn() async {
    prefs = await SharedPreferences.getInstance();

    this.setState(() {
      isLoading = true;
    });

    GoogleAuthProvider googleProvider = GoogleAuthProvider();

    googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
    googleProvider.setCustomParameters({
      'login_hint': 'user@example.com'
    });

    User firebaseUser = (await FirebaseAuth.instance.signInWithPopup(googleProvider)).user;

    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result =
          await FirebaseFirestore.instance.collection('users').where('id', isEqualTo: firebaseUser.uid).get();
      final List<DocumentSnapshot> documents = result.docs;
      if (documents.length == 0) {
        // Update data to server if new user
        FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
          'nickname': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoURL,
          'id': firebaseUser.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('nickname', currentUser.displayName);
        await prefs.setString('photoUrl', currentUser.photoURL);
      } else {
        // Write data to local
        await prefs.setString('id', documents[0].data()['id']);
        await prefs.setString('nickname', documents[0].data()['nickname']);
        await prefs.setString('photoUrl', documents[0].data()['photoUrl']);
        await prefs.setString('aboutMe', documents[0].data()['aboutMe']);
      }
      this.setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Chat()));
    } else {
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: <Widget>[
            Center(
              child: ElevatedButton(
                  onPressed: () => handleSignIn().catchError((err) {
                        log("Sign in failed");
                      }),
                  child: Text(
                    'Sign In With Google',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  style: ElevatedButton.styleFrom(primary: primaryColor, elevation: 3, ),
              )
            ),

            // Loading
            // Positioned(
            //   child: isLoading ? const Loading() : Container(),
            // ),
          ],
        ));
  }

}