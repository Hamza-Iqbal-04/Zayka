import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../Widgets/authentication.dart';
import 'cartScreen.dart';
import '../Widgets/models.dart';
import '../main.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import '../Screens/HomeScreen.dart';// For FilteringTextInputFormatter

class _MapUI {
  static const Color fieldFill   = Color(0xFFF5F7FA);
  static const Color stroke      = Color(0xFFE0E6ED);
  static const Color mapBorder   = Color(0xFFE0E6ED);
  static const Color searchFocus = Color(0xFFCCE4FF);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  File? _profileImage;
  bool _isLoggingOut = false;

  get pickImage => null;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });

    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('Users').doc(user.email).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyProfile(user);
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildProfileContent(context, user, userData);
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, User user, Map<String, dynamic> userData) {
    return CustomScrollView(
      slivers: [
        // Modern App Bar with Gradient
        SliverAppBar(
          expandedHeight: 220.0,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue,
                    Color(0xFF1E40AF),
                    Color(0xFF1D4ED8),
                  ],
                ),
              ),
              child: _buildModernHeader(context, user, userData),
            ),
          ),
        ),
        // Content
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Column(
                  children: [
                    _buildModernProfileMenu(context, user),
                    const SizedBox(height: 30),
                    _buildModernLogoutButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernHeader(BuildContext context, User user, Map<String, dynamic> userData) {
    String displayName = userData['name'] ?? user.email?.split('@').first ?? 'User';
    String email = user.email ?? 'No email available';
    String? imageUrl = userData['imageUrl'];

    // In buildModernHeader
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12), // CHANGED: was 20

            // Profile Image
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 40, // CHANGED: was 55
                      backgroundColor: Colors.white,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (imageUrl != null ? NetworkImage(imageUrl) : null) as ImageProvider?,
                      child: (_profileImage == null && imageUrl == null)
                          ? Icon(Icons.person, size: 36, color: Colors.grey.shade400) // CHANGED: was 60
                          : null,
                    ),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      color: AppColors.primaryBlue,
                      iconSize: 18, // slightly smaller for proportional look
                      onPressed: pickImage,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12), // CHANGED: was 20

            // Name
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20, // CHANGED: was 28
                fontWeight: FontWeight.w600, // CHANGED: was w700
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 6), // CHANGED: was 8

            // Email chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // CHANGED: was 12 & 6
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                email,
                style: const TextStyle(
                  fontSize: 12, // CHANGED: was 14
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

  }

  Widget _buildModernProfileMenu(BuildContext context, User user) {
    final menuItems = [
      {
        'icon': Icons.person_outline_rounded,
        'title': 'Edit Profile',
        'subtitle': 'Update your personal information',
        'color': const Color(0xFF3B82F6),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
        ),
      },
      {
        'icon': Icons.location_on_outlined,
        'title': 'Saved Addresses',
        'subtitle': 'Manage your delivery locations',
        'color': const Color(0xFF10B981),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SavedAddressesScreen()),
        ),
      },
      {
        'icon': Icons.favorite_border_rounded,
        'title': 'My Favorites',
        'subtitle': 'View your liked items',
        'color': const Color(0xFFEC4899),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FavoritesScreen()),
        ),
      },
      {
        'icon': Icons.help_outline_rounded,
        'title': 'Help & Support',
        'subtitle': 'Get help and contact us',
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
        ),
      },
    ];

    return Column(
      children: menuItems.asMap().entries.map((entry) {
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: item['onTap'] as VoidCallback,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModernLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoggingOut ? null : _logout,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _isLoggingOut ? null : LinearGradient(
                colors: [Colors.red.shade50, Colors.red.shade50],
              ),
            ),
            child: Center(
              child: _isLoggingOut
                  ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                ),
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LOGOUT',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProfile(User user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue,
            Color(0xFF1E40AF),
            Color(0xFF1D4ED8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Welcome, ${user.email?.split('@').first ?? 'User'}!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your profile is not yet set up.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Set Up Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _profileImage;
  String? _initialImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (widget.user.email == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(widget.user.email).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _initialImageUrl = data['imageUrl'];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || widget.user.email == null) return;
    setState(() => _isLoading = true);
    try {
      // TODO: If _profileImage is not null, upload it to Firebase Storage
      await FirebaseFirestore.instance.collection('Users').doc(widget.user.email).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': widget.user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfilePicture(),
              const SizedBox(height: 32),
              _buildTextField(
                controller: _nameController,
                labelText: 'Full Name',
                icon: Icons.person_outline,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _phoneController,
                labelText: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your phone number' : null,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildProfilePicture() {
    ImageProvider? backgroundImage;
    if (_profileImage != null) {
      backgroundImage = FileImage(_profileImage!);
    } else if (_initialImageUrl != null) {
      backgroundImage = NetworkImage(_initialImageUrl!);
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: backgroundImage,
            child: backgroundImage == null ? Icon(Icons.person, size: 60, color: Colors.grey.shade500) : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET WITH CHANGES ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      cursorColor: AppColors.primaryBlue, // Set cursor color to blue
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white,
        // Style for the label when it's floating (field is focused or has text)
        floatingLabelStyle: const TextStyle(color: AppColors.primaryBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        // Style for the border when the field is focused
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2.0),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
      color: Colors.grey[100],
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({Key? key}) : super(key: key);

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController labelController;
  late TextEditingController streetController;
  late TextEditingController buildingController;
  late TextEditingController floorController;
  late TextEditingController flatController;
  late TextEditingController cityController;
  late TextEditingController searchController;
  late MapController mapController;

  @override
  void initState() {
    super.initState();
    labelController = TextEditingController();
    streetController = TextEditingController();
    buildingController = TextEditingController();
    floorController = TextEditingController();
    flatController = TextEditingController();
    cityController = TextEditingController();
    searchController = TextEditingController();
    mapController = MapController();
  }

  @override
  void dispose() {
    labelController.dispose();
    streetController.dispose();
    buildingController.dispose();
    floorController.dispose();
    flatController.dispose();
    cityController.dispose();
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<LatLng?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _updateAddresses(List<Map<String, dynamic>> updatedAddresses) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    try {
      await _firestore.collection('Users').doc(user.email).update({'address': updatedAddresses});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating addresses: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _setAsDefault(int index, List<Map<String, dynamic>> addresses) async {
    final updatedAddresses = addresses.map((addr) => {...addr, 'isDefault': false}).toList();
    updatedAddresses[index]['isDefault'] = true;
    await _updateAddresses(updatedAddresses);
  }

  Future<void> _deleteAddress(int index, List<Map<String, dynamic>> addresses) async {
    final updatedAddresses = List<Map<String, dynamic>>.from(addresses);
    updatedAddresses.removeAt(index);
    await _updateAddresses(updatedAddresses);
  }

  void _showAddEditAddressSheet({
    Map<String, dynamic>? address,
    int? index,
    List<Map<String, dynamic>>? allAddresses,
  }) async {
    final isEditing = address != null;

    // Set controller texts based on editing or adding
    labelController.text = isEditing ? address!['label'] ?? '' : '';
    streetController.text = isEditing ? address!['street'] ?? '' : '';
    buildingController.text = isEditing ? address!['building'] ?? '' : '';
    floorController.text = isEditing ? address!['floor'] ?? '' : '';
    flatController.text = isEditing ? address!['flat'] ?? '' : '';
    cityController.text = isEditing ? address!['city'] ?? '' : '';
    searchController.clear(); // Clear search for new modal

    GeoPoint? selectedGeoPoint = isEditing ? address!['geolocation'] : null;

    LatLng initialCenter = const LatLng(28.6139, 77.2090);
    if (!isEditing) {
      final current = await _getCurrentLocation();
      if (current != null) {
        initialCenter = current;
        selectedGeoPoint = GeoPoint(current.latitude, current.longitude);
        await _reverseGeocode(
            current.latitude, current.longitude, streetController, cityController, buildingController, floorController, flatController);
      }
    } else if (selectedGeoPoint != null) {
      initialCenter = LatLng(selectedGeoPoint.latitude, selectedGeoPoint.longitude);
    }

    // Use the persistent mapController

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft : Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Text(
                        isEditing ? 'Edit Address' : 'Add New Address',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        height: 350,
                        decoration: BoxDecoration(
                          border: Border.all(color: _MapUI.mapBorder),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            initialCenter: initialCenter,
                            initialZoom  : 13,
                            onTap: (tapPos, point) async {
                              if (!mounted) return;
                              selectedGeoPoint = GeoPoint(point.latitude, point.longitude);
                              await _reverseGeocode(point.latitude, point.longitude,
                                  streetController, cityController, buildingController, floorController, flatController);
                              modalSetState(() {}); // Force rebuild to reflect changes
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                              additionalOptions: const {
                                'userAgent': 'MitraDaDhabaApp/1.0 (contact: your.email@example.com)'
                              },
                            ),
                            if (selectedGeoPoint != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(selectedGeoPoint!.latitude, selectedGeoPoint!.longitude),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_pin, color: Colors.red, size: 32),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap on the map to select a location',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search location…',
                          filled: true,
                          fillColor: Colors.grey[200],
                          prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2.5),
                          ),
                        ),
                        onSubmitted: (query) async {
                          if (!mounted) return;
                          await _forwardGeocode(
                            query,
                            streetController,
                            cityController,
                            buildingController,
                            floorController,
                            flatController,
                            selectedGeoPoint!,
                            mapController,
                          );
                          modalSetState(() {}); // Force rebuild after search
                        },
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: labelController,
                        decoration: InputDecoration(
                          labelText: 'Label (e.g., Home, Work)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: streetController,
                        decoration: InputDecoration(
                          labelText: 'Street Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: buildingController,
                        keyboardType: TextInputType.number, // Set keyboard type
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Building',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: floorController,
                        keyboardType: TextInputType.number, // Set keyboard type
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Floor',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: flatController,
                        keyboardType: TextInputType.number, // Set keyboard type
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Flat',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: cityController,
                        decoration: InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!mounted) return;

                            final newAddress = {
                              'label'      : labelController.text,
                              'street'     : streetController.text,
                              'building'   : buildingController.text,
                              'floor'      : floorController.text,
                              'flat'       : flatController.text,
                              'city'       : cityController.text,
                              'isDefault'  : isEditing ? address!['isDefault'] : false,
                              'geolocation': selectedGeoPoint ?? const GeoPoint(0, 0),
                            };

                            // ---- FIX: always use a copy, never an empty list (unless really empty) ---
                            final currentAddresses = allAddresses != null
                                ? List<Map<String, dynamic>>.from(allAddresses!)
                                : <Map<String, dynamic>>[];

                            if (isEditing) {
                              // Defensive: check index bounds
                              if (index != null && index < currentAddresses.length) {
                                currentAddresses[index] = newAddress;
                              }
                            } else {
                              currentAddresses.add(newAddress);
                            }

                            await _updateAddresses(currentAddresses);
                            if (mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEditing ? 'SAVE CHANGES' : 'ADD ADDRESS'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _reverseGeocode(double lat, double lng, TextEditingController streetController, TextEditingController cityController, TextEditingController buildingController, TextEditingController floorController, TextEditingController flatController) async {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1';
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'MitraDaDhabaApp/1.0 (contact: your.email@example.com)', 'accept-language': 'en'
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final addressDetails = data['address'] ?? {};

      // Parse detailed fields
      streetController.text = addressDetails['road'] ?? addressDetails['street'] ?? '';
      buildingController.text = addressDetails['building'] ?? '';
      floorController.text = addressDetails['floor'] ?? ''; // Might not be available
      flatController.text = addressDetails['house_number'] ?? addressDetails['flat'] ?? '';
      cityController.text = addressDetails['city'] ?? addressDetails['town'] ?? addressDetails['village'] ?? '';
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch address'))
        );
      }
    }
  }

  Future<void> _forwardGeocode(
      String query,
      TextEditingController streetController,
      TextEditingController cityController,
      TextEditingController buildingController,
      TextEditingController floorController,
      TextEditingController flatController,
      GeoPoint selectedGeoPoint,
      MapController mapController) async {
    if (query.isEmpty) return;
    final url = 'https://nominatim.openstreetmap.org/search?format=json&q=$query&addressdetails=1&limit=1';
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'MitraDaDhabaApp/1.0 (contact: your.email@example.com)', 'accept-language': 'en'
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final result = data[0];
        final lat = double.parse(result['lat']);
        final lon = double.parse(result['lon']);
        selectedGeoPoint = GeoPoint(lat, lon);
        mapController.move(LatLng(lat, lon), 13.0);
        await _reverseGeocode(lat, lon, streetController, cityController, buildingController, floorController, flatController);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Saved Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: user == null || user.email == null
          ? const Center(child: Text('Please sign in to view addresses.'))
          : StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('Users').doc(user.email).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final addresses = (data['address'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (addresses.isEmpty) {
            return _buildEmptyState();
          }
          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return _buildAddressCard(
                    context: context,
                    address: address,
                    onEdit: () => _showAddEditAddressSheet(
                      address: address,
                      index: index,
                      allAddresses: addresses,
                    ),
                    onDelete: () => _deleteAddress(index, addresses),
                    onSetDefault: () => _setAsDefault(index, addresses),
                  );
                },
              ),
              // Add address FAB handled _outside_ the StreamBuilder
            ],
          );
        },
      ),
      floatingActionButton: Builder(
        // Needed to get latest addresses from the current StreamBuilder context
        builder: (context) {
          final user = _auth.currentUser;
          if (user == null || user.email == null) return const SizedBox.shrink();
          return StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('Users').doc(user.email).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return FloatingActionButton.extended(
                  onPressed: () => _showAddEditAddressSheet(allAddresses: <Map<String, dynamic>>[]),
                  label: const Text('Add New Address'),
                  icon: const Icon(Icons.add),
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final addresses = (data['address'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              return FloatingActionButton.extended(
                onPressed: () => _showAddEditAddressSheet(allAddresses: addresses),
                label: const Text('Add New Address'),
                icon: const Icon(Icons.add),
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text('No Addresses Saved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Add an address to get started with your orders.', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAddressCard({
    required BuildContext context,
    required Map<String, dynamic> address,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onSetDefault,
  }) {
    final bool isDefault = address['isDefault'] ?? false;
    final String label = address['label'] ?? 'No Label';
    final IconData iconData = label.toLowerCase().contains('home')
        ? Icons.home_outlined
        : (label.toLowerCase().contains('work') ? Icons.work_outline : Icons.location_on_outlined);

    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('DEFAULT', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Divider(height: 24),
            Text(
              '${address['street'] ?? ''}, Building: ${address['building'] ?? ''}, Floor: ${address['floor'] ?? ''}, Flat: ${address['flat'] ?? ''}, ${address['city'] ?? ''}',
              style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('Set as Default'),
                  ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.grey[600], size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _removeFavorite(String itemId) async {
    // ... (Your existing _removeFavorite logic)
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    try {
      await _firestore.collection('Users').doc(user.email).update({
        'favorites.$itemId': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites.'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing favorite: ${e.toString()}')),
        );
      }
    }
  }

  void _addItemToCart(Map<String, dynamic> itemData, String itemId) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final menuItem = MenuItem(
      id: itemId,
      name: itemData['name'] ?? 'Unknown Dish',
      description: itemData['description'] ?? '',
      price: (itemData['price'] ?? 0.0).toDouble(),
      imageUrl: itemData['imageUrl'] ?? '',
      tags: {'isSpicy': itemData['isSpicy'] ?? false},
      branchIds: [''], // NEW - wrap in array
      categoryId: '',
      isAvailable: true,
      isPopular: false,
      sortOrder: 0,
      variants: const {},
    );
    cartService.addToCart(menuItem);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${menuItem.name} added to cart'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Favorites', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: user == null || user.email == null
          ? const Center(child: Text('Please sign in to view your favorites.'))
          : StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('Users').doc(user.email).snapshots(),
        builder: (context, snapshot) {
          // ... (Your existing StreamBuilder logic)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final favorites = (data['favorites'] as Map<String, dynamic>?) ?? {};
          if (favorites.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Add bottom padding to avoid overlap with cart bar
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final itemId = favorites.keys.elementAt(index);
              final itemData = favorites[itemId] as Map<String, dynamic>;
              return _buildFavoriteItem(
                itemId: itemId,
                itemData: itemData,
              );
            },
          );
        },
      ),
      // --- NEW: Add the persistent cart bar here ---
      bottomNavigationBar: ListenableBuilder(
        listenable: CartService(), // Listens for changes in the cart
        builder: (context, child) {
          // Rebuilds the bar whenever the cart is updated
          return _buildPersistentCartBar();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    // ... (Your existing _buildEmptyState widget)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('No Favorites Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the bookmark icon on any dish to save it for later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem({required String itemId, required Map<String, dynamic> itemData}) {
    // ... (Your existing _buildFavoriteItem widget)
    final String name = itemData['name'] ?? 'Unknown Dish';
    final double price = (itemData['price'] ?? 0.0).toDouble();
    final String imageUrl = itemData['imageUrl'] ?? '';
    final bool isSpicy = itemData['isSpicy'] ?? false;
    return InkWell(
      onTap: () => _addItemToCart(itemData, itemId),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.grey))
                      : const Icon(Icons.fastfood, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('QAR ${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primaryBlue, fontSize: 15, fontWeight: FontWeight.bold)),
                        if (isSpicy) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.local_fire_department, color: Colors.red.shade600, size: 18),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _removeFavorite(itemId),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.blueAccent,  // ← Use red for heart
                    size: 20,
                  ),

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW: Copied your widget from MainScreen ---
  Widget _buildPersistentCartBar() {
    final cartService = CartService();
    final itemCount = cartService.itemCount;
    final totalAmount = cartService.totalAmount;
    if (itemCount == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Adjusted for safe area
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: Text('$itemCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      const Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Text('QAR ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Background for contrast
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- First Group: General Help ---
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                'GET HELP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            _buildOptionContainer(
              children: [
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'FAQs',
                  onTap: () {
                    // TODO: Navigate to FAQs screen
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.email_outlined,
                  title: 'Contact Us',
                  onTap: () {
                    // TODO: Navigate to contact form or show contact info
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.chat_outlined,
                  title: 'Live Chat',
                  onTap: () {
                    // TODO: Implement or navigate to live chat
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // --- Second Group: Legal Information ---
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                'LEGAL INFORMATION',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            _buildOptionContainer(
              children: [
                _buildMenuItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {
                    // TODO: Show terms of service
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {
                    // TODO: Show privacy policy
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // A helper widget to create the card-like container for menu items
  Widget _buildOptionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // A helper widget for each individual menu item (ListTile)
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
