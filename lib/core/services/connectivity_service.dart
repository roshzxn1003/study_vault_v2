import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline, unknown }

class ConnectivityService {
  final Connectivity _connectivity;
  NetworkStatus? _testOverrideStatus;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @visibleForTesting
  void setOverrideStatusForTesting(NetworkStatus? status) {
    _testOverrideStatus = status;
  }

  /// Checks whether internet connectivity is genuinely active and reachable.
  Future<NetworkStatus> checkStatus() async {
    if (_testOverrideStatus != null) return _testOverrideStatus!;

    try {
      final result = await _connectivity.checkConnectivity();
      if (result.contains(ConnectivityResult.none)) {
        return NetworkStatus.offline;
      }

      // Verify actual host reachability to prevent captive portals or dead Wi-Fi
      final isReachable = await _checkReachability();
      return isReachable ? NetworkStatus.online : NetworkStatus.offline;
    } catch (_) {
      return NetworkStatus.unknown;
    }
  }

  /// Verifies reachability via DNS lookup with bounded timeout.
  Future<bool> _checkReachability() async {
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Stream of network status changes.
  Stream<NetworkStatus> get onStatusChanged {
    return _connectivity.onConnectivityChanged.asyncMap((result) async {
      if (_testOverrideStatus != null) return _testOverrideStatus!;
      if (result.contains(ConnectivityResult.none)) {
        return NetworkStatus.offline;
      }
      final reachable = await _checkReachability();
      return reachable ? NetworkStatus.online : NetworkStatus.offline;
    });
  }
}

final connectivityServiceProvider = Provider((ref) => ConnectivityService());
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  return ref.watch(connectivityServiceProvider).onStatusChanged;
});
