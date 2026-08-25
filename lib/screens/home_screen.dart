import 'package:flutter/material.dart';

import '../theme.dart';
import 'help_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screens = [SendScreen(), ReceiveScreen(), HelpScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QR Share', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('شارك أي ملف بكود',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim)),
              ],
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.primary.withOpacity(0.35),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file_rounded),
            label: 'إرسال',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'استقبال',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help_rounded),
            label: 'إزاي بيشتغل؟',
          ),
        ],
      ),
    );
  }
}
