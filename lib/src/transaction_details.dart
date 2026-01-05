import 'package:decimal/decimal.dart';
import 'package:flutter_upi_india/src/applications.dart';
import 'package:flutter_upi_india/src/exceptions.dart';

class TransactionDetails {
  static const String _currency = 'INR';
  static const int _maxAmount = 100000;

  final UpiApplication upiApplication;
  final String payeeAddress;
  final String payeeName;
  final String transactionRef;
  final String currency;
  final Decimal amount;
  final String? url;
  final String? merchantCode;
  final String? transactionNote;
  final bool isForMandate;

  // Mandate-specific parameters
  final String? amountRule;
  final String? blockFlag;
  final String? merchantName;
  final String? mode;
  final String? orgId;
  final String? purpose;
  final String? recurrence;
  final String? recurrenceType;
  final String? recurrenceValue;
  final String? revocable;
  final String? transactionId;
  final String? txnType;
  final String? validityStart;
  final String? validityEnd;

  TransactionDetails({
    required this.upiApplication,
    required this.payeeAddress,
    required this.payeeName,
    required this.transactionRef,
    this.currency = TransactionDetails._currency,
    required String amount,
    this.url,
    this.merchantCode = '',
    this.transactionNote = 'UPI Transaction',
    this.isForMandate = false,
    this.amountRule,
    this.blockFlag,
    this.merchantName,
    this.mode,
    this.orgId,
    this.purpose,
    this.recurrence,
    this.recurrenceType,
    this.recurrenceValue,
    this.revocable,
    this.transactionId,
    this.txnType,
    this.validityStart,
    this.validityEnd,
  }) : amount = Decimal.parse(amount) {
    if (!_checkIfUpiAddressIsValid(payeeAddress)) {
      throw InvalidUpiAddressException();
    }
    final Decimal am = Decimal.parse(amount);
    if (am.scale > 2) {
      throw InvalidAmountException(
          'Amount must not have more than 2 digits after decimal point');
    }
    if (am <= Decimal.zero) {
      throw InvalidAmountException('Amount must be greater than 1');
    }
    if (am > Decimal.fromInt(_maxAmount)) {
      throw InvalidAmountException(
          'Amount must be less then 1,00,000 since that is the upper limit '
          'per UPI transaction');
    }
  }

  Map<String, dynamic> toJson() {
    final json = {
      'app': upiApplication.toString(),
      'pa': payeeAddress,
      'pn': payeeName,
      'tr': transactionRef,
      'cu': currency,
      'am': amount.toString(),
      'url': url,
      'mc': merchantCode,
      'tn': transactionNote,
      'isForMandate': isForMandate,
    };

    // Add mandate-specific parameters if available
    if (amountRule != null) json['amrule'] = amountRule;
    if (blockFlag != null) json['block'] = blockFlag;
    if (merchantName != null) json['mn'] = merchantName;
    if (mode != null) json['mode'] = mode;
    if (orgId != null) json['orgid'] = orgId;
    if (purpose != null) json['purpose'] = purpose;
    if (recurrence != null) json['recur'] = recurrence;
    if (recurrenceType != null) json['recurtype'] = recurrenceType;
    if (recurrenceValue != null) json['recurvalue'] = recurrenceValue;
    if (revocable != null) json['rev'] = revocable;
    if (transactionId != null) json['tid'] = transactionId;
    if (txnType != null) json['txnType'] = txnType;
    if (validityStart != null) json['validitystart'] = validityStart;
    if (validityEnd != null) json['validityend'] = validityEnd;

    return json;
  }

  String toString() {
    final authority = isForMandate ? 'mandate' : 'pay';
    String uri = 'upi://$authority?pa=$payeeAddress'
        '&pn=${Uri.encodeComponent(payeeName)}'
        '&tr=$transactionRef'
        '&tn=${Uri.encodeComponent(transactionNote!)}'
        '&am=${amount.toString()}'
        '&cu=$currency';
    if (url != null && url!.isNotEmpty) {
      uri += '&url=${Uri.encodeComponent(url!)}';
    }
    if (merchantCode!.isNotEmpty) {
      uri += '&mc=${Uri.encodeComponent(merchantCode!)}';
    }

    // Add mandate-specific parameters if available
    if (isForMandate) {
      if (amountRule != null) uri += '&amrule=$amountRule';
      if (blockFlag != null) uri += '&block=$blockFlag';
      if (merchantName != null) uri += '&mn=${Uri.encodeComponent(merchantName!)}';
      if (mode != null) uri += '&mode=$mode';
      if (orgId != null) uri += '&orgid=$orgId';
      if (purpose != null) uri += '&purpose=$purpose';
      if (recurrence != null) uri += '&recur=$recurrence';
      if (recurrenceType != null) uri += '&recurtype=$recurrenceType';
      if (recurrenceValue != null) uri += '&recurvalue=$recurrenceValue';
      if (revocable != null) uri += '&rev=$revocable';
      if (transactionId != null) uri += '&tid=$transactionId';
      if (txnType != null) uri += '&txnType=$txnType';
      if (validityStart != null) uri += '&validitystart=$validityStart';
      if (validityEnd != null) uri += '&validityend=$validityEnd';
    }

    return uri;
  }
}

bool _checkIfUpiAddressIsValid(String upiAddress) {
  return upiAddress.split('@').length == 2;
}
