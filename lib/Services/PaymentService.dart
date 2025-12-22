import 'package:flutter/material.dart';
import 'package:myfatoorah_flutter/myfatoorah_flutter.dart';

class PaymentService {
  // Public Test Token (Kuwait)
  static const String _apiToken = 'SK_KWT_vVZlnnAqu8jRByOWaRPNId4ShzEDNt256dvnjebuyzo52dXjAfRx2ixW5umjWSUx';

  /// Initialize the SDK
  static Future<void> init() async {
    try {
      await MFSDK.init(_apiToken, MFCountry.KUWAIT, MFEnvironment.TEST);
      // V3 Method: setUpActionBar (instead of setUpAppBar)
      MFSDK.setUpActionBar(
        toolBarTitle: "Checkout",
        toolBarTitleColor: '#FFFFFF',
        toolBarBackgroundColor: '#004E92',
        isShowToolBar: true,
      );
    } catch (e) {
      debugPrint("MyFatoorah Init Error: $e");
    }
  }

  /// Get Payment Methods
  static Future<List<MFPaymentMethod>> getPaymentMethods(double invoiceAmount) async {
    try {
      var request = MFInitiatePaymentRequest(
        invoiceAmount: invoiceAmount,
        currencyIso: MFCurrencyISO.KUWAIT_KWD,
      );

      // V3 Method: returns response directly
      final response = await MFSDK.initiatePayment(request, MFLanguage.ENGLISH);

      return response.paymentMethods ?? [];
    } catch (e) {
      debugPrint("Error fetching methods: $e");
      rethrow;
    }
  }

  /// Execute Payment
  static Future<void> executePayment({
    required int paymentMethodId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
    required Function(String invoiceId) onSuccess,
    required Function(String errorMessage) onFailure,
  }) async {
    try {
      var request = MFExecutePaymentRequest(
        invoiceValue: amount,
        paymentMethodId: paymentMethodId,
      );

      request.customerName = customerName;
      request.customerEmail = customerEmail;
      request.customerMobile = customerMobile;
      request.displayCurrencyIso = MFCurrencyISO.KUWAIT_KWD;

      // V3 Method: No context passed, different callback structure
      await MFSDK.executePayment(
        request,
        MFLanguage.ENGLISH,
            (String invoiceId) {
          debugPrint("Invoice Created: $invoiceId");
          onSuccess(invoiceId);
        },
      ).then((value) {
        debugPrint("Payment Finished");
      }).catchError((error) {
        onFailure(error.toString());
      });

    } catch (e) {
      onFailure(e.toString());
    }
  }
}