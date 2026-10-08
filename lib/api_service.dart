import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

// ---------- حجز (للقوائم) ----------
class Booking {
  final int id;
  final String code, cementType, status;
  final double quantityTon;
  final DateTime date;
  Booking({
    required this.id,
    required this.code,
    required this.cementType,
    required this.quantityTon,
    required this.date,
    required this.status,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['bookingId'],
    code: j['bookingCode'],
    cementType: j['cementType'],
    quantityTon: (j['quantityTon'] as num).toDouble(),
    date: DateTime.parse(j['bookingDate']),
    status: j['status'],
  );
}

// ---------- تفاصيل حجز ----------
class BookingDetails {
  final int id;
  final String code, cementType, status;
  final double quantityTon;
  final DateTime date, createdAt;
  final String? driverName, plateNumber, driverMobile, deliveryLocation;

  BookingDetails({
    required this.id,
    required this.code,
    required this.cementType,
    required this.status,
    required this.quantityTon,
    required this.date,
    required this.createdAt,
    this.driverName,
    this.plateNumber,
    this.driverMobile,
    this.deliveryLocation,
  });

  factory BookingDetails.fromJson(Map<String, dynamic> j) => BookingDetails(
    id: j['bookingId'],
    code: j['bookingCode'],
    cementType: j['cementType'],
    status: j['status'],
    quantityTon: (j['quantityTon'] as num).toDouble(),
    date: DateTime.parse(j['bookingDate']),
    createdAt: DateTime.parse(j['createdAt']),
    driverName: j['driverName'],
    plateNumber: j['plateNumber'],
    driverMobile: j['driverMobile'],
    deliveryLocation: j['deliveryLocation'],
  );
}

// ---------- بيانات العميل ----------
class Me {
  final String fullName, companyName, mobile, commercialReg;
  final int totalBookings, activeBookings;
  Me({
    required this.fullName,
    required this.companyName,
    required this.mobile,
    required this.commercialReg,
    required this.totalBookings,
    required this.activeBookings,
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    fullName: j['fullName'],
    companyName: j['companyName'],
    mobile: j['mobile'],
    commercialReg: j['commercialReg'],
    totalBookings: j['totalBookings'],
    activeBookings: j['activeBookings'],
  );
}

// ---------- إشعار ----------
class AppNotif {
  final int id, bookingId;
  final String bookingCode, status;
  final bool isRead;
  final DateTime createdAt;
  AppNotif({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotif.fromJson(Map<String, dynamic> j) => AppNotif(
    id: j['notificationId'],
    bookingId: j['bookingId'],
    bookingCode: j['bookingCode'],
    status: j['status'],
    isRead: j['isRead'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}

class ApiService {
  static String? _token; // في الذاكرة

  static bool get isLoggedIn => _token != null;
  static void logout() => _token = null;

  static Map<String, String> _headers({bool auth = false}) => {
    'Content-Type': 'application/json',
    if (auth && _token != null) 'Authorization': 'Bearer $_token',
  };

  static dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = null; // الرد مو JSON (غالباً خطأ في السيرفر)
    }
    if (r.statusCode >= 500) {
      throw ApiException('حدث خطأ في السيرفر، حاول مرة أخرى (${r.statusCode})');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    if (r.statusCode == 401) {
      throw ApiException('بيانات الدخول غير صحيحة أو انتهت الجلسة');
    }
    throw ApiException((body is Map && body['error'] != null)
        ? body['error']
        : 'خطأ (${r.statusCode})');
  }

  // ---------- إنشاء حساب ----------
  static Future<void> register({
    required String companyName,
    required String fullName,
    required String mobile,
    required String commercialReg,
    required String password,
  }) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/api/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'companyName': companyName,
          'fullName': fullName,
          'mobile': mobile,
          'commercialReg': commercialReg,
          'password': password,
        }));
    _token = _handle(r)['token'];
  }

  // ---------- تسجيل الدخول ----------
  static Future<void> login(String mobile, String password) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/api/auth/login'),
        headers: _headers(),
        body: jsonEncode({'mobile': mobile, 'password': password}));
    _token = _handle(r)['token'];
  }

  // ---------- بيانات العميل ----------
  static Future<Me> getMe() async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/api/me'),
        headers: _headers(auth: true));
    return Me.fromJson(_handle(r));
  }

  // ---------- قائمة الحجوزات: all | active | completed ----------
  static Future<List<Booking>> getBookings({String filter = 'all'}) async {
    final r = await http.get(
        Uri.parse('${Config.baseUrl}/api/bookings?filter=$filter'),
        headers: _headers(auth: true));
    return (_handle(r) as List).map((e) => Booking.fromJson(e)).toList();
  }

  // ---------- تفاصيل حجز ----------
  static Future<BookingDetails> getBooking(int id) async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/api/bookings/$id'),
        headers: _headers(auth: true));
    return BookingDetails.fromJson(_handle(r));
  }

  // ---------- إنشاء حجز ----------
  static Future<Booking> createBooking({
    required String cementType,
    required double quantityTon,
    required DateTime bookingDate,
    String? bookingTime,
    String? driverName,
    String? plateNumber,
    String? driverMobile,
    String? deliveryLocation,
  }) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/api/bookings'),
        headers: _headers(auth: true),
        body: jsonEncode({
          'cementType': cementType,
          'quantityTon': quantityTon,
          'bookingDate': bookingDate.toIso8601String(),
          'bookingTime': bookingTime,
          'driverName': driverName,
          'plateNumber': plateNumber,
          'driverMobile': driverMobile,
          'deliveryLocation': deliveryLocation,
        }));
    return Booking.fromJson(_handle(r));
  }

  // ---------- الإشعارات ----------
  static Future<List<AppNotif>> getNotifications() async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/api/notifications'),
        headers: _headers(auth: true));
    return (_handle(r) as List).map((e) => AppNotif.fromJson(e)).toList();
  }

  static Future<void> markNotificationsRead() async {
    final r = await http.post(
        Uri.parse('${Config.baseUrl}/api/notifications/read-all'),
        headers: _headers(auth: true));
    _handle(r);
  }

  // ---------- إلغاء حجز (فقط بانتظار التأكيد) ----------
  static Future<void> cancelBooking(int id) async {
    final r = await http.delete(Uri.parse('${Config.baseUrl}/api/bookings/$id'),
        headers: _headers(auth: true));
    _handle(r);
  }
}