import 'dart:math';

import '../models/models.dart';

class MockIdentity {
  final String farmerId;
  final String name;
  final String mobile;
  final String village;
  final String crop;

  const MockIdentity(
    this.farmerId,
    this.name,
    this.mobile,
    this.village,
    this.crop,
  );
}

class AuthService {
  static const officialUsers = <OfficialIdentity>[
    OfficialIdentity(
      officialId: 'OFF001',
      name: 'Amit Sharma',
      centreId: 'A',
      role: OfficialRole.centreManager,
    ),
    OfficialIdentity(
      officialId: 'OFF002',
      name: 'Neha Verma',
      centreId: 'B',
      role: OfficialRole.centreManager,
    ),
    OfficialIdentity(
      officialId: 'DIST001',
      name: 'Rohit Mehta',
      centreId: '*',
      role: OfficialRole.districtOfficer,
    ),
    OfficialIdentity(
      officialId: 'ADMIN001',
      name: 'System Administrator',
      centreId: '*',
      role: OfficialRole.admin,
    ),
  ];

  static const profiles = <MockIdentity>[
    MockIdentity(
      'F001',
      'Raj Kumar',
      '98XXXX1001',
      'Najafgarh',
      'Wheat',
    ),
    MockIdentity(
      'F002',
      'Suresh Yadav',
      '98XXXX1002',
      'Dhansa',
      'Paddy',
    ),
    MockIdentity(
      'F003',
      'Sunita Devi',
      '98XXXX1003',
      'Kair',
      'Mustard',
    ),
    MockIdentity(
      'F004',
      'Mohan Singh',
      '98XXXX1004',
      'Roshanpura',
      'Wheat',
    ),
    MockIdentity(
      'F005',
      'Geeta Sharma',
      '98XXXX1005',
      'Najafgarh',
      'Paddy',
    ),
    MockIdentity(
      'F006',
      'Ramesh Verma',
      '98XXXX1006',
      'Dhansa',
      'Mustard',
    ),
    MockIdentity(
      'F007',
      'Kavita Rani',
      '98XXXX1007',
      'Kair',
      'Wheat',
    ),
    MockIdentity(
      'F008',
      'Anil Chauhan',
      '98XXXX1008',
      'Roshanpura',
      'Paddy',
    ),
    MockIdentity(
      'F009',
      'Pooja Kumari',
      '98XXXX1009',
      'Najafgarh',
      'Mustard',
    ),
    MockIdentity(
      'F010',
      'Mahender Pal',
      '98XXXX1010',
      'Dhansa',
      'Wheat',
    ),
    MockIdentity(
      'F011',
      'Rekha Devi',
      '98XXXX1011',
      'Kair',
      'Paddy',
    ),
    MockIdentity(
      'F012',
      'Vijay Kumar',
      '98XXXX1012',
      'Roshanpura',
      'Mustard',
    ),
  ];

  final Random _random = Random();
  String _otp = '';
  DateTime? _sentAt;

  Future<MockIdentity?> lookupAadhaar(
    String digits,
  ) async {
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
      return null;
    }

    return profiles[
      _random.nextInt(profiles.length)
    ];
  }

  Future<String> sendOtp(
    String mobile,
  ) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    _otp = (
      100000 + _random.nextInt(900000)
    ).toString();

    _sentAt = DateTime.now();
    return _otp;
  }

  bool get canResend {
    return _sentAt == null ||
        DateTime.now()
                .difference(_sentAt!)
                .inSeconds >=
            45;
  }

  int get resendSeconds {
    if (_sentAt == null) {
      return 0;
    }

    return (
      45 -
      DateTime.now()
          .difference(_sentAt!)
          .inSeconds
    ).clamp(0, 45);
  }

  Future<bool> verifyOtp(
    String value,
  ) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    return value == _otp &&
        _otp.isNotEmpty;
  }

  Future<OfficialIdentity?> loginOfficial({
    required String centreId,
    required String officialId,
    required String password,
  }) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    final centre = centreId.trim().toUpperCase();
    final id = officialId.trim().toUpperCase();

    // Final server-side-style validation in the mock service too. This keeps
    // the authentication contract correct even if a caller bypasses the UI.
    if (!RegExp(r'^[A-Z]+$').hasMatch(centre)) {
      return null;
    }

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(id)) {
      return null;
    }

    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(password)) {
      return null;
    }

    const passwords = <String, String>{
      'OFF001': 'procure123',
      'OFF002': 'procure123',
      'DIST001': 'admin123',
      'ADMIN001': 'admin123',
    };

    for (final user in officialUsers) {
      if (user.officialId != id) {
        continue;
      }

      final expectedPassword =
          passwords[user.officialId];

      if (expectedPassword == null ||
          expectedPassword != password) {
        return null;
      }

      final centreAllowed =
          user.centreId == '*' ||
          user.centreId.toUpperCase() == centre;

      if (!centreAllowed) {
        return null;
      }

      return user;
    }

    return null;
  }
}
