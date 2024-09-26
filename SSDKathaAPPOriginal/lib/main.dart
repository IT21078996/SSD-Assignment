import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/foundation.dart';
import 'package:katha/splashScreen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

import 'Provider/internet_provider.dart';
import 'Provider/sign_in_provider.dart';
import 'Screens/GameScreen/Game/testing/dancing_screen.dart';
import 'Screens/GameScreen/Game/questionAnimation.dart';
import 'Screens/GameScreen/Game/testing/questionPage.dart';
import 'Screens/GameScreen/Game/testing/question_screen.dart';
import 'Screens/ScreenTest/Correct.dart';
import 'Screens/ScreenTest/InCorrect.dart';
import 'Screens/ScreenTest/HowToSpeak.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;

//could metadata potentially exposed valnarability
void fetchMetaData() async {
  final response = await http.get(Uri.parse('http://169.254.169.254/latest/meta-data/instance-id'));

  if (response.statusCode == 200) {
    // If the server returns a 200 OK response, parse the metadata
    print('Metadata: ${response.body}');
  } else {
    // If the server returns an unsuccessful response code, throw an exception.
    throw Exception('Failed to load metadata');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fetch Meta Data
  fetchMetaData();

  await dotenv.load(fileName: ".env");

  // Firebase Initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _jailbroken;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      initPlatformState();
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    bool jailbroken;
    try {
      jailbroken = await FlutterJailbreakDetection.jailbroken;
    } on PlatformException {
      jailbroken = true;
    }

    if (!mounted) return;

    setState(() {
      _jailbroken = jailbroken;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && _jailbroken == true) {
      // Handle jailbroken devices
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        // Wait for 5 seconds for the user to read the message
        await Future.delayed(Duration(seconds: 5));
        // Close the app
        SystemNavigator.pop();
      });
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text('Jailbroken Device'),
          ),
          body: Center(
            child: Text('Sorry, this app cannot run on jailbroken devices. The app will close in 5 seconds.'),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: ((context) => SignInProvider()),
        ),
        ChangeNotifierProvider(
          create: ((context) => InternetProvider()),
        ),
      ],

      child:   MaterialApp(
        builder: EasyLoading.init(),
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}