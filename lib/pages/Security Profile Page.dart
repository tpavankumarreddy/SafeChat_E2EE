import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_checker_plus/root_checker_plus.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

class SecurityProfilePage extends StatefulWidget {
  final bool isBiometricEnabled;
  SecurityProfilePage({
    super.key,
    required this.isBiometricEnabled,

  });

  @override
  _SecurityProfilePageState createState() => _SecurityProfilePageState();

}

class _SecurityProfilePageState extends State<SecurityProfilePage> {
  int securityScore = 100;
  List<Map<String, dynamic>> securityLogs = [];
  bool rootedCheck = false;
  bool devMode = false;
  bool vpnActive = false;

  @override
  void initState() {
    super.initState();
    checkSecurityThreats();
  }

  Future<void> androidRootChecker() async {
    try {
      bool isRooted = (await RootCheckerPlus.isRootChecker()) ?? false;
      setState(() {
        rootedCheck = isRooted;
      });
    } on PlatformException {
      setState(() {
        rootedCheck = false;
      });
    }
  }

  Future<void> developerMode() async {
    bool devModeStatus = false;
    try {
      devModeStatus = (await RootCheckerPlus.isDeveloperMode()) ?? false;
    } on PlatformException {
      devModeStatus = false;
    }

    setState(() {
      devMode = devModeStatus;
    });
  }

  Future<void> checkVPN() async {
    try {
      bool isVpnConnected = await VpnConnectionDetector.isVpnActive();
      setState(() {
        vpnActive = isVpnConnected;
        if (vpnActive) {
          securityLogs.add({"event": "VPN/Proxy Usage Detected", "severity": "Medium", "status": "Warning"});
          securityScore -= 10; // Reduce less score for VPN
        } else {
          securityLogs.add({"event": "No VPN/Proxy Detected", "severity": "Low", "status": "Passed"});
        }
      });
    } catch (e) {
      debugPrint("VPN check failed: $e");
    }
  }

  Future<void> checkSecurityThreats() async {
    int score = 100;
    securityLogs.clear();

    if (Platform.isAndroid) {
      await androidRootChecker();
      await developerMode();
    }

    await checkVPN();

    if (rootedCheck) {
      securityLogs.add({"event": "Rooted Device Detected", "severity": "High", "status": "Failed"});
      score -= 40;
    } else {
      securityLogs.add({"event": "Rooted Device Not Detected", "severity": "Low", "status": "Passed"});
    }

    if (devMode) {
      securityLogs.add({"event": "Developer Mode Enabled", "severity": "Medium", "status": "Failed"});
      score -= 20;
    } else {
      securityLogs.add({"event": "Developer Mode Disabled", "severity": "Low", "status": "Passed"});
    }

    if (widget.isBiometricEnabled) {
      securityLogs.add({"event": "Biometric Lock Enabled", "severity": "Low", "status": "Passed"});
      score += 10; // Increase security score if biometrics is enabled
    } else {
      securityLogs.add({"event": "Biometric Lock Disabled", "severity": "Medium", "status": "Warning"});
      score -= 10; // Reduce security score if biometrics is disabled
    }

    setState(() {
      securityScore = score.clamp(0, 100); // Ensure score stays between 0 and 100
    });

    debugPrint("VPN Status: $vpnActive");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Security Profile")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: securityScore >= 80 ? Colors.green : securityScore >= 50 ? Colors.orange : Colors.red,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text("Security Score", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 10),
                    Text("$securityScore", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text("Security Logs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: securityLogs.length,
                itemBuilder: (context, index) {
                  final log = securityLogs[index];
                  return Card(
                    child: ListTile(
                      title: Text(log["event"] ?? "Unknown Event"),
                      subtitle: Text("Severity: ${log["severity"]}"),
                      trailing: Text("Status: ${log["status"]}"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
