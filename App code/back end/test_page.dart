import 'package:flutter/material.dart';
import 'api_service.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String _out = 'اضغط الزر';

  Future<void> _run() async {
    try {
      await ApiService.login('0509998877', '12345678');
      final list = await ApiService.getBookings();
      setState(() => _out = 'نجح الاتصال ✅ عدد الحجوزات: ${list.length}');
    } catch (e) {
      setState(() => _out = 'خطأ: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_out, textDirection: TextDirection.rtl),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _run, child: const Text('اختبر الاتصال')),
      ]),
    ),
  );
}