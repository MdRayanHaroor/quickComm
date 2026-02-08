import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import 'tracking_screen.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    // final user = Provider.of<AuthProvider>(context, listen: false).user; // Removed direct provider access here, using SupabaseService directly in button

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return ListTile(
                  title: Text(item.product['name']),
                  subtitle: Text('Quantity: ${item.quantity}'),
                  trailing: Text('₹${item.product['price'] * item.quantity}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Total: ₹${cart.totalAmount}', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: cart.items.isEmpty ? null : () {
                    final user = SupabaseService.client.auth.currentUser;
                    if (user == null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen(returnToCheckout: true)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                    }
                  },
                  child: const Text('Proceed to Checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
