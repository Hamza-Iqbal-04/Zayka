import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using them.
  // await Firebase.initializeApp(); // Uncomment if you need other Firebase services
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // 1. Define the High-Priority Channel
  static const AndroidNotificationChannel _driverArrivalChannel = AndroidNotificationChannel(
    'driver_arrival_channel', // A unique ID
    'Driver Arrivals', // Title shown to user in settings
    description: 'Notifications for when the driver is near your location.', // Description for user
    importance: Importance.max, // Set the importance to MAX
    playSound: true,
  );

  static Future<void> initialize() async {
    // --- Setup for High-Priority Channel ---
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_driverArrivalChannel);

    // --- Firebase Messaging Setup ---
    // Request permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get and save device token
    String? token = await _firebaseMessaging.getToken();
    print("Device Token: $token");
    await _saveTokenToFirestore(token);
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // --- Handle Incoming Messages ---
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If a notification arrives while the app is open, show it
      if (notification != null && android != null) {
        _showLocalNotification(notification);
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 2. Function to Display the Notification with the High-Priority Channel
  static void _showLocalNotification(RemoteNotification notification) {
    _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _driverArrivalChannel.id, // Use the channel ID
          _driverArrivalChannel.name,
          channelDescription: _driverArrivalChannel.description,
          icon: '@mipmap/ic_launcher', // IMPORTANT: use your app's launcher icon
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.email)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    }
  }
}
