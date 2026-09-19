import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../services/delivery_service.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double? deliveryFee;
  const CheckoutScreen({super.key, this.deliveryFee});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Delivery address state
  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _loadingAddresses = true;
  bool _useCurrentLocation = false;
  Position? _gpsPosition;

  // Delivery fee state
  double? _deliveryFee;

  // Order state
  bool _isPlacingOrder = false;
  String _paymentMethod = 'cod'; // only cod for now

  @override
  void initState() {
    super.initState();
    _deliveryFee = widget.deliveryFee;
    _loadSavedAddresses();
    if (_deliveryFee == null) {
      _loadDeliveryFee();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final locProv = Provider.of<LocationProvider>(context, listen: false);
        if (locProv.currentPosition != null) {
          setState(() => _gpsPosition = locProv.currentPosition);
        }
      }
    });
  }

  Future<void> _loadDeliveryFee() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final fee = await DeliveryService.getEffectiveDeliveryFee(cart.subtotal);
    if (mounted) {
      setState(() => _deliveryFee = fee);
    }
  }

  Future<void> _loadSavedAddresses() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;
    try {
      final response = await SupabaseService.client
          .from('customer_addresses')
          .select()
          .eq('user_id', user.id)
          .order('is_default', ascending: false);
      debugPrint('📍 CheckoutScreen: Loaded ${response.length} addresses for user ${user.id}');
      if (mounted) {
        setState(() {
          _savedAddresses = List<Map<String, dynamic>>.from(response);
          if (_savedAddresses.isNotEmpty && _selectedAddress == null) {
            _selectedAddress = _savedAddresses.firstWhere(
              (a) => a['is_default'] == true,
              orElse: () => _savedAddresses.first,
            );
          }
          _loadingAddresses = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ CheckoutScreen._loadSavedAddresses user_id query failed: $e. Trying fallback...');
      try {
        final response = await SupabaseService.client
            .from('customer_addresses')
            .select()
            .eq('customer_id', user.id)
            .order('is_default', ascending: false);
        if (mounted) {
          setState(() {
            _savedAddresses = List<Map<String, dynamic>>.from(response);
            if (_savedAddresses.isNotEmpty && _selectedAddress == null) {
              _selectedAddress = _savedAddresses.first;
            }
            _loadingAddresses = false;
          });
        }
      } catch (e2) {
        debugPrint('❌ CheckoutScreen._loadSavedAddresses fallback error: $e2');
        if (mounted) setState(() => _loadingAddresses = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locProv = Provider.of<LocationProvider>(context, listen: false);
      final ok = await locProv.requestLocationPermission();
      if (!ok && !locProv.isLocationPermissionGranted) {
        _showError('Location permission was not granted or location services disabled.');
        return;
      }
      if (locProv.currentPosition != null) {
        setState(() => _gpsPosition = locProv.currentPosition);
      } else {
        final position = await Geolocator.getCurrentPosition();
        setState(() => _gpsPosition = position);
      }
    } catch (e) {
      debugPrint('❌ CheckoutScreen._getCurrentLocation error: $e');
      _showError('Could not get location: $e');
    }
  }

  Future<void> _addNewAddress() async {
    final labelCtrl = TextEditingController();
    final lineCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => _AddAddressSheet(
        labelCtrl: labelCtrl,
        lineCtrl: lineCtrl,
      ),
    );
    if (result == true && mounted) {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        _showError('Please log in to save an address.');
        return;
      }
      try {
        final locProv = Provider.of<LocationProvider>(context, listen: false);
        final lat = _gpsPosition?.latitude ?? locProv.currentPosition?.latitude;
        final lng = _gpsPosition?.longitude ?? locProv.currentPosition?.longitude;
        debugPrint('💾 CheckoutScreen: Saving address for user ${user.id} (lat: $lat, lng: $lng)');

        final inserted = await SupabaseService.client
            .from('customer_addresses')
            .insert({
              'user_id': user.id,
              'label': labelCtrl.text.trim(),
              'address_line1': lineCtrl.text.trim(),
              'is_default': _savedAddresses.isEmpty,
              if (lat != null) 'lat': lat,
              if (lng != null) 'lng': lng,
            })
            .select()
            .single();

        debugPrint('✅ CheckoutScreen: Saved address id=${inserted['id']}');
        await _loadSavedAddresses();
        await locProv.loadSavedAddresses();

        if (mounted) {
          setState(() {
            _selectedAddress = inserted;
            _useCurrentLocation = false;
          });
          locProv.selectAddress(inserted);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ CheckoutScreen._addNewAddress error: $e');
        _showError('Could not save address: $e');
      }
    }
  }

  Future<void> _placeOrder() async {
    // Check if store is open
    final locProv = Provider.of<LocationProvider>(context, listen: false);
    if (!locProv.isStoreOpen) {
      _showError(
        'Store is currently unavailable (${locProv.closedReason ?? "Closed for Now"}). Orders cannot be placed at this time.',
      );
      return;
    }

    // Validate address
    if (!_useCurrentLocation && _selectedAddress == null) {
      _showError('Please select or add a delivery address.');
      return;
    }
    if (_useCurrentLocation && _gpsPosition == null) {
      await _getCurrentLocation();
      if (!mounted || _gpsPosition == null) return;
    }

    if (!mounted) return;
    setState(() => _isPlacingOrder = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw 'Not logged in';

      final cart = Provider.of<CartProvider>(context, listen: false);

      // Build delivery address string
      final deliveryAddress = _useCurrentLocation
          ? 'Lat: ${_gpsPosition!.latitude}, Lng: ${_gpsPosition!.longitude}'
          : (_selectedAddress?['address_line1'] ?? _selectedAddress?['address_line'] ?? '');

      final feeToAdd = _deliveryFee ?? 0.0;

      // 1. Create order
      final orderData = {
        'user_id': user.id,
        'total_amount': cart.subtotal + feeToAdd,
        'delivery_address': deliveryAddress,
        'status': 'pending',
        'payment_method': _paymentMethod,
        'payment_status': 'pending',
        'delivery_fee': _deliveryFee,
        'delivery_lat': _useCurrentLocation
            ? _gpsPosition?.latitude
            : (_selectedAddress?['lat'] as num?)?.toDouble(),
        'delivery_lng': _useCurrentLocation
            ? _gpsPosition?.longitude
            : (_selectedAddress?['lng'] as num?)?.toDouble(),
      };

      final orderResponse = await SupabaseService.client
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'] as int;

      // 2. Create order items with variant_id and snapshots
      final orderItems = cart.items.map((item) => {
            'order_id': orderId,
            'product_id': item.productId,
            'variant_id': item.variantId,
            'quantity': item.quantity,
            'price_at_time': item.sellingPrice,
            'mrp_at_time': item.mrp,
            'product_name_snapshot': item.productName,
            'variant_name_snapshot': item.variantName,
            'discount_at_time': item.mrp - item.sellingPrice,
          }).toList();

      await SupabaseService.client.from('order_items').insert(orderItems);

      // 3. Clear cart
      cart.clearCart();

      if (!mounted) return;

      final locProv = Provider.of<LocationProvider>(context, listen: false);
      final estimatedEta = _useCurrentLocation ? locProv.etaMinutes : null;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: orderId,
            estimatedEtaMinutes: estimatedEta,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _showError('Order failed: $e');
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final feeToAdd = _deliveryFee ?? 0.0;
    final grandTotal = cart.subtotal + feeToAdd;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section: Delivery Address ───────────────────────
            _SectionHeader('Delivery Address', Icons.location_on_rounded),
            const SizedBox(height: 12),

            // GPS toggle
            _OptionCard(
              selected: _useCurrentLocation,
              onTap: () async {
                setState(() {
                  _useCurrentLocation = !_useCurrentLocation;
                  if (_useCurrentLocation) _selectedAddress = null;
                });
                if (_useCurrentLocation) {
                  final locProv =
                      Provider.of<LocationProvider>(context, listen: false);
                  locProv.useCurrentGpsLocation();
                  await _getCurrentLocation();
                }
              },
              child: Consumer<LocationProvider>(
                builder: (context, locProv, _) {
                  return Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        color: _useCurrentLocation
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Use Current Location',
                                style: AppTheme.titleSm),
                            if (_useCurrentLocation) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    locProv.formattedEta,
                                    style: AppTheme.captionSm.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      letterSpacing: 0.4,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (locProv.formattedDistance != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppColors.border,
                                            width: 1.0),
                                      ),
                                      child: Text(
                                        locProv.formattedDistance!,
                                        style: AppTheme.captionSm.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Saved addresses
            if (_loadingAddresses)
              const Center(child: CircularProgressIndicator())
            else ...[
              ..._savedAddresses.map((addr) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OptionCard(
                      selected: !_useCurrentLocation &&
                          _selectedAddress?['id'] == addr['id'],
                      onTap: () {
                        setState(() {
                          _selectedAddress = addr;
                          _useCurrentLocation = false;
                        });
                        final locProv = Provider.of<LocationProvider>(context,
                            listen: false);
                        locProv.selectAddress(addr);
                      },
                      child: Row(
                        children: [
                          Icon(
                            addr['label'] == 'Home'
                                ? Icons.home_rounded
                                : addr['label'] == 'Office'
                                    ? Icons.work_rounded
                                    : Icons.location_on_rounded,
                            color: !_useCurrentLocation &&
                                    _selectedAddress?['id'] == addr['id']
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(addr['label'] ?? 'Address',
                                    style: AppTheme.titleSm),
                                Text(
                                    addr['address_line1'] ??
                                        addr['address_line'] ??
                                        '',
                                    style: AppTheme.bodyMd,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add New Address'),
                onPressed: _addNewAddress,
              ),
            ],

            const SizedBox(height: 20),

            // ── Section: Payment ────────────────────────────────
            _SectionHeader('Payment Method', Icons.payment_rounded),
            const SizedBox(height: 12),

            _OptionCard(
              selected: _paymentMethod == 'cod',
              onTap: () => setState(() => _paymentMethod = 'cod'),
              child: Row(
                children: [
                  const Icon(Icons.money_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash on Delivery', style: AppTheme.titleSm),
                      Text('Pay when delivered', style: AppTheme.captionSm),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _OptionCard(
              selected: false,
              enabled: false,
              onTap: null,
              child: Row(
                children: [
                  const Icon(Icons.credit_card_rounded,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Online Payment',
                          style: AppTheme.titleSm
                              .copyWith(color: AppColors.textMuted)),
                      Text('Coming soon',
                          style: AppTheme.captionSm),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text('Soon',
                        style:
                            AppTheme.captionSm.copyWith(color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section: Bill Summary ───────────────────────────
            _SectionHeader('Bill Summary', Icons.receipt_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  _BillRow('Item Total (${cart.itemCount} items)',
                      '₹${cart.subtotal.toStringAsFixed(0)}'),
                  if (_deliveryFee != null) ...[
                    const SizedBox(height: 8),
                    _BillRow(
                      'Delivery Fee',
                      _deliveryFee == 0
                          ? 'FREE'
                          : '₹${_deliveryFee!.toStringAsFixed(0)}',
                      valueColor: _deliveryFee == 0 ? AppColors.success : null,
                    ),
                  ],
                  if (cart.totalSavings > 0) ...[
                    const SizedBox(height: 8),
                    _BillRow(
                      'Total Savings',
                      '-₹${cart.totalSavings.toStringAsFixed(0)}',
                      valueColor: AppColors.success,
                    ),
                  ],
                  const Divider(height: 20),
                  _BillRow(
                    'Grand Total',
                    '₹${grandTotal.toStringAsFixed(0)}',
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<LocationProvider>(
        builder: (context, locProv, _) {
          final isClosed = !locProv.isStoreOpen;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isClosed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                      ),
                      child: Text(
                        'Store is paused (${locProv.closedReason ?? "Closed for Now"}). Ordering is disabled.',
                        style: const TextStyle(
                          color: Color(0xFFBE123C),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isPlacingOrder || isClosed) ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isClosed ? AppColors.textMuted : AppColors.primary,
                      ),
                      child: _isPlacingOrder
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isClosed ? 'Store Currently Unavailable' : 'Place Order',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w700)),
                                if (!isClosed) ...[
                                  const SizedBox(width: 8),
                                  Text('• ₹${grandTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w800)),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTheme.titleMd),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget child;

  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Opacity(opacity: enabled ? 1.0 : 0.5, child: child),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _BillRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: bold ? AppTheme.titleSm : AppTheme.bodyMd),
        Text(
          value,
          style: AppTheme.titleSm.copyWith(
            fontSize: bold ? 16 : 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ── Add New Address bottom sheet ──────────────────────────────────
class _AddAddressSheet extends StatelessWidget {
  final TextEditingController labelCtrl;
  final TextEditingController lineCtrl;

  const _AddAddressSheet(
      {required this.labelCtrl, required this.lineCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add New Address', style: AppTheme.titleMd),
          const SizedBox(height: 20),
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(
              hintText: 'Label (Home, Office, Other)',
              prefixIcon: Icon(Icons.label_outline, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lineCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Full address (door, street, city)',
              prefixIcon: Icon(Icons.home_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (labelCtrl.text.trim().isNotEmpty &&
                    lineCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save Address'),
            ),
          ),
        ],
      ),
    );
  }
}
