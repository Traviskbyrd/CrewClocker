import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/field_repository.dart';
import 'ui/field_workspace.dart';
import 'ui/device_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  String? setupError;
  if (url.isEmpty || key.isEmpty) {
    setupError = 'This build needs its Supabase connection configured.';
  } else {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
    } catch (_) {
      setupError =
          'The connection could not be initialized. Check this build’s configuration.';
    }
  }
  runApp(CrewClockerApp(setupError: setupError));
}

class CrewClockerApp extends StatelessWidget {
  const CrewClockerApp({super.key, this.setupError});
  final String? setupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CrewClocker',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f8c)),
      scaffoldBackgroundColor: const Color(0xfff5f7fa),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: setupError != null
        ? Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Builder(
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(setupError!),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DeviceCheckScreen(),
                          ),
                        ),
                        child: const Text('Check this phone'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : const SessionGate(),
  );
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) => client.auth.currentSession == null
          ? const SignInScreen()
          : FieldWorkspace(
              key: ValueKey(client.auth.currentUser!.id),
              repository: FieldRepository(client),
            ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInState();
}

class _SignInState extends State<SignInScreen> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  bool creating = false;
  String? notice;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (creating) {
        if (password.text.length < 10) {
          setState(() => error = 'Use a password with at least 10 characters.');
          return;
        }
        final response = await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (mounted && response.session == null)
          setState(() {
            creating = false;
            notice =
                'Check your email and open the confirmation link. Then return here and sign in. If you already have an account, sign in with its password.';
          });
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Unable to connect. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 64,
                  color: Color(0xff087f8c),
                ),
                const SizedBox(height: 20),
                Text(
                  'CrewClocker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your workday, accounted for.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) {
                    if (!busy) signIn();
                  },
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : signIn,
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : creating
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(notice!),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          creating = !creating;
                          error = null;
                        }),
                  child: Text(
                    creating
                        ? 'Already have an account? Sign in'
                        : 'New owner? Create an account',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeviceCheckScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Check this phone'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
