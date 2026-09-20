import 'package:avaremp/instruments/autopilot.dart';
import 'package:avaremp/io/autopilot_udp_sender.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Settings for pushing the autopilot NMEA sentences out over UDP.
class AutopilotUdpScreen extends StatefulWidget {
  const AutopilotUdpScreen({super.key});

  @override
  State<StatefulWidget> createState() => AutopilotUdpScreenState();
}

class AutopilotUdpScreenState extends State<AutopilotUdpScreen> {
  late bool _enabled;
  late String _mode;
  late final TextEditingController _host;
  late final TextEditingController _port;

  @override
  void initState() {
    super.initState();
    final settings = Storage().settings;
    _enabled = settings.getApUdpEnabled();
    _mode = settings.getApUdpMode();
    _host = TextEditingController(text: settings.getApUdpHost());
    _port = TextEditingController(text: settings.getApUdpPort().toString());
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _savePort(String text) {
    final int? port = int.tryParse(text);
    if (port != null && port > 0 && port < 65536) {
      Storage().settings.setApUdpPort(port);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool unicast = _mode == AutopilotUdpSender.modeUnicast;
    final AutopilotUdpSender sender = Storage().autopilotUdp;

    return Scaffold(
      appBar: AppBar(title: const Text('Autopilot UDP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Sends the same RMC, GGA, RMB and BOD sentences as the Bluetooth "
            "autopilot output, once a second, as one UDP datagram.",
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text("Enable"),
            value: _enabled,
            onChanged: (bool value) {
              setState(() => _enabled = value);
              Storage().settings.setApUdpEnabled(value);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text("Destination", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioGroup<String>(
            groupValue: _mode,
            onChanged: (String? value) {
              if (value == null) return;
              setState(() => _mode = value);
              Storage().settings.setApUdpMode(value);
            },
            child: const Column(
              children: [
                RadioListTile<String>(
                  title: Text("Broadcast"),
                  subtitle: Text("Every device on the local network (255.255.255.255)"),
                  value: AutopilotUdpSender.modeBroadcast,
                ),
                RadioListTile<String>(
                  title: Text("Unicast"),
                  subtitle: Text("One device, by IP address"),
                  value: AutopilotUdpSender.modeUnicast,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _host,
              enabled: unicast,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Host IP address",
                hintText: "192.168.1.50",
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) => Storage().settings.setApUdpHost(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "UDP port",
                hintText: "${AutopilotUdpSender.defaultPort}",
                border: OutlineInputBorder(),
              ),
              onChanged: _savePort,
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ValueListenableBuilder<int>(
            valueListenable: sender.sentCount,
            builder: (context, int count, _) => ListTile(
              dense: true,
              leading: const Icon(Icons.outbox),
              title: Text("Datagrams sent: $count"),
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: sender.lastError,
            builder: (context, String? error, _) => error == null
                ? const SizedBox.shrink()
                : ListTile(
                    dense: true,
                    leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                    title: Text(error),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.send),
              label: const Text("Send one now"),
              onPressed: _enabled
                  ? () => sender.send(AutoPilot.apCreateSentences())
                  : null,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "To check from a computer on the same network:\n"
              "  nc -ul 10110\n"
              "(replace 10110 with the port above)",
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
