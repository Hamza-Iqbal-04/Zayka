import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import '../Widgets/models.dart';
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

class BranchDistance {
  final String id;
  final String name;
  final double distance;
  final bool isOpen;
  final bool isInRange;

  BranchDistance(
      this.id, this.name, this.distance, this.isOpen, this.isInRange);
}

class BranchSelectionResult {
  final BranchDistance? selectedBranch;
  final bool allClosed;
  final bool noDeliveryAvailable;
  final bool fallbackOccurred;
  final BranchDistance? nearestClosedBranch;

  BranchSelectionResult({
    this.selectedBranch,
    this.allClosed = false,
    this.noDeliveryAvailable = false,
    this.fallbackOccurred = false,
    this.nearestClosedBranch,
  });
}

class BranchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<BranchSelectionResult> findBestBranch({
    required GeoPoint userLocation,
    required String orderType, // 'delivery' or 'pickup'
  }) async {
    try {
      // 1. Fetch ALL Active Branches
      final branchesSnapshot = await _firestore
          .collection('Branch')
          .where('isActive', isEqualTo: true)
          .get();

      if (branchesSnapshot.docs.isEmpty) {
        return BranchSelectionResult(allClosed: true);
      }

      // 2. Calculate Stats for Every Branch
      List<BranchDistance> sortedBranches = [];

      for (final doc in branchesSnapshot.docs) {
        final data = doc.data();
        final addressData = data['address'] as Map<String, dynamic>?;

        if (addressData != null && addressData['geolocation'] != null) {
          final branchGeo = addressData['geolocation'] as GeoPoint;
          final double distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            branchGeo.latitude,
            branchGeo.longitude,
          );

          final bool isOpen = data['isOpen'] ?? true;
          final String name = data['name'] ?? doc.id;
          final double noDeliveryRange =
              (data['noDeliveryRange'] ?? 0).toDouble();

          // Rule: If delivery, range matters. If pickup, range doesn't matter.
          final bool isInRange = orderType == 'pickup'
              ? true
              : (noDeliveryRange > 0 && distance <= noDeliveryRange);

          sortedBranches
              .add(BranchDistance(doc.id, name, distance, isOpen, isInRange));
        }
      }

      if (sortedBranches.isEmpty) {
        // No branches with valid location data found
        return BranchSelectionResult(allClosed: true);
      }

      // 3. FILTERING FOR DELIVERY
      if (orderType == 'delivery') {
        final branchesInRange =
            sortedBranches.where((b) => b.isInRange).toList();

        if (branchesInRange.isEmpty) {
          return BranchSelectionResult(noDeliveryAvailable: true);
        }

        // Only consider in-range branches for selection
        sortedBranches = branchesInRange;
      }

      // 4. SORTING: Open > Closest
      sortedBranches.sort((a, b) {
        if (a.isOpen != b.isOpen) {
          return a.isOpen ? -1 : 1; // Open first
        }
        return a.distance.compareTo(b.distance); // Closest first
      });

      // 5. Select the Best Branch
      final BranchDistance selectedBranch = sortedBranches.first;
      final bool allClosed = sortedBranches.every((b) => !b.isOpen);

      if (allClosed) {
        return BranchSelectionResult(allClosed: true);
      }

      // 6. Check for Fallback (skipped a closer closed branch)
      bool fellBack = false;
      BranchDistance? nearestClosed;

      // Find the absolute closest branch (ignoring open status) within the filtered list
      final geometricNearest = sortedBranches
          .reduce((curr, next) => curr.distance < next.distance ? curr : next);

      // If we picked an open branch that isn't the geometric nearest, it means the nearest was closed
      if (selectedBranch.id != geometricNearest.id &&
          !geometricNearest.isOpen) {
        fellBack = true;
        nearestClosed = geometricNearest;
      }

      return BranchSelectionResult(
        selectedBranch: selectedBranch,
        allClosed: false,
        noDeliveryAvailable: false,
        fallbackOccurred: fellBack,
        nearestClosedBranch: nearestClosed,
      );
    } catch (e) {
      debugPrint('Error finding best branch: $e');
      // FAIL SAFE: Do NOT return allClosed=true, as this blocks the app.
      // Instead, return a fallback branch (e.g. Old_Airport) assuming it's open.
      return BranchSelectionResult(
        selectedBranch: BranchDistance(
            'Old_Airport',
            'Old Airport Branch',
            0.0,
            true, // Assume open on error to avoid blocking
            true // Assume in range on error to avoid blocking
            ),
        allClosed: false,
        noDeliveryAvailable: false,
      );
    }
  }

  // --- Legacy / Helper Methods ---

  Future<String> getNearestBranch() async {
    try {
      debugPrint('🔍 Finding nearest branch by default address...');

      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return 'Old_Airport';
      }

      final userDoc =
          await _firestore.collection('Users').doc(user.email).get();
      if (!userDoc.exists) {
        return 'Old_Airport';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final addresses =
          (userData['address'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (addresses.isEmpty) {
        return 'Old_Airport';
      }

      Map<String, dynamic> defaultAddress;
      try {
        defaultAddress = addresses.firstWhere((a) => a['isDefault'] == true);
      } catch (e) {
        defaultAddress = addresses.first;
      }

      if (defaultAddress['geolocation'] == null) {
        return 'Old_Airport';
      }

      final userGeoPoint = defaultAddress['geolocation'] as GeoPoint;

      // Use the new shared logic to find best branch
      // 'pickup' ensures we find the nearest branch regardless of delivery range
      // but 'delivery' ensures we respect range if the user strictly cares about delivery.
      // The original code was just finding the NEAREST GEOMETRIC branch from address.
      // I will replicate that simple geometric search here if that's what's expected,
      // OR I can use my smart logic.
      // The original code iterated all active branches and found the shortest distance.
      // Let's stick to the original behavior for this method to ensure stability.

      final branches = await _getAllBranches();
      if (branches.isEmpty) return 'Old_Airport';

      Branch nearestBranch = branches.first;
      double shortestDistance = double.infinity;

      for (final branch in branches) {
        if (branch.geolocation != null) {
          double distance = Geolocator.distanceBetween(
            userGeoPoint.latitude,
            userGeoPoint.longitude,
            branch.geolocation!.latitude,
            branch.geolocation!.longitude,
          );

          if (distance < shortestDistance) {
            shortestDistance = distance;
            nearestBranch = branch;
          }
        }
      }

      return nearestBranch.id;
    } catch (e) {
      debugPrint('❌ Error finding nearest branch by address: $e');
      return 'Old_Airport';
    }
  }

  Future<String> getNearestBranchByGPS() async {
    try {
      debugPrint('🔍 Finding nearest branch by GPS...');
      Position userPosition = await _getCurrentLocation();

      final branches = await _getAllBranches();
      if (branches.isEmpty) return 'Old_Airport';

      Branch nearestBranch = branches.first;
      double shortestDistance = double.infinity;

      for (final branch in branches) {
        if (branch.geolocation != null) {
          double distance = Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            branch.geolocation!.latitude,
            branch.geolocation!.longitude,
          );

          if (distance < shortestDistance) {
            shortestDistance = distance;
            nearestBranch = branch;
          }
        }
      }
      return nearestBranch.id;
    } catch (e) {
      debugPrint('❌ Error finding nearest branch by GPS: $e');
      return 'Old_Airport';
    }
  }

  Future<String> getNearestBranchByOrderType(String orderType) async {
    if (orderType == 'delivery') {
      return await getNearestBranch();
    } else {
      return await getNearestBranchByGPS();
    }
  }

  String getBranchDisplayName(String branchId) {
    switch (branchId) {
      case 'Old_Airport':
        return 'Old Airport Branch';
      case 'Mansoura':
        return 'Mansoura Branch';
      case 'West_Bay':
        return 'West Bay Branch';
      default:
        return branchId.replaceAll('_', ' ') + ' Branch';
    }
  }

  Future<bool> canBranchDeliverToAddress(
      String branchId, String userEmail) async {
    try {
      if (userEmail.isEmpty) return true;

      final branchDoc =
          await _firestore.collection('Branch').doc(branchId).get();
      if (!branchDoc.exists) return false;

      final branchData = branchDoc.data() as Map<String, dynamic>;
      final noDeliveryRange = (branchData['noDeliveryRange'] ?? 0).toDouble();

      if (noDeliveryRange == 0) return true;

      final userDoc = await _firestore.collection('Users').doc(userEmail).get();
      if (!userDoc.exists) return true;

      final userData = userDoc.data() as Map<String, dynamic>;
      final addresses =
          (userData['address'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (addresses.isEmpty) return true;

      Map<String, dynamic> defaultAddress;
      try {
        defaultAddress = addresses.firstWhere((a) => a['isDefault'] == true);
      } catch (e) {
        defaultAddress = addresses.first;
      }

      if (defaultAddress['geolocation'] == null) return true;

      final userGeoPoint = defaultAddress['geolocation'] as GeoPoint;
      final branchAddress = branchData['address'] as Map<String, dynamic>?;

      if (branchAddress == null || branchAddress['geolocation'] == null)
        return true;

      final branchGeoPoint = branchAddress['geolocation'] as GeoPoint;

      final distance = Geolocator.distanceBetween(
            userGeoPoint.latitude,
            userGeoPoint.longitude,
            branchGeoPoint.latitude,
            branchGeoPoint.longitude,
          ) /
          1000;

      return distance <= noDeliveryRange;
    } catch (e) {
      debugPrint('Error checking delivery availability: $e');
      return true;
    }
  }

  Future<List<Branch>> _getAllBranches() async {
    try {
      final querySnapshot = await _firestore
          .collection('Branch')
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final addressData = data['address'] as Map<String, dynamic>?;
        GeoPoint? geolocation;

        if (addressData != null && addressData['geolocation'] != null) {
          geolocation = addressData['geolocation'] as GeoPoint;
        }

        return Branch(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Branch',
          isActive: data['isActive'] ?? false,
          geolocation: geolocation,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching branches: $e');
      return [];
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  Future<String> getDynamicEtaForUser(String branchId,
      {String orderType = 'delivery'}) async {
    // Mock implementation
    return "30-45 mins";
  }

  // Helper: Haversine distance in km
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.1415926535897932 / 180);
  }
}
