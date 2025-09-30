import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class AddressService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _activeAddress;
  Map<String, dynamic>? get active => _activeAddress;          // full map
  GeoPoint? get coords => _activeAddress?['geolocation'];      // lat/lng

  AddressService() {
    _load();                                                   // start listener
  }

  void _load() {
    final user = _auth.currentUser;
    if (user == null) return;
    _db.collection('Users').doc(user.email).snapshots().listen((snap) {
      final list = (snap.data()?['address'] as List?)
          ?.cast<Map<String, dynamic>>() ??
          [];
      Map<String, dynamic>? chosen =
      list.firstWhere((e) => e['isDefault'] == true, orElse: () => {});
      chosen ??= list.isNotEmpty ? list.first : null;
      if (chosen != null && chosen != _activeAddress) {
        _activeAddress = chosen;
        notifyListeners();
      }
    });
  }
}

