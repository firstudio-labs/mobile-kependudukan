import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/pages/auth/register_page.dart';
import 'package:ladimas/presentation/widgets/custom_button.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Selamat Datang di LADIMAS',
      'description':
          'Kelola data kependudukan Anda secara mudah dan cepat melalui aplikasi ini',
      'image': 'assets/app_icon_padded.png',
      'color': AppTheme.primaryColor,
    },
    {
      'title': 'Akses Layanan Kapan Saja',
      'description':
          'Dapatkan layanan kependudukan 24 jam tanpa perlu mengantri di kantor',
      'image': Icons.access_time,
      'color': const Color(0xFF00BFA5),
    },
    {
      'title': 'Mulai Sekarang',
      'description':
          'Daftar atau masuk untuk menikmati kemudahan layanan kependudukan digital',
      'image': Icons.rocket_launch,
      'color': const Color(0xFFF57C00),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _navigateToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isShortScreen = screenHeight < 720;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Illustration / PageView
            Expanded(
              flex: isShortScreen ? 45 : 50,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => _buildOnboardingPage(index),
              ),
            ),

            // Bottom Content Card
            Expanded(
              flex: isShortScreen ? 55 : 50,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hPadding = 28.0;
                    final vPadding = isShortScreen ? 20.0 : 28.0;

                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: hPadding,
                              vertical: vPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _onboardingData[_currentPage]['title'],
                                  style: TextStyle(
                                    fontSize: isShortScreen ? 22 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                SizedBox(height: isShortScreen ? 10 : 14),
                                Text(
                                  _onboardingData[_currentPage]['description'],
                                  style: TextStyle(
                                    fontSize: isShortScreen ? 13 : 14,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                                const Spacer(),

                                // Page indicators and "Lanjut" button (on non-last pages)
                                Row(
                                  children: [
                                    // Page indicators
                                    Row(
                                      children: List.generate(
                                        _onboardingData.length,
                                        (index) => _buildDotIndicator(index),
                                      ),
                                    ),
                                    const Spacer(),

                                    // Navigation button(s)
                                    if (_currentPage < _onboardingData.length - 1)
                                      SizedBox(
                                        width: 120,
                                        child: CustomButton(
                                          height: isShortScreen ? 46 : 50,
                                          text: 'Lanjut',
                                          onPressed: () {
                                            _pageController.nextPage(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),

                                // Login & Register buttons (only on the last page)
                                if (_currentPage == _onboardingData.length - 1) ...[
                                  SizedBox(height: isShortScreen ? 14 : 18),
                                  CustomButton(
                                    height: isShortScreen ? 48 : 52,
                                    text: 'Masuk',
                                    onPressed: _navigateToLogin,
                                  ),
                                  SizedBox(height: isShortScreen ? 10 : 12),
                                  CustomButton(
                                    height: isShortScreen ? 48 : 52,
                                    text: 'Daftar',
                                    onPressed: _navigateToRegister,
                                    backgroundColor: Colors.white,
                                    textColor: AppTheme.primaryColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 320;
        final circleSize = isCompact ? 100.0 : 120.0;
        final outerPad = isCompact ? 12.0 : 16.0;
        final midPad = isCompact ? 20.0 : 32.0;
        final iconSize = isCompact ? 50.0 : 60.0;
        final imageSize = isCompact ? 75.0 : 90.0;

        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 32),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background decorations
                Positioned(
                  top: isCompact ? 20 : 50,
                  left: 20,
                  child: Container(
                    width: isCompact ? 24 : 30,
                    height: isCompact ? 24 : 30,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: isCompact ? 40 : 80,
                  right: 10,
                  child: Container(
                    width: isCompact ? 16 : 20,
                    height: isCompact ? 16 : 20,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Illustration
                Container(
                  padding: EdgeInsets.all(outerPad),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(midPad),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: Container(
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(circleSize / 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: _onboardingData[index]['image'] is String
                                ? Center(
                                    child: Image.asset(
                                      _onboardingData[index]['image'],
                                      width: imageSize,
                                      height: imageSize,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    _onboardingData[index]['image'],
                                    size: iconSize,
                                    color: _onboardingData[index]['color'],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotIndicator(int index) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? AppTheme.primaryColor
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
