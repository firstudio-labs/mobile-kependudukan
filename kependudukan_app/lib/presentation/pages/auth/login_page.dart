import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/auth/register_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_beranda_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';

class LoginFormValidator {
  static String? validateNik(String? value, {bool isAdmin = false}) {
    if (value == null || value.trim().isEmpty) {
      return isAdmin
          ? 'Username/NIK tidak boleh kosong'
          : 'NIK tidak boleh kosong';
    }
    if (!isAdmin && value.trim().length != 16) {
      return 'NIK harus 16 digit';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    return null;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _loginSebagaiAdmin = false;

  @override
  void dispose() {
    _nikController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus(); // Tutup keyboard saat submit
      if (_loginSebagaiAdmin) {
        context.read<AuthBloc>().add(
              LoginAdminEvent(
                nikOrUsername: _nikController.text.trim(),
                password: _passwordController.text,
              ),
            );
      } else {
        context.read<AuthBloc>().add(
              LoginPendudukEvent(
                nik: _nikController.text.trim(),
                password: _passwordController.text,
              ),
            );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: Duration(seconds: isError ? 3 : 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showSnackBar(state.message, isError: true);
          } else if (state is PendudukAuthenticated) {
            _showSnackBar('Login berhasil');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BerandaPage(penduduk: state.penduduk),
              ),
            );
          } else if (state is AdminAuthenticated) {
            _showSnackBar('Login admin berhasil');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AdminBerandaPage(adminData: state.adminData),
              ),
            );
          }
        },
        builder: (context, state) {
          final bool isLoading = state is AuthLoading;

          return Stack(
            children: [
              // Header Background
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.40,
                child: Container(
                  color: AppTheme.primaryColor,
                ),
              ),

              // Main Form & Header Text
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      _buildHeader(),
                      const SizedBox(height: 50),
                      _buildFormCard(isLoading),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Full Screen Overlay Indicator (Optional)
              if (isLoading)
                Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'LADIMAS',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Layanan Digital Masyarakat',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Login',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            _buildRoleToggle(),
            const SizedBox(height: 24),
            _buildCustomTextField(
              controller: _nikController,
              label: _loginSebagaiAdmin ? 'Username / NIK' : 'NIK',
              hintText: _loginSebagaiAdmin
                  ? 'Masukkan Username atau NIK'
                  : '33230921xxxxxxxx',
              keyboardType: _loginSebagaiAdmin
                  ? TextInputType.text
                  : TextInputType.number,
              validator: (val) => LoginFormValidator.validateNik(val,
                  isAdmin: _loginSebagaiAdmin),
            ),
            const SizedBox(height: 18),
            _buildCustomTextField(
              controller: _passwordController,
              label: 'Password',
              hintText: '••••••••',
              isPassword: true,
              passwordVisible: _isPasswordVisible,
              onTogglePassword: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              validator: LoginFormValidator.validatePassword,
            ),
            const SizedBox(height: 28),
            _buildSubmitButton(isLoading),
            const SizedBox(height: 20),
            _buildRegisterOption(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildRoleTab(
            title: 'Masyarakat',
            isSelected: !_loginSebagaiAdmin,
            onTap: () {
              if (_loginSebagaiAdmin) {
                setState(() => _loginSebagaiAdmin = false);
              }
            },
          ),
          _buildRoleTab(
            title: 'Admin',
            isSelected: _loginSebagaiAdmin,
            onTap: () {
              if (!_loginSebagaiAdmin) {
                setState(() => _loginSebagaiAdmin = true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool isPassword = false,
    bool passwordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !passwordVisible,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      passwordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade500, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _onLoginPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildRegisterOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Belum punya akun? ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegisterPage(),
              ),
            );
          },
          child: const Text(
            'Daftar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
