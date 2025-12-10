import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'services/fcm_service.dart';
import 'services/sms_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

/// Background message handler for Firebase Cloud Messaging
/// Must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  runApp(const MediBoxApp());
}

/// MediBox Guardian App
/// 
/// Smart medical pillbox management system for guardians
/// Features:
/// - User authentication
/// - Device management
/// - Real-time monitoring
/// - Remote control
/// - Push notifications
class MediBoxApp extends StatelessWidget {
  const MediBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth provider
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        
        // Device provider
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'MediBox Guardian',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Color scheme
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          
          // App bar theme
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          
          // Card theme
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          
          // Input decoration theme
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
          ),
          
          // Elevated button theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          
          // Use Material 3
          useMaterial3: true,
        ),
        
        // Home route with auth check
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Auth wrapper to determine initial screen
/// 
/// Shows LoginScreen if not authenticated
/// Shows HomeScreen if authenticated
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FCMService _fcmService = FCMService();
  final SmsService _smsService = SmsService();
  bool _fcmInitialized = false;
  bool _smsInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeFCM(String userId) async {
    if (_fcmInitialized) return;
    await _fcmService.initialize(userId: userId);
    _fcmInitialized = true;
  }

  Future<void> _initializeSMS(String userId) async {
    if (_smsInitialized) return;
    await _smsService.initialize(userId);
    _smsInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show login if not authenticated
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }
        
        // Initialize FCM and SMS when user is authenticated
        if (authProvider.user != null) {
          if (!_fcmInitialized) {
            _initializeFCM(authProvider.user!.uid);
          }
          if (!_smsInitialized) {
            _initializeSMS(authProvider.user!.uid);
          }
        }
        
        // Show home if authenticated
        return const HomeScreen();
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
