import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';



class ImageCarousel extends StatefulWidget {
  final List<String> images;
  const ImageCarousel({Key? key, required this.images}) : super(key: key);

  @override
  _ImageCarouselState createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late final PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  // you can also make this configurable via widget.height if you prefer

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // cycle every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (widget.images.isEmpty) return;
      _currentPage = (_currentPage + 1) % widget.images.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      setState(() {}); // only rebuild this carousel
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return SizedBox(
        // height: 280,
        child: Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // <-- increased height here -->
        Container(
          // height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            allowImplicitScrolling: true,
            itemBuilder: (ctx, i) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),

        // gradient overlay also needs the same height
        IgnorePointer(
          child: Container(
            // height: 280,  // <-- and here
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),
        ),

        // indicators
        if (widget.images.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class Address {
  final firestore.GeoPoint geolocation; // Use aliased GeoPoint
  final String city;
  final bool isDefault;
  final String label;
  final String street;

  Address({
    required this.city,
    required this.geolocation,
    required this.isDefault,
    required this.label,
    required this.street,
  });

  // Convert an Address object into a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'geolocation': geolocation,
      'isDefault': isDefault,
      'label': label,
      'street': street,
    };
  }

  // Create an Address object from a Map (from Firestore)
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      city: map['city'] ?? '',
      geolocation: map['geolocation'] ?? const firestore.GeoPoint(0, 0), // Use aliased GeoPoint
      isDefault: map['isDefault'] ?? false,
      label: map['label'] ?? '',
      street: map['street'] ?? '',
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String imageUrl;
  final List<Address> addresses; // List of Address objects

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.imageUrl = '',
    this.addresses = const [],
  });

  // Convert an AppUser object into a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'imageUrl': imageUrl,
      'address': addresses.map((address) => address.toJson()).toList(), // Convert list of Address to list of Maps
    };
  }

  // Create an AppUser object from a DocumentSnapshot (from Firestore)
  factory AppUser.fromFirestore(firestore.DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      addresses: (data['address'] as List<dynamic>?)
          ?.map((addrMap) => Address.fromMap(addrMap as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}