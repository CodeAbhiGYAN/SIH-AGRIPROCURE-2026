import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  final AppState state;

  const AuthScreen({
    super.key,
    required this.state,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthStep {
  welcome,
  aadhaar,
  otp,
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService auth = AuthService();

  _AuthStep step = _AuthStep.welcome;

  MockIdentity? identity;

  String digits = '';
  String otp = '';
  String currentOtp = '';

  String? error;

  bool busy = false;
  bool aadhaarKeypadVisible = false;
  bool otpKeypadVisible = false;

  Timer? resendTimer;
  int resendLeft = 0;

  @override
  void dispose() {
    resendTimer?.cancel();
    super.dispose();
  }

  void _showError(String value) {
    setState(() => error = value);
  }

  void _key(String key, {required bool isOtp}) {
    setState(() => error = null);

    final target = isOtp ? otp : digits;
    final max = isOtp ? 6 : 12;

    if (key == 'check') {
      setState(() {
        if (isOtp) {
          otpKeypadVisible = false;
        } else {
          aadhaarKeypadVisible = false;
        }
      });
      return;
    }

    if (key == 'back') {
      if (target.isEmpty) return;

      setState(() {
        if (isOtp) {
          otp = target.substring(0, target.length - 1);
        } else {
          digits = target.substring(0, target.length - 1);
        }
      });

      return;
    }

    if (target.length >= max) return;

    setState(() {
      if (isOtp) {
        otp = '$target$key';
      } else {
        digits = '$target$key';
      }
    });
  }

  Future<void> _submitAadhaar() async {
    if (digits.length != 12) {
      _showError(
        'Please enter your complete 12-digit Aadhaar number.',
      );
      return;
    }

    setState(() {
      busy = true;
      error = null;
      aadhaarKeypadVisible = false;
    });

    final value = await auth.lookupAadhaar(digits);

    if (!mounted) return;

    if (value == null) {
      setState(() => busy = false);
      _showError('Please enter a valid 12-digit number.');
      return;
    }

    identity = value;

    await Future<void>.delayed(
      const Duration(seconds: 5),
    );

    if (!mounted) return;

    currentOtp = await auth.sendOtp(value.mobile);

    if (!mounted) return;

    _startResendCooldown();

    setState(() {
      step = _AuthStep.otp;
      busy = false;
      otp = '';
      otpKeypadVisible = false;
    });

    await widget.state.notifications.showSystemNotification(
      title: 'Messages',
      message: 'Your Smart Procurement OTP is $currentOtp',
      details: 'Use this code to complete sign in.',
      id: DateTime.now().millisecondsSinceEpoch.remainder(
        1000000000,
      ),
    );
  }

  void _startResendCooldown() {
    resendTimer?.cancel();

    setState(() {
      resendLeft = auth.resendSeconds == 0
          ? 45
          : auth.resendSeconds;
    });

    resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final seconds = auth.resendSeconds;

        setState(() => resendLeft = seconds);

        if (seconds <= 0) {
          timer.cancel();
        }
      },
    );
  }

  Future<void> _resend() async {
    if (identity == null || resendLeft > 0 || busy) return;

    currentOtp = await auth.sendOtp(
      identity!.mobile,
    );

    if (!mounted) return;

    setState(() {
      otp = '';
      otpKeypadVisible = false;
    });

    await widget.state.notifications.showSystemNotification(
      title: 'Messages',
      message:
          'Your new Smart Procurement OTP is $currentOtp',
      details: 'The previous OTP is no longer valid.',
      id: DateTime.now().millisecondsSinceEpoch.remainder(
        1000000000,
      ),
    );

    _startResendCooldown();
  }

  Future<void> _verify() async {
    if (otp.length != 6) {
      _showError(
        'Please enter the complete 6-digit OTP.',
      );
      return;
    }

    setState(() {
      busy = true;
      error = null;
      otpKeypadVisible = false;
    });

    final ok = await auth.verifyOtp(otp);

    if (!mounted) return;

    if (!ok) {
      setState(() => busy = false);
      _showError('Invalid OTP. Please try again.');
      return;
    }

    final p = identity!;

    await widget.state.login(
      farmerId: p.farmerId,
      name: p.name,
      mobile: p.mobile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (step) {
      _AuthStep.welcome => _welcome(),
      _AuthStep.aadhaar => _aadhaar(),
      _AuthStep.otp => _otp(),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _base(
    String title,
    String subtitle,
    Widget child,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.agriculture,
          size: 68,
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        Text(
          'Smart Procurement',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle),
        const SizedBox(height: 24),
        child,
      ],
    );
  }

  Widget _welcome() {
    return _base(
      'Welcome Farmer',
      'Login or register to access Smart Procurement.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  error = null;
                  step = _AuthStep.aadhaar;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.agriculture),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login / Registration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Login or register using your Aadhaar number.',
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aadhaar() {
    return _base(
      'Aadhaar Verification',
      'Tap the number field to enter your 12-digit Aadhaar number.',
      TapRegion(
        groupId: 'aadhaar-input-group',
        onTapOutside: (_) {
          if (aadhaarKeypadVisible && mounted) {
            setState(
              () => aadhaarKeypadVisible = false,
            );
          }
        },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius:
                  BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  error = null;
                  aadhaarKeypadVisible = true;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: aadhaarKeypadVisible
                        ? Colors.green
                        : Colors.grey.shade300,
                    width: aadhaarKeypadVisible
                        ? 2
                        : 1,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _format(digits),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            if (aadhaarKeypadVisible) ...[
              const SizedBox(height: 12),
              NumericKeypad(
                onKey: (k) => _key(
                  k,
                  isOtp: false,
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            BigAction(
              text: busy
                  ? 'Checking...'
                  : 'Continue',
              icon: Icons.arrow_forward,
              onTap: busy ||
                      digits.length != 12
                  ? null
                  : _submitAadhaar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _otp() {
    return _base(
      'OTP Verification',
      'Enter the 6-digit verification code sent to your registered mobile number.',
      TapRegion(
        groupId: 'otp-input-group',
        onTapOutside: (_) {
          if (otpKeypadVisible && mounted) {
            setState(
              () => otpKeypadVisible = false,
            );
          }
        },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius:
                  BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  error = null;
                  otpKeypadVisible = true;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: otpKeypadVisible
                        ? Colors.green
                        : Colors.grey.shade300,
                    width: otpKeypadVisible
                        ? 2
                        : 1,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    otp.padRight(6, '•'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),
            ),
            if (otpKeypadVisible) ...[
              const SizedBox(height: 12),
              NumericKeypad(
                onKey: (k) => _key(
                  k,
                  isOtp: true,
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            BigAction(
              text: busy
                  ? 'Verifying...'
                  : 'Verify OTP',
              icon: Icons.verified,
              onTap: busy ||
                      otp.length != 6
                  ? null
                  : _verify,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  resendLeft == 0 && !busy
                      ? _resend
                      : null,
              child: Text(
                resendLeft == 0
                    ? 'Resend OTP'
                    : 'Resend OTP in ${resendLeft}s',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(String v) {
    if (v.isEmpty) {
      return '••••-••••-••••';
    }

    final a = v.length > 4
        ? v.substring(0, 4)
        : v;

    final b = v.length > 4
        ? v.substring(
            4,
            v.length > 8 ? 8 : v.length,
          )
        : '';

    final c = v.length > 8
        ? v.substring(8)
        : '';

    return [
      a,
      b,
      c,
    ].where((x) => x.isNotEmpty).join('-');
  }
}