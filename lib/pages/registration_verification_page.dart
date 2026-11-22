import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/mobile_page_shell.dart';

class RegistrationVerificationPage extends StatefulWidget {
  const RegistrationVerificationPage({
    required this.email,
    required this.registrationId,
    required this.retryAfterSeconds,
    super.key,
  });

  final String email;
  final String registrationId;
  final int retryAfterSeconds;

  @override
  State<RegistrationVerificationPage> createState() =>
      _RegistrationVerificationPageState();
}

class _RegistrationVerificationPageState
    extends State<RegistrationVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _countdown;
  int _secondsLeft = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.retryAfterSeconds);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _secondsLeft = seconds;
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _verify() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await AuthService.verifyRegistration(widget.registrationId, _code.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _secondsLeft > 0) return;
    setState(() => _busy = true);
    try {
      final response =
          await AuthService.resendRegistrationCode(widget.registrationId);
      if (!mounted) return;
      _code.clear();
      _startCountdown((response['retryAfterSeconds'] as int?) ?? 60);
      _message('Check your inbox and spam folder for the new code.');
    } on AuthException catch (error) {
      if (!mounted) return;
      final seconds = error.retryAfterSeconds;
      if (seconds != null && seconds > 0) _startCountdown(seconds);
      _message(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: MobilePageShell(
        child: Column(
          children: [
            AuthFlowHeader(
              onBack: _busy ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AuthPageTitle(
                        title: 'Verify your email',
                        subtitle: 'Check the inbox and spam folder for '
                            '${widget.email}. Your code expires in 10 minutes.',
                      ),
                      const SizedBox(height: 24),
                      const FieldLabel('Registration Code'),
                      TextFormField(
                        controller: _code,
                        readOnly: _busy,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onFieldSubmitted: (_) => _verify(),
                        validator: (value) => RegExp(r'^\d{6}$')
                                .hasMatch(value ?? '')
                            ? null
                            : 'Enter the 6-digit registration code.',
                        decoration: const InputDecoration(
                          hintText: 'Enter the 6-digit code',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Verify and Register',
                        onPressed: _busy ? null : _verify,
                      ),
                      TextButton(
                        onPressed: _busy || _secondsLeft > 0 ? null : _resend,
                        child: Text(_secondsLeft > 0
                            ? 'Resend in ${_secondsLeft}s'
                            : 'Resend Code'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
