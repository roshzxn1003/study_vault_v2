import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline, unknown }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<NetworkStatus> checkStatus() async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  Stream<NetworkStatus> get onStatusChanged => _connectivity.onConnectivityChanged.map((result) {
    if (result.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  });
}

final connectivityServiceProvider = Provider((ref) => ConnectivityService());
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  return ref.watch(connectivityServiceProvider).onStatusChanged;
});
