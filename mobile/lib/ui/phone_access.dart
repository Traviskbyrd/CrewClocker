import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String? normalizePhone(String input) {
  final clean = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  final number = RegExp(r'^\d{10}$').hasMatch(clean) ? '+1$clean' : clean;
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(number) ? number : null;
}

class PhoneAccess extends StatefulWidget {
  const PhoneAccess({super.key, this.emailBuilder, this.link = false});
  final WidgetBuilder? emailBuilder;
  final bool link;
  @override
  State<PhoneAccess> createState() => _PhoneAccessState();
}

class _PhoneAccessState extends State<PhoneAccess> {
  final phone = TextEditingController(), code = TextEditingController();
  String? sentTo, error;
  bool busy = false, email = false;
  int cooldown = 0;
  Timer? timer;
  @override
  void dispose() { phone.dispose(); code.dispose(); timer?.cancel(); super.dispose(); }

  Future<void> send() async {
    final number = normalizePhone(phone.text);
    if (number == null) { setState(() => error = 'Enter a phone number with country code, such as +1 512 555 0123.'); return; }
    setState(() { busy = true; error = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (widget.link) {
        await auth.updateUser(UserAttributes(phone: number));
      } else {
        await auth.signInWithOtp(phone: number);
      }
      if (!mounted) return;
      setState(() { sentTo = number; cooldown = 60; code.clear(); });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() => cooldown--);
        if (cooldown <= 0) t.cancel();
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message.toLowerCase().contains('disabled') ? 'Text-message sign-in has not been enabled yet. Use email for now, or ask your company owner to finish SMS setup.' : e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not send a code. Check your connection and try again.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> verify() async {
    if (!RegExp(r'^\d{6,10}$').hasMatch(code.text.trim())) {
      setState(() => error = 'Enter the verification code from your text message.'); return;
    }
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(phone: sentTo!, token: code.text.trim(), type: widget.link ? OtpType.phoneChange : OtpType.sms);
      if (widget.link && mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message.toLowerCase().contains('disabled') ? 'Text-message sign-in has not been enabled yet. Use email for now, or ask your company owner to finish SMS setup.' : e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not verify the code. Try again when connected.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (email && widget.emailBuilder != null) {
      return Scaffold(body: Column(children: [SafeArea(bottom: false, child: TextButton.icon(onPressed: () => setState(() => email = false), icon: const Icon(Icons.phone_android), label: const Text('Use phone number instead'))), Expanded(child: widget.emailBuilder!(context))]));
    }
    return Scaffold(
      appBar: widget.link ? AppBar(title: const Text('Link your phone number')) : null,
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.timer_outlined, size: 64, color: Color(0xff1565c0)),
        const SizedBox(height: 20),
        Text('CrewClocker', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(widget.link ? 'Add phone sign-in to this account and keep your existing jobs and records.' : 'Sign in or create an account with a text-message code. No email required.'),
        const SizedBox(height: 24),
        TextField(controller: phone, enabled: !busy && sentTo == null, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: const InputDecoration(labelText: 'Phone number', helperText: 'US: 10 digits. Elsewhere: include +country code.')),
        if (sentTo != null) ...[
          const SizedBox(height: 16), Text('Code sent to $sentTo'), const SizedBox(height: 12),
          TextField(controller: code, enabled: !busy, keyboardType: TextInputType.number, autofillHints: const [AutofillHints.oneTimeCode], decoration: const InputDecoration(labelText: 'Verification code'), onSubmitted: (_) { if (!busy) verify(); }),
        ],
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : sentTo == null ? send : verify, child: Text(busy ? 'Please wait…' : sentTo == null ? 'Send code' : 'Verify code')),
        if (sentTo != null) ...[
          TextButton(onPressed: busy || cooldown > 0 ? null : send, child: Text(cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend code')),
          TextButton(onPressed: busy ? null : () => setState(() { sentTo = null; error = null; code.clear(); }), child: const Text('Change number')),
        ],
        if (!widget.link && widget.emailBuilder != null) TextButton(onPressed: busy ? null : () => setState(() => email = true), child: const Text('Use email and password')),
        if (!widget.link) const Text('Already use email? Sign in with email first, then link your phone under Account to keep your existing records.'),
      ]))))),
    );
  }
}
