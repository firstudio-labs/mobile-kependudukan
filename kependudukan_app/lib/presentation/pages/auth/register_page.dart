import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/core/utils/form_validators.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _noHpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nikController.dispose();
    _noHpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      context.read<AuthBloc>().add(
            RegisterPendudukEvent(
              nik: _nikController.text,
              password: _passwordController.text,
              confirmPassword: _confirmPasswordController.text,
              noHp: _noHpController.text,
            ),
          );
    }
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool isPassword = false,
    bool passwordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !passwordVisible,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
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
                      color: Colors.grey.shade400,
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
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
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

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF6),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
              ),
            );
          } else if (state is RegisterSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(AppConstants.successRegistration),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
                duration: const Duration(seconds: 1),
              ),
            );

            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            });
          }
        },
        builder: (context, state) {
          final bool isLoading = state is AuthLoading;

          return Stack(
            children: [
              SizedBox(
                height: size.height,
                width: size.width,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: size.height * 0.45,
                      child: Container(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 24.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Pendaftaran',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _buildCustomTextField(
                                      controller: _nikController,
                                      label: 'NIK',
                                      hintText: '33230921xxxxxxxx',
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(16),
                                      ],
                                      validator: FormValidators.validateNik,
                                    ),
                                    const SizedBox(height: 18),
                                    _buildCustomTextField(
                                      controller: _noHpController,
                                      label: 'Nomor HP',
                                      hintText: '08000000000',
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(13),
                                      ],
                                      validator:
                                          FormValidators.validatePhoneNumber,
                                    ),
                                    const SizedBox(height: 18),
                                    _buildCustomTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hintText: '*******',
                                      isPassword: true,
                                      passwordVisible: _isPasswordVisible,
                                      onTogglePassword: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                      validator:
                                          FormValidators.validatePassword,
                                    ),
                                    const SizedBox(height: 18),
                                    _buildCustomTextField(
                                      controller: _confirmPasswordController,
                                      label: 'Konfirmasi Password',
                                      hintText: '*******',
                                      isPassword: true,
                                      passwordVisible:
                                          _isConfirmPasswordVisible,
                                      onTogglePassword: () {
                                        setState(() {
                                          _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible;
                                        });
                                      },
                                      validator: (value) =>
                                          FormValidators.validatePasswordMatch(
                                        value,
                                        _passwordController.text,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed:
                                            isLoading ? null : _submitForm,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Daftar',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Sudah punya akun? ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const LoginPage(),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Login',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.2),
                  width: double.infinity,
                  height: double.infinity,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
