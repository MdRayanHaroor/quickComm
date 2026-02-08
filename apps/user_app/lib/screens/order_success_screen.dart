
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'home_screen.dart';
import 'order_tracking_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final int orderId;
  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation (Load from network for simplicity, or asset if added)
            // Using a reliable network URL for a checkmark
            Lottie.network(
              'https://assets2.lottiefiles.com/packages/lf20_t24tpvcu.json', // Official Lottie Checkmark
              controller: _controller,
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..forward();
              },
              height: 200,
              width: 200,
              repeat: false,
            ),
            const SizedBox(height: 20),
            const Text('Order Placed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 10),
            Text('Order #${widget.orderId} has been confirmed.', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 40),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: widget.orderId)));
                    }, 
                    child: const Text('Track Order'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                       Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
                    },
                    child: const Text('Back to Home'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
