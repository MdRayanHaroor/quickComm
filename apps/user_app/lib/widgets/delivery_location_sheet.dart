import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class DeliveryLocationSheet extends StatefulWidget {
  const DeliveryLocationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => const DeliveryLocationSheet(),
    );
  }

  @override
  State<DeliveryLocationSheet> createState() => _DeliveryLocationSheetState();
}

class _DeliveryLocationSheetState extends State<DeliveryLocationSheet> {
  bool _isAddingNew = false;
  final _labelCtrl = TextEditingController(text: 'Home');
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _landmarkCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_line1Ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an address line.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final locProv = Provider.of<LocationProvider>(context, listen: false);
    final success = await locProv.addNewAddress(
      label: _labelCtrl.text.trim(),
      addressLine1: _line1Ctrl.text.trim(),
      addressLine2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
      landmark: _landmarkCtrl.text.trim().isEmpty ? null : _landmarkCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _saving = false;
        if (success) {
          _isAddingNew = false;
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not save address. Please ensure you are signed in.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locProv = Provider.of<LocationProvider>(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isAddingNew ? 'Add Delivery Address' : 'Select Delivery Location',
                    style: AppTheme.titleLg.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      if (_isAddingNew) {
                        setState(() => _isAddingNew = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (!_isAddingNew) ...[
                // Current GPS Option
                _LocationOptionTile(
                  title: 'Current Location',
                  subtitle: locProv.isLocationPermissionGranted
                      ? (locProv.formattedDistance != null
                          ? 'Distance: ${locProv.formattedDistance} • Delivery in ${locProv.formattedEta}'
                          : 'Location permission enabled')
                      : 'Tap to allow location access',
                  icon: Icons.my_location_rounded,
                  isSelected: locProv.selectedAddress == null &&
                      locProv.isLocationPermissionGranted,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    if (!locProv.isLocationPermissionGranted) {
                      await locProv.requestLocationPermission();
                    } else {
                      locProv.useCurrentGpsLocation();
                    }
                    if (mounted) nav.pop();
                  },
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Saved Addresses Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Addresses',
                      style: AppTheme.titleSm.copyWith(color: AppColors.textSecondary),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _isAddingNew = true),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add New'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (locProv.savedAddresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No saved addresses yet.',
                        style: AppTheme.bodyMd.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...locProv.savedAddresses.map((addr) {
                    final isSelected = locProv.selectedAddress?['id'] == addr['id'];
                    final label = addr['label']?.toString() ?? 'Home';
                    final line = addr['address_line1']?.toString() ??
                        addr['address_line']?.toString() ??
                        '';
                    final landmark = addr['landmark']?.toString();
                    final subtitle = landmark != null && landmark.isNotEmpty
                        ? '$line, Near $landmark'
                        : line;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LocationOptionTile(
                        title: label,
                        subtitle: subtitle,
                        icon: label.toLowerCase() == 'work'
                            ? Icons.work_outline_rounded
                            : Icons.home_outlined,
                        isSelected: isSelected,
                        onTap: () {
                          locProv.selectAddress(addr);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }),
              ] else ...[
                // Add Address Form
                Row(
                  children: ['Home', 'Work', 'Other'].map((lbl) {
                    final isSel = _labelCtrl.text == lbl;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(lbl),
                        selected: isSel,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _labelCtrl.text = lbl),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _line1Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Flat / House No. / Building / Street *',
                    prefixIcon: Icon(Icons.business_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _line2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Area / Sector / Colony (Optional)',
                    prefixIcon: Icon(Icons.map_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _landmarkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Landmark',
                          prefixIcon: Icon(Icons.place_rounded, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          prefixIcon: Icon(Icons.pin_drop_rounded, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save & Deliver Here',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocationOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleSm.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.captionSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
