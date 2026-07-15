import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/responsive.dart';
import '../widgets/animated_web_background.dart';
import 'main_screen.dart';
import 'admin_dashboard_screen.dart';

/// Login screen with simple hardcoded authentication.
/// Credentials: admin / 1234
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate network delay for realistic feel
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;

      // Navigate based on role
      if (context.read<AuthProvider>().isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        // Initialize company provider only for clients (asynchronous background initialization)
        context.read<CompanyProvider>().initialize(
          clientCompanyId: authProvider.clientId,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }

    }
  }

  @override
  Widget build(BuildContext context) {
    final loginBody = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isMobile(context) ? double.infinity : 420,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo and title
                  _buildHeader(),
                  const SizedBox(height: 48),
                  // Login form card
                  _buildLoginCard(),
                  const SizedBox(height: 24),
                  // Demo credentials hint
                  _buildCredentialsHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final loginContent = Scaffold(
      backgroundColor: kIsWeb ? Colors.transparent : null,
      body: kIsWeb
          ? loginBody
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    Colors.indigo.shade800,
                  ],
                ),
              ),
              child: loginBody,
            ),
    );

    // Wrap with scrolling background on web
    if (kIsWeb) {
      return AnimatedWebBackground(child: loginContent);
    }
    return loginContent;
  }


  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/AppIcons/playstore.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Armix Machinery',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Machine Monitoring Dashboard',
          style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 4),
        Text(
          'Bengaluru',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sign In',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter username';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter password';
                  return null;
                },
              ),
              const SizedBox(height: 4),
              // Forgot Password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
                ),
              ),
              // Error message
              Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  if (auth.errorMessage != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        auth.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final controller = TextEditingController(text: _usernameController.text);
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lock_reset, color: Colors.orange),
            SizedBox(width: 8),
            Text('Forgot Password'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your username and we\'ll notify the admin to send you a new password.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setDialogState(() => isSending = true);
                      try {
                        final bridge = context.read<AuthProvider>().bridgeService;
                        await bridge.forgotPassword(controller.text.trim());
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Request sent! Admin will provide you with a new password.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSending = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Admin: armix_admin / armix2026',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const Text(
            'Client: bricks_user / bricks123',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
