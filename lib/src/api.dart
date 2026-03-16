import 'dart:async';

// for meta
import 'package:flutter_upi_india/src/discovery.dart';
import 'package:flutter_upi_india/src/meta.dart';
import 'package:flutter_upi_india/src/method_channel.dart';
import 'package:flutter_upi_india/src/response.dart';
import 'package:flutter_upi_india/src/applications.dart';
import 'package:flutter_upi_india/src/exceptions.dart';
import 'package:flutter_upi_india/src/transaction.dart';
import 'package:flutter_upi_india/src/transaction_details.dart';

/// Helps with getting installed UPI apps and making payments using them.
///
/// The [getInstalledUpiApplications] API helps getting installed applications.
///
/// The [initiateTransaction] API helps with making a transaction using a chosen
/// UPI payment app.
class UpiPay {
  static final UpiMethodChannel _channel = UpiMethodChannel();
  static final UpiApplicationDiscovery _discovery = UpiApplicationDiscovery();
  static final UpiTransactionHelper _transactionHelper = UpiTransactionHelper();

  /// Start a UPI Transaction.
  ///
  /// The parameters correspond to respective parameters in the
  /// [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf).
  /// Their names as appearing in the specification have been mentioned.
  ///
  /// [app] represents a UPI payment app. One of the static members of
  /// [UpiApplication].
  ///
  /// [receiverUpiAddress] is recipient UPI VPA. An invalid value will result
  /// in [InvalidUpiAddressException]. See `pa` in [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf).
  ///
  /// [receiverName] is the name of the recipient. See `pn` in specification.
  ///
  /// [transactionRef] is an ID (typically unique if you need to
  /// identify each payment) for the UPI transaction. On Android its value is
  /// copied back in the response from the UPI payment app. See `tr` in
  /// [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf).
  ///
  /// [amount] must be a string form of payment amount and must be valid
  /// currency (no more than 2 digits after decimal). The package also limits
  /// it to be <=1,00,000. An unacceptable value leads to
  /// [InvalidAmountException]. Some UPI payment apps or your payer account
  /// may have their own permanent or daily limits, which this package cannot
  /// control towards ensuring payment. See `am` in [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf).
  ///
  /// [transactionNote] is a short description of the transaction. See `tn` in
  /// [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf).
  ///
  /// [url]: See `url` parameter in [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf)
  ///
  /// [isForMandate] switches the request to use the `upi://mandate` authority.
  ///
  /// Mandate-specific parameters:
  /// [amountRule] - Amount rule (MAX, EXACT, etc.)
  /// [blockFlag] - Block flag (Y/N)
  /// [merchantName] - Merchant name or identifier
  /// [mode] - Payment mode
  /// [orgId] - Organization ID
  /// [purpose] - Payment purpose code
  /// [recurrence] - Recurrence pattern (ASPRESENTED, MONTHLY, etc.)
  /// [recurrenceType] - Recurrence type (AFTER, BEFORE, etc.)
  /// [recurrenceValue] - Recurrence value/count
  /// [revocable] - Revocable flag (Y/N)
  /// [transactionId] - Transaction ID
  /// [txnType] - Transaction type (CREATE, REVOKE, etc.)
  /// [validityStart] - Validity start date (DDMMYYYY)
  /// [validityEnd] - Validity end date (DDMMYYYY)
  static Future<UpiTransactionResponse> initiateTransaction({
    required UpiApplication app,
    required String receiverUpiAddress,
    required String receiverName,
    required String transactionRef,
    required String amount,
    String? url,
    String? merchantCode,
    String? transactionNote,
    bool isForMandate = false,
    String? amountRule,
    String? blockFlag,
    String? merchantName,
    String? mode,
    String? orgId,
    String? purpose,
    String? recurrence,
    String? recurrenceType,
    String? recurrenceValue,
    String? revocable,
    String? transactionId,
    String? txnType,
    String? validityStart,
    String? validityEnd,
  }) async {
    final transactionDetails = TransactionDetails(
      upiApplication: app,
      payeeAddress: receiverUpiAddress,
      payeeName: receiverName,
      transactionRef: transactionRef,
      amount: amount,
      url: url,
      merchantCode: merchantCode,
      transactionNote: transactionNote,
      isForMandate: isForMandate,
      amountRule: amountRule,
      blockFlag: blockFlag,
      merchantName: merchantName,
      mode: mode,
      orgId: orgId,
      purpose: purpose,
      recurrence: recurrence,
      recurrenceType: recurrenceType,
      recurrenceValue: recurrenceValue,
      revocable: revocable,
      transactionId: transactionId,
      txnType: txnType,
      validityStart: validityStart,
      validityEnd: validityEnd,
    );
    return await _transactionHelper.transact(_channel, transactionDetails);
  }

  /// Finds installed UPI payment applications.
  ///
  /// Default behaviour is to present all applications verified to be working
  /// properly.
  ///
  /// [statusType] can be used to change the default behaviour. Setting it to
  /// [UpiApplicationDiscoveryAppStatusType.workingWithWarnings] will fetch
  /// all apps that work but produce a "unverified source" or relevant error
  /// caused due to lack of using the merchant's signature parameter in this
  /// package (See `mc` and `sign` in [UPI Linking Specification](https://www.npci.org.in/sites/default/files/UPI%20Linking%20Specs_ver%201.6.pdf)).
  /// Currently this package does not implement merchant payments as per the
  /// specification, and rather helps with individual-to-individual payments
  /// that do not require merchant details. It's an upcoming feature. Setting
  /// [statusType] to [UpiApplicationDiscoveryAppStatusType.all] will fetch all
  /// the apps. UPI researchers can use this value to experiment with the
  /// UPI apps this package can detect.
  ///
  /// [paymentType] must be [UpiApplicationDiscoveryAppPaymentType.nonMerchant]
  /// for now. Setting it to any other value will lead to [UnsupportedError].
  ///
  /// [isForMandateApps] filters apps that advertise UPI mandate support where
  /// platform discovery supports it.
  ///
  /// The [statusType] parameter is kept for backward compatibility but is no
  /// longer used for filtering — all installed UPI apps are returned.
  static Future<List<ApplicationMeta>> getInstalledUpiApplications({
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    UpiApplicationDiscoveryAppStatusType statusType =
        UpiApplicationDiscoveryAppStatusType.working,
    bool isForMandateApps = false,
  }) async {
    if (paymentType != UpiApplicationDiscoveryAppPaymentType.nonMerchant) {
      throw UnsupportedError('The parameter `paymentType` must be '
          '`UpiApplicationDiscoveryAppPaymentType.nonMerchant`');
    }
    return await _discovery.discover(
      upiMethodChannel: _channel,
      paymentType: paymentType,
      isForMandateApps: isForMandateApps,
    );
  }
}
