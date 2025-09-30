import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../Widgets/models.dart';

class PaymentService {
  static const String _apiKey = '3ebee910-5232-488b-a7c0-6d5dbcd67a32';
  static const String _baseUrl =
      'https://api.fatora.io'; // Sandbox or production

  Future<Map<String, dynamic>> createPayment({
    required double amount,
    required String currency,
    required String customerEmail,
    required String customerName,
    required String orderId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'customer_email': customerEmail,
          'customer_name': customerName,
          'order_id': orderId,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
          'metadata': {
            'order_id': orderId,
          },
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Payment creation failed');
      }

      return responseData;
    } catch (e) {
      throw Exception('Payment error: $e');
    }
  }

  Future<Map<String, dynamic>> verifyPayment(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/payments/$paymentId'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(
            responseData['message'] ?? 'Payment verification failed');
      }

      return responseData;
    } catch (e) {
      throw Exception('Verification error: $e');
    }
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({required this.url, required this.title, Key? key})
      : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Handle error
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check for payment success/failure URLs
            if (request.url.contains('payment-success')) {
              Navigator.pop(context, true); // Payment success
              return NavigationDecision.prevent;
            } else if (request.url.contains('payment-cancel')) {
              Navigator.pop(context, false); // Payment cancelled
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
              ),
            ),
        ],
      ),
    );
  }
}