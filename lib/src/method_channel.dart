import 'package:universal_io/io.dart' as io;
import 'package:flutter/services.dart';
import 'package:flutter_upi_india/src/transaction_details.dart';

class UpiMethodChannel {
  MethodChannel _channel = MethodChannel('flutter_upi_india');
  static final _singleton = UpiMethodChannel._inner();
  factory UpiMethodChannel() {
    return _singleton;
  }
  UpiMethodChannel._inner();

  Future<String?> initiateTransaction(
      TransactionDetails transactionDetails) async {
    if (io.Platform.isAndroid) {
      return await _channel.invokeMethod<String>(
          'initiateTransaction', transactionDetails.toJson());
    }
    throw UnsupportedError(
        'The `initiateTransaction` call is supported only on Android');
  }

  Future<bool?> launch(TransactionDetails transactionDetails) async {
    if (io.Platform.isIOS) {
      return await _channel
          .invokeMethod<bool>('launch', {'uri': transactionDetails.toString()});
    }
    throw UnsupportedError('The `launch` call is supported only on iOS');
  }

  Future<List<Map<dynamic, dynamic>>?> getInstalledUpiApps({
    bool isForMandateApps = false,
  }) async {
    if (io.Platform.isAndroid) {
      return await _channel
          .invokeListMethod<Map<dynamic, dynamic>>('getInstalledUpiApps', {
        'isForMandateApps': isForMandateApps,
      });
    }
    throw UnsupportedError('The `getInstalledUpiApps` call is supported only '
        'on Android');
  }

  Future<bool?> canLaunch(String uriOrScheme) async {
    if (io.Platform.isIOS) {
      final uri = uriOrScheme.contains('://')
          ? uriOrScheme
          : uriOrScheme + '://';
      return await _channel.invokeMethod<bool>('canLaunch', {'uri': uri});
    }
    throw UnsupportedError('The `canLaunch` call is supported only on iOS');
  }
}
