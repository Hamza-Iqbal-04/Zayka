import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'AddressService.dart';

class BranchLocator extends ChangeNotifier {
  final AddressService addrSvc;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _branchId;

  BranchLocator(this.addrSvc) {
    addrSvc.addListener(recompute);
    recompute();
  }

  String? get branchId => _branchId;

  Future<void> recompute() async {
    final GeoPoint? userPt = addrSvc.coords;
    if (userPt == null) return;

    final docs = await _db.collection('Branch').get();
    double best = double.infinity;
    String? bestId;

    for (final d in docs.docs) {
      final GeoPoint pt = d['address']['geolocation'];
      final dist = Geolocator.distanceBetween(
          userPt.latitude, userPt.longitude, pt.latitude, pt.longitude);
      if (dist < best) {
        best = dist;
        bestId = d.id;
      }
    }
    if (bestId != _branchId) {
      _branchId = bestId;
      notifyListeners();
    }
  }
}


