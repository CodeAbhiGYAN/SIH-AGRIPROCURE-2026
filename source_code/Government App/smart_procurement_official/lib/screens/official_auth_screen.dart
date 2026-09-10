import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

class OfficialAuthScreen extends StatefulWidget {
  final AppState state;

  const OfficialAuthScreen({
    super.key,
    required this.state,
  });

  @override
  State<OfficialAuthScreen> createState() =>
      _OfficialAuthScreenState();
}

class _OfficialAuthScreenState extends State<OfficialAuthScreen> {
  final AuthService auth = AuthService();

  final TextEditingController centreController =
      TextEditingController();
  final TextEditingController officialIdController =
      TextEditingController();
  final TextEditingController passwordController =
      TextEditingController();

  bool busy = false;
  String? error;

  @override
  void dispose() {
    centreController.dispose();
    officialIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final centre = centreController.text.trim().toUpperCase();
    final officialId = officialIdController.text.trim().toUpperCase();
    final password = passwordController.text;

    final validationError = _validateInput(
      centre: centre,
      officialId: officialId,
      password: password,
    );

    if (validationError != null) {
      setState(() => error = validationError);
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    final user = await auth.loginOfficial(
      centreId: centre,
      officialId: officialId,
      password: password,
    );

    if (!mounted) return;

    if (user == null) {
      setState(() {
        busy = false;
        error = 'Invalid official credentials or centre access.';
      });
      return;
    }

    await widget.state.loginOfficial(user);
  }

  String? _validateInput({
    required String centre,
    required String officialId,
    required String password,
  }) {
    if (centre.isEmpty || officialId.isEmpty || password.isEmpty) {
      return 'Please enter all login details.';
    }

    if (!RegExp(r'^[A-Z]+$').hasMatch(centre)) {
      return 'Centre ID can contain letters only.';
    }

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(officialId)) {
      return 'Official ID can contain letters and numbers only.';
    }

    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(password)) {
      return 'Password can contain letters and numbers only.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance,
                    size: 68,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Smart Procurement Official',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Official Login',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to manage procurement centre operations.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: centreController,
                    textCapitalization:
                        TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    textInputAction:
                        TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z]'),
                      ),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Centre ID',
                      hintText: 'A',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: officialIdController,
                    textCapitalization:
                        TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    textInputAction:
                        TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Official ID',
                      hintText: 'OFF001',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  BigAction(
                    text: busy ? 'Signing in...' : 'Sign in',
                    icon: Icons.login,
                    onTap: busy ? null : _login,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Authorised official access only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      composing: TextRange.empty,
    );
  }
}
