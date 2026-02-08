
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'order_tracking_screen.dart';
import 'order_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final response = await SupabaseService.client.from('products').select();
    if (mounted) {
      setState(() {
        _products = response;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // We access user strictly to show Login button or Avatar, and active orders
    final user = Provider.of<AuthProvider>(context).user;
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. App Bar with Location & Profile
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Theme.of(context).primaryColor, size: 18),
                    const SizedBox(width: 4),
                    const Text('Delivering to', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Row(
                  children: [
                     Text('Current Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                     Icon(Icons.keyboard_arrow_down, color: Colors.black),
                  ],
                ),
              ],
            ),
            actions: [
               IconButton(
                icon: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Icon(Icons.person, color: user != null ? Theme.of(context).primaryColor : Colors.grey),
                ),
                onPressed: () {
                  if (user == null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  } else {
                    // Profile or Logout sheet
                       showModalBottomSheet(context: context, builder: (_) => Container(
                      height: 250, // Increased height
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                           Text('Logged in as ${user.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 20),
                           ListTile(
                             leading: const Icon(Icons.history),
                             title: const Text("Your Orders"),
                             onTap: () {
                               Navigator.pop(context);
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
                             },
                           ),
                           const Spacer(),
                           ElevatedButton(
                             onPressed: () async {
                               await SupabaseService.client.auth.signOut();
                               if (mounted) Navigator.pop(context);
                             },
                             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                             child: const Text('Logout'),
                           )
                        ],
                      ),
                    ));
                  }
                },
              ),
            ],
          ),

          // 2. Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search "Biryani"',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),

          // 3. Banner
          SliverToBoxAdapter(
             child: Container(
               margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
               height: 140,
               decoration: BoxDecoration(
                 gradient: LinearGradient(colors: [const Color(0xFFFF6D00), Colors.orange.shade300]),
                 borderRadius: BorderRadius.circular(16),
               ),
               child: Stack(
                 children: [
                   Positioned(
                     left: 20,
                     top: 30,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: const [
                         Text('Fastest Delivery', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                         Text('Get 50% OFF on first order', style: TextStyle(color: Colors.white, fontSize: 14)),
                       ],
                     ),
                   ),
                   // Ideally an image here
                   const Positioned(
                     right: 10,
                     bottom: 10,
                     child: Icon(Icons.fastfood, size: 80, color: Colors.white24),
                   ),
                 ],
               ),
             ),
          ),

          // 4. Categories (Simplified)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                   _buildCategoryItem('Biryani', Icons.rice_bowl),
                   _buildCategoryItem('Pizza', Icons.local_pizza),
                   _buildCategoryItem('Burger', Icons.lunch_dining),
                   _buildCategoryItem('Drinks', Icons.local_drink),
                   _buildCategoryItem('Dessert', Icons.icecream),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Recommended for you', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          )),

          // 5. Product Grid
          if (_isLoading) 
             const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = _products[index];
                    return _buildProductCard(context, product);
                  },
                  childCount: _products.length,
                ),
              ),
            ),
             
          // Space for Floating Widget and Cart Bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      // Floating Cart Bar if Items > 0
      bottomNavigationBar: cart.items.isNotEmpty ? SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${cart.items.length} ITEM${cart.items.length > 1 ? "S" : ""}', 
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('₹${cart.totalAmount}', 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton(
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                },
                child: const Row(
                  children: [
                    Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_right_alt, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ) : null,
      
      floatingActionButton: user != null ? _buildActiveOrderFab(context, user.id) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCategoryItem(String title, IconData icon) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(icon, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, dynamic product) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(child: Icon(Icons.fastfood, size: 40, color: Colors.grey[300])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(product['size'] ?? 'Standard', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₹${product['price']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    InkWell(
                      onTap: () {
                         cart.addToCart(product);
                         ScaffoldMessenger.of(context).hideCurrentSnackBar();
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'), duration: Duration(milliseconds: 500)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).primaryColor),
                        ),
                        child: Text('ADD', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderFab(BuildContext context, String userId) {
     return StreamBuilder(
        stream: SupabaseService.client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .map((maps) => maps),
        builder: (context, snapshot) {
          if (!snapshot.hasData || (snapshot.data as List).isEmpty) return const SizedBox.shrink();
          
          final order = (snapshot.data as List)[0];
          final status = order['status'];
          if (status == 'delivered' || status == 'cancelled') return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 80.0), // Above bottom bar
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order['id']))),
              backgroundColor: Colors.blue.shade900,
              icon: const Icon(Icons.delivery_dining, color: Colors.white),
              label: Text('Track Order #${order['id']}', style: const TextStyle(color: Colors.white)),
            ),
          );
        },
      );
  }
}
