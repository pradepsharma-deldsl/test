import 'package:flutter/material.dart';

import 'database.dart';
import 'home_page.dart';
import 'security_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SecureDocApp());
}

class SecureDocApp extends StatefulWidget {
  const SecureDocApp({super.key});

  @override
  State<SecureDocApp> createState() => _SecureDocAppState();
}

class _SecureDocAppState extends State<SecureDocApp>
    with WidgetsBindingObserver {
  bool _locked = true;
  bool _homeReady = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppDatabase.instance.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _homeReady) {
      final then = _backgroundedAt;
      _backgroundedAt = null;
      if (then != null && DateTime.now().difference(then).inSeconds >= 5) {
        setState(() => _locked = true);
      }
    }
  }

  Future<void> _unlocked() async {
    await AppDatabase.instance.open();
    if (!mounted) return;
    setState(() {
      _homeReady = true;
      _locked = false;
    });
  }

  void _lockNow() {
    if (mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: _homeReady
          ? HomePage(onLock: _lockNow)
          : const SizedBox.shrink(),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_locked || !_homeReady)
              Positioned.fill(
                child: Material(
                  child: AppLockPage(onUnlocked: _unlocked),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppLockPage extends StatefulWidget {
  final Future<void> Function() onUnlocked;
  const AppLockPage({super.key, required this.onUnlocked});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _firstRun = false;
  bool _busy = true;
  bool _showPin = false;
  bool _biometricVisible = false;
  int _failures = 0;
  DateTime? _blockedUntil;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final security = SecurityService.instance;
    final hasPin = await security.hasPin();
    final bio = hasPin &&
        await security.isBiometricEnabled() &&
        await security.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _firstRun = !hasPin;
      _biometricVisible = bio;
      _busy = false;
    });
  }

  Future<void> _createPin() async {
    if (_pin.text != _confirm.text) {
      _message('PIN/password entries do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await SecurityService.instance.createPin(_pin.text);
      await widget.onUnlocked();
    } catch (e) {
      _message(_cleanError(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    if (_blockedUntil != null && DateTime.now().isBefore(_blockedUntil!)) {
      final seconds = _blockedUntil!.difference(DateTime.now()).inSeconds + 1;
      _message('Too many attempts. Try again in $seconds seconds.');
      return;
    }
    if (_pin.text.isEmpty) {
      _message('Enter your PIN/password.');
      return;
    }
    setState(() => _busy = true);
    final ok = await SecurityService.instance.verifyPin(_pin.text);
    if (!ok) {
      _failures++;
      if (_failures >= 5) {
        _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _failures = 0;
      }
      if (mounted) setState(() => _busy = false);
      _message('Incorrect PIN/password.');
      return;
    }
    _failures = 0;
    try {
      await widget.onUnlocked();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _message('Could not open the encrypted database: ${_cleanError(e)}');
    }
  }

  Future<void> _biometricUnlock() async {
    setState(() => _busy = true);
    final ok = await SecurityService.instance.authenticateBiometric();
    if (!ok) {
      if (mounted) setState(() => _busy = false);
      _message('Biometric authentication was not completed.');
      return;
    }
    try {
      await widget.onUnlocked();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _message('Could not open the encrypted database: ${_cleanError(e)}');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Invalid argument(s): ', '').replaceFirst('Bad state: ', '');

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.enhanced_encryption, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      _firstRun ? 'Secure Docs Setup' : 'Secure Docs Locked',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _firstRun
                          ? 'Create a PIN or password. Your documents stay encrypted on this device.'
                          : 'Unlock to view your encrypted documents.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pin,
                      obscureText: !_showPin,
                      autofillHints: const [AutofillHints.password],
                      textInputAction:
                          _firstRun ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_firstRun) _unlock();
                      },
                      decoration: InputDecoration(
                        labelText: 'PIN / Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showPin = !_showPin),
                          icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    if (_firstRun) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        obscureText: !_showPin,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createPin(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm PIN / Password',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Minimum 6 characters.'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _firstRun ? _createPin : _unlock,
                        icon: const Icon(Icons.lock_open),
                        label: Text(_firstRun ? 'Create Secure Vault' : 'Unlock'),
                      ),
                    ),
                    if (!_firstRun && _biometricVisible) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _biometricUnlock,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Use Biometrics'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
