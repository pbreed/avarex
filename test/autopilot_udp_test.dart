// Loopback test of the autopilot UDP sender: bind a receiver on localhost,
// push a four-sentence block through the sender, and check it arrives as one
// datagram, byte for byte.
import 'dart:async';
import 'dart:convert';

import 'package:avaremp/io/autopilot_udp_sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';

void main() {
  test('four sentences arrive as one datagram', () async {
    final RawDatagramSocket receiver =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final Completer<Datagram> received = Completer<Datagram>();
    receiver.listen((RawSocketEvent e) {
      final Datagram? dg = receiver.receive();
      if (dg != null && !received.isCompleted) {
        received.complete(dg);
      }
    });

    const String block =
        '\$GPRMC,120000,A,3245.0000,N,11710.0000,W,95.0,270.0,190926,12.0,E*00\r\n'
        '\$GPGGA,120000,3245.0000,N,11710.0000,W,6,00,0.0,1500.0,M,-32.0,M,,*00\r\n'
        '\$GPRMB,A,0.10,L,SRC,DST,3300.0000,N,11800.0000,W,42.0,275.0,95.0,V*00\r\n'
        '\$GPBOD,275.0,T,263.0,M,DST,SRC*00\r\n';

    final AutopilotUdpSender sender = AutopilotUdpSender();
    final bool ok = await sender.sendTo(
        block, InternetAddress.loopbackIPv4, receiver.port);
    expect(ok, isTrue);

    final Datagram dg =
        await received.future.timeout(const Duration(seconds: 5));
    expect(utf8.decode(dg.data), block);
    expect(sender.sentCount.value, 1);
    expect(sender.lastError.value, isNull);

    sender.close();
    receiver.close();
  });

  test('socket is reused across sends', () async {
    final RawDatagramSocket receiver =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final List<int> sourcePorts = [];
    final Completer<void> gotTwo = Completer<void>();
    receiver.listen((RawSocketEvent e) {
      final Datagram? dg = receiver.receive();
      if (dg != null) {
        sourcePorts.add(dg.port);
        if (sourcePorts.length == 2 && !gotTwo.isCompleted) {
          gotTwo.complete();
        }
      }
    });

    final AutopilotUdpSender sender = AutopilotUdpSender();
    await sender.sendTo('one', InternetAddress.loopbackIPv4, receiver.port);
    await sender.sendTo('two', InternetAddress.loopbackIPv4, receiver.port);
    await gotTwo.future.timeout(const Duration(seconds: 5));

    expect(sourcePorts[0], sourcePorts[1],
        reason: 'a new socket per send would show a new source port');
    expect(sender.sentCount.value, 2);

    sender.close();
    receiver.close();
  });
}
