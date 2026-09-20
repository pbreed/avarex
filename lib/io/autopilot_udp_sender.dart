import 'dart:convert';

import 'package:avaremp/storage.dart';
import 'package:avaremp/utils/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

/// Pushes the autopilot NMEA sentences (RMC, GGA, RMB, BOD) out over UDP,
/// alongside the Bluetooth SPP path that only exists on Android. All four
/// sentences go in one datagram, the same grouping the Bluetooth path writes.
///
/// Broadcast mode sends to 255.255.255.255 so anything on the local Wi-Fi
/// picks it up with no configuration; unicast sends to a single host.
class AutopilotUdpSender {
  static const String modeBroadcast = "Broadcast";
  static const String modeUnicast = "Unicast";
  static const int defaultPort = 10110; // common NMEA-over-UDP port

  RawDatagramSocket? _socket;
  bool _binding = false;
  String? _lastError;

  /// Datagrams sent since startup, for the status line in the settings UI.
  final ValueNotifier<int> sentCount = ValueNotifier<int>(0);

  /// Most recent failure, or null when the last send worked.
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  Future<void> send(String data) async {
    if (!Storage().settings.getApUdpEnabled() || data.isEmpty) {
      return;
    }

    final InternetAddress? target = _target();
    if (target == null) {
      _fail("Unicast host is not a valid IP address");
      return;
    }

    await sendTo(data, target, Storage().settings.getApUdpPort());
  }

  /// Settings-free core: one datagram to [target]:[port]. Returns true when
  /// the bytes were handed to the socket.
  Future<bool> sendTo(String data, InternetAddress target, int port) async {
    final RawDatagramSocket? socket = await _ensureSocket();
    if (socket == null) {
      return false;
    }

    try {
      final int written = socket.send(utf8.encode(data), target, port);
      if (written > 0) {
        sentCount.value++;
        _ok();
        return true;
      }
      _fail("Send returned 0 bytes");
    } catch (e) {
      _fail("Send failed: $e");
      // A failed socket (e.g. network went away) is dropped and re-bound
      // on the next tick.
      _socket?.close();
      _socket = null;
    }
    return false;
  }

  void close() {
    _socket?.close();
    _socket = null;
  }

  InternetAddress? _target() {
    if (Storage().settings.getApUdpMode() == modeBroadcast) {
      return InternetAddress("255.255.255.255");
    }
    return InternetAddress.tryParse(Storage().settings.getApUdpHost().trim());
  }

  Future<RawDatagramSocket?> _ensureSocket() async {
    if (_socket != null) {
      return _socket;
    }
    if (_binding) {
      return null; // a bind from the previous tick is still in flight
    }
    _binding = true;
    try {
      final RawDatagramSocket socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      _socket = socket;
      return socket;
    } catch (e) {
      _fail("Cannot open UDP socket: $e");
      return null;
    } finally {
      _binding = false;
    }
  }

  void _ok() {
    if (_lastError != null) {
      _lastError = null;
      lastError.value = null;
    }
  }

  // Sends run once a second, so log a problem when it first appears rather
  // than every tick.
  void _fail(String message) {
    if (_lastError != message) {
      _lastError = message;
      lastError.value = message;
      AppLog.logMessage("Autopilot UDP: $message");
    }
  }
}
