import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/next_Screen.dart';

class SignInProvider extends ChangeNotifier {
  // Firebase Authentication and Google Sign-In instances
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  // Secure storage instance
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();

  // Encryption setup
  late encrypt.Key key;
  final encrypt.IV iv = encrypt.IV.fromLength(16); // IV will be dynamic in encrypt/decrypt methods

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  bool _hasError = false;
  bool get hasError => _hasError;

  String? _errorCode;
  String? get errorCode => _errorCode;

  String? _uid;
  String? get uid => _uid;

  String? _displayName;
  String? get displayName => _displayName;

  String? _email;
  String? get email => _email;

  SignInProvider() {
    checkSignInUser();
    loadEncryptionKey(); // Load the encryption key securely
  }

  // Load encryption key from secure storage or generate a new one
  Future<void> loadEncryptionKey() async {
    String? storedKey = await secureStorage.read(key: 'encryptionKey');
    if (storedKey == null) {
      // Generate and store a new key if it doesn't exist
      final newKey = encrypt.Key.fromSecureRandom(32);
      await secureStorage.write(key: 'encryptionKey', value: newKey.base64);
      key = newKey;
    } else {
      key = encrypt.Key.fromBase64(storedKey);
    }
  }

  // AES Encryption method with dynamic IV
  String encryptAES(String text) {
    final iv = encrypt.IV.fromSecureRandom(16); // Generate random IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(text, iv: iv);
    return '${iv.base64}:${encrypted.base64}'; // Store IV with encrypted text
  }

  // AES Decryption method with extracted IV
  String decryptAES(String encryptedData) {
    final parts = encryptedData.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]); // Extract IV
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Future checkSignInUser() async {
    _isSignedIn = (await secureStorage.read(key: 'signed_in')) == 'true' ? true : false;
    notifyListeners();
  }

  Future setSignIn() async {
    await secureStorage.write(key: 'signed_in', value: 'true');
    _isSignedIn = true;
    notifyListeners();
  }

  // ENTRY FOR CLOUD_FIRESTORE

  Future getUserDataFromFirestore(uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc('uid')
        .get()
        .then((DocumentSnapshot snapshot) => {
      _uid = snapshot['uid'],
      _email = snapshot['email'],
      _displayName = snapshot['displayName'],
    });
  }

  Future saveDataToFirestore() async {
    final DocumentReference r = FirebaseFirestore.instance.collection('users').doc(uid);
    await r.set({
      'email': _email,
      'uid': _uid,
      'displayName': _displayName,
    });
    notifyListeners();
  }

  // Save encrypted data to secure storage
  Future saveDataToSecureStorage() async {
    await secureStorage.write(key: 'email', value: encryptAES(_email!));
    await secureStorage.write(key: 'uid', value: encryptAES(_uid!));
    await secureStorage.write(key: 'displayName', value: encryptAES(_displayName!));
    notifyListeners();
  }

  // Retrieve and decrypt data from secure storage
  Future getDataFromSecureStorage() async {
    String? emailEncrypted = await secureStorage.read(key: 'email');
    String? uidEncrypted = await secureStorage.read(key: 'uid');
    String? displayNameEncrypted = await secureStorage.read(key: 'displayName');

    if (emailEncrypted != null && uidEncrypted != null && displayNameEncrypted != null) {
      _email = decryptAES(emailEncrypted);
      _uid = decryptAES(uidEncrypted);
      _displayName = decryptAES(displayNameEncrypted);
    }
    notifyListeners();
  }

  // Check if the user exists in Firestore
  Future<bool> checkUserExists() async {
    DocumentSnapshot snap = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (snap.exists) {
      print('EXISTING USER');
      return true;
    } else {
      print('NEW USER');
      return false;
    }
  }

  // Sign out the user and clear all secure storage
  Future userSignOut() async {
    firebaseAuth.signOut();

    _isSignedIn = false;
    notifyListeners();

    clearStoredData();
  }

  // Clear all secure storage data
  Future clearStoredData() async {
    await secureStorage.deleteAll();
  }

  // Sign in with Google and handle errors
  Future signInWithGoogle() async {
    final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

    if (googleSignInAccount != null) {
      // Executing authentication
      try {
        final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        // Sign in to Firebase user instance
        final User userDetails = (await firebaseAuth.signInWithCredential(credential)).user!;
        _email = userDetails.email;
        _uid = userDetails.uid;
        _displayName = userDetails.displayName;

        notifyListeners();
      } on FirebaseAuthException catch (e) {
        switch (e.code) {
          case 'account-exists-with-different-credential':
            _errorCode = 'You already have an account with us. Use correct provider';
            _hasError = true;
            notifyListeners();
            break;
          case 'not selected':
            _errorCode = 'Some unexpected error while trying to sign in';
            _hasError = true;
            notifyListeners();
            break;
          default:
            _errorCode = e.toString();
            _hasError = true;
            notifyListeners();
        }
      }
    } else {
      _hasError = true;
      notifyListeners();
    }
  }
}
