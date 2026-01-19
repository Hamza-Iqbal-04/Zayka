import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Screens/OrderScreen.dart';

// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using them.
  // await Firebase.initializeApp(); // Uncomment if you need other Firebase services
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Global navigator key - must be set from main.dart MaterialApp
  static GlobalKey<NavigatorState>? navigatorKey;

  // 1. Define the High-Priority Channel
  static const AndroidNotificationChannel
  _driverArrivalChannel = AndroidNotificationChannel(
    'driver_arrival_channel', // A unique ID
    'Driver Arrivals', // Title shown to user in settings
    description:
        'Notifications for when the driver is near your location.', // Description for user
    importance: Importance.max, // Set the importance to MAX
    playSound: true,
  );

  // Order Updates Channel (for pickup ready notifications)
  static const AndroidNotificationChannel _orderUpdatesChannel =
      AndroidNotificationChannel(
        'order_updates', // Must match channelId in Cloud Function
        'Order Updates',
        description: 'Notifications about your order status',
        importance: Importance.max,
        playSound: true,
      );

  static Future<void> initialize() async {
    // --- Setup for Notification Channels ---
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_driverArrivalChannel);
    await androidPlugin?.createNotificationChannel(_orderUpdatesChannel);

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
        _showLocalNotification(notification, message.data);
      }
    });

    // Handle notification taps when app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was TERMINATED (killed state)
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      // Delay slightly to ensure navigator is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage);
      });
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Handle notification tap - navigate based on type
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    final orderId = data['orderId'];

    print('Notification tapped: type=$type, orderId=$orderId');

    if (type == 'pickup_ready' && orderId != null) {
      await _navigateToOrderDetails(orderId);
    }
    // Add more notification types here as needed
    // else if (type == 'driver_arrival') { ... }
  }

  // Navigate to order details screen
  static Future<void> _navigateToOrderDetails(String orderId) async {
    if (navigatorKey?.currentContext == null) {
      print('Navigator not ready, cannot navigate to order');
      return;
    }

    try {
      // Fetch order from Firestore
      final orderDoc = await FirebaseFirestore.instance
          .collection('Orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        print('Order $orderId not found');
        return;
      }

      final orderData = orderDoc.data()!;
      orderData['id'] = orderId; // Ensure order ID is included

      // Navigate to OrderDetailsScreen
      navigatorKey!.currentState?.push(
        MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: orderData)),
      );
      print('Navigated to order details: $orderId');
    } catch (e) {
      print('Error navigating to order: $e');
    }
  }

  // 2. Function to Display the Notification with the High-Priority Channel
  static void _showLocalNotification(
    RemoteNotification notification, [
    Map<String, dynamic>? data,
  ]) {
    // Determine which channel to use based on notification type
    final channelId = data?['type'] == 'pickup_ready'
        ? _orderUpdatesChannel.id
        : _driverArrivalChannel.id;
    final channelName = data?['type'] == 'pickup_ready'
        ? _orderUpdatesChannel.name
        : _driverArrivalChannel.name;
    final channelDesc = data?['type'] == 'pickup_ready'
        ? _orderUpdatesChannel.description
        : _driverArrivalChannel.description;

    _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          icon:
              '@mipmap/ic_launcher', // IMPORTANT: use your app's launcher icon
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
