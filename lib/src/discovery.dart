import 'dart:convert';

import 'package:universal_io/io.dart' as io;
import 'package:flutter_upi_india/src/applications.dart';
import 'package:flutter_upi_india/src/method_channel.dart';
import 'package:flutter_upi_india/src/meta.dart';

class UpiApplicationDiscovery implements _PlatformDiscoveryBase {
  final discovery = io.Platform.isAndroid
      ? _AndroidDiscovery()
      : io.Platform.isIOS
          ? _IosDiscovery()
          : null;
  static final _singleton = UpiApplicationDiscovery._inner();
  factory UpiApplicationDiscovery() {
    return _singleton;
  }
  UpiApplicationDiscovery._inner();

  @override
  Future<List<ApplicationMeta>> discover({
    required UpiMethodChannel upiMethodChannel,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    bool isForMandateApps = false,
  }) async {
    if (io.Platform.isAndroid || io.Platform.isIOS) {
      return await discovery!.discover(
        upiMethodChannel: upiMethodChannel,
        paymentType: paymentType,
        isForMandateApps: isForMandateApps,
      );
    }
    throw UnsupportedError('Discovery is available only on Android and iOS');
  }
}

class _AndroidDiscovery implements _PlatformDiscoveryBase {
  static final _singleton = _AndroidDiscovery._inner();
  factory _AndroidDiscovery() {
    return _singleton;
  }
  _AndroidDiscovery._inner();

  @override
  Future<List<ApplicationMeta>> discover({
    required UpiMethodChannel upiMethodChannel,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    bool isForMandateApps = false,
  }) async {
    // Accessing UpiApplication.all forces all static app instances to
    // initialize, which populates UpiApplication.lookUpMap as a side effect.
    UpiApplication.all;
    final appsList = await upiMethodChannel.getInstalledUpiApps(
      isForMandateApps: isForMandateApps,
    );
    if (appsList == null) return [];
    final List<ApplicationMeta> retList = [];
    appsList.forEach((app) {
      final packageName = _castToString(app['packageName']);
      if (!UpiApplication.lookUpMap.containsKey(packageName)) return;
      final icon = _castToString(app['icon']);
      final priority = _castToInt(app['priority']);
      final preferredOrder = _castToInt(app['preferredOrder']);
      retList.add(ApplicationMeta.android(
        UpiApplication.lookUpMap[packageName]!,
        base64.decode(icon),
        priority,
        preferredOrder,
      ));
    });
    return retList;
  }
}

class _IosDiscovery implements _PlatformDiscoveryBase {
  static final _singleton = _IosDiscovery._inner();
  factory _IosDiscovery() {
    return _singleton;
  }
  _IosDiscovery._inner();

  @override
  Future<List<ApplicationMeta>> discover({
    required UpiMethodChannel upiMethodChannel,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    bool isForMandateApps = false,
  }) async {
    if (isForMandateApps) {
      final bool? supportsMandate =
          await upiMethodChannel.canLaunch('upi://mandate');
      if (supportsMandate != true) {
        return [];
      }
    }

    // Accessing UpiApplication.all forces all static app instances to
    // initialize, which populates UpiApplication.lookUpMap as a side effect.
    UpiApplication.all;

    // Build a scheme -> app map for all apps that have a discoveryCustomScheme
    Map<String, UpiApplication> discoveryMap = {};
    UpiApplication.lookUpMap.forEach((bundleId, app) {
      if (app.discoveryCustomScheme != null) {
        discoveryMap[app.discoveryCustomScheme!] = app;
      }
    });

    List<UpiApplication> discovered = [];
    final keys = discoveryMap.keys.toList();
    for (int idx = 0; idx < discoveryMap.length; ++idx) {
      final scheme = keys[idx];
      try {
        final bool? result = await upiMethodChannel.canLaunch(scheme);
        if (result == true) {
          discovered.add(discoveryMap[scheme]!);
        }
      } catch (error, stack) {
        print(error);
        print(stack);
      }
    }

    if (discovered.isEmpty) return [];
    final metas = await Future.wait(discovered.map((app) async {
      final resolved = await _resolveIOSAppIcon(
        appName: app.appName,
        bundleIdHint: app.iosBundleId,
      );
      return ApplicationMeta.ios(
        app,
        iconUrl: resolved.logoUrl,
      );
    }));
    return metas;
  }
}

Future<({String? logoUrl, String? bundleId})> _resolveIOSAppIcon({
  required String appName,
  String? bundleIdHint,
}) async {
  try {
    final hasBundleHint = bundleIdHint != null && bundleIdHint.contains('.');
    final uri = hasBundleHint
        ? Uri.https("itunes.apple.com", "/lookup", {
            "bundleId": bundleIdHint,
            "country": "in",
          })
        : Uri.https("itunes.apple.com", "/search", {
            "term": appName,
            "country": "in",
            "entity": "software",
            "limit": "5",
          });

    final data = await _getJson(uri);
    if (data == null) return (logoUrl: null, bundleId: null);

    if (data["resultCount"] > 0 && data["results"] is List) {
      final results = List<Map<String, dynamic>>.from(data["results"]);
      final targetName = _normalizeAppName(appName);
      Map<String, dynamic>? best;

      if (hasBundleHint) {
        best = results.firstWhere(
          (item) => item["bundleId"]?.toString() == bundleIdHint,
          orElse: () => results.first,
        );
      } else {
        best = results.firstWhere(
          (item) =>
              _normalizeAppName(item["trackName"]?.toString() ?? "") ==
              targetName,
          orElse: () => results.first,
        );
      }

      return (
        logoUrl: best["artworkUrl100"]?.toString() ??
            best["artworkUrl60"]?.toString(),
        bundleId: best["bundleId"]?.toString(),
      );
    }
  } catch (error) {
    print("Error resolving iOS app icon: $error");
  }
  return (logoUrl: null, bundleId: null);
}

Future<Map<String, dynamic>?> _getJson(Uri uri) async {
  final client = io.HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (error) {
    print("Error fetching iOS app icon metadata: $error");
  } finally {
    client.close(force: true);
  }
  return null;
}

String _normalizeAppName(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

abstract class _PlatformDiscoveryBase {
  Future<List<ApplicationMeta>> discover({
    required UpiMethodChannel upiMethodChannel,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    bool isForMandateApps = false,
  });
}

String _castToString(dynamic val) {
  if (val is String) {
    return val;
  }
  throw TypeError();
}

int _castToInt(dynamic val) {
  if (val is int) {
    return val;
  }
  throw TypeError();
}

/// Represents the type of payments in the apps that user wants to access.
///
/// Passed as [paymentType] parameter of [UpiPay.getInstalledUpiApplications]
/// API.
enum UpiApplicationDiscoveryAppPaymentType {
  /// Individual-to-individual payment type. Currently the only accepted type.
  nonMerchant,

  /// Merchant payment type. Currently not accepted.
  merchant,

  /// Both individual-to-individual and merchant payment types. Not accepted
  /// currently.
  both,
}

/// Kept for backward compatibility. Status-based filtering has been removed —
/// all discovered/installed UPI apps are returned regardless of status.
enum UpiApplicationDiscoveryAppStatusType {
  all,
  workingWithWarnings,
  working,
}
