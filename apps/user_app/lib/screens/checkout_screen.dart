
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../providers/cart_provider.dart';
import 'home_screen.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _useCurrentLocation = false;
  Position? _currentPosition;
  
  @override
  void initState() {
    super.initState();
    _fetchSavedData();
  }

  Future<void> _fetchSavedData() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await SupabaseService.client
            .from('customers')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        
        if (response != null && mounted) {
          setState(() {
            _addressController.text = response['address'] ?? '';
            _nameController.text = response['full_name'] ?? '';
            _phoneController.text = response['phone_number'] ?? '';
          });
        }
      } catch (e) {
         print("Error fetching profile: $e");
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location fetched successfully!')));
    } catch (e) {
      setState(() {
        _useCurrentLocation = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.isEmpty && !_useCurrentLocation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter delivery address')));
      return;
    }

    if (_useCurrentLocation && _currentPosition == null) {
       await _getCurrentLocation();
       if (_currentPosition == null) return; // Failed to get location
    }

    setState(() => _isLoading = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw "User not logged in";

      final cart = Provider.of<CartProvider>(context, listen: false);

      // 0. Ensure Customer Profile Exists
      try {
         await SupabaseService.client.from('customers').upsert({
           'id': user.id,
           'address': _addressController.text, // Save manual address as default
           'full_name': _nameController.text.isNotEmpty ? _nameController.text : 'User',
           'phone_number': _phoneController.text
         });
      } catch (e) {
          print("Profile update warning: $e");
      }

      // 1. Create Order
      final orderData = {
            'user_id': user.id,
            'total_amount': cart.totalAmount,
            'delivery_address': _addressController.text.isNotEmpty ? _addressController.text : 'Lat: ${_currentPosition?.latitude}, Lng: ${_currentPosition?.longitude}',
            'status': 'pending',
            'delivery_lat': _useCurrentLocation ? _currentPosition?.latitude : null,
            'delivery_lng': _useCurrentLocation ? _currentPosition?.longitude : null,
      };

      final orderResponse = await SupabaseService.client
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'];

      // 2. Create Order Items
      final orderItems = cart.items.map((item) => {
        'order_id': orderId,
        'product_id': item.product['id'],
        'quantity': 1, 
        'price_at_time': item.product['price']
      }).toList();

      await SupabaseService.client.from('order_items').insert(orderItems);

      // 3. Clear Cart
      cart.clearCart();

      if (!mounted) return;
      
      // 4. Navigate to Success Screen
      Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId)), 
          (route) => false
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Summary
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    const Text('Bill Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Item Total'),
                        Text('₹${cart.totalAmount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                     Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                         Text('Delivery Fee'),
                         Text('₹40', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                     Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('To Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('₹${cart.totalAmount + 40}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                 ],
               ),
             ),
             const SizedBox(height: 20),

             // Address Section
            const Text('Delivery Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
             const SizedBox(height: 10),
             TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                hintText: 'Enter your full address',
                prefixIcon: Icon(Icons.home),
                suffixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
              enabled: !_useCurrentLocation, // Disable text input if using GPS
            ),
            
            CheckboxListTile(
              title: const Text("Use Current Location"),
              value: _useCurrentLocation,
              activeColor: Theme.of(context).primaryColor,
              onChanged: (bool? value) {
                setState(() {
                  _useCurrentLocation = value ?? false;
                });
                if (_useCurrentLocation && _currentPosition == null) {
                  _getCurrentLocation();
                }
              },
            ),

            const SizedBox(height: 20),
            
            const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Card(
              child: ListTile(
                title: const Text('Cash on Delivery'),
                leading: const Icon(Icons.money, color: Colors.green),
                trailing: Radio(value: true, groupValue: true, onChanged: (_) {}),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _placeOrder,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('PLACE ORDER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
