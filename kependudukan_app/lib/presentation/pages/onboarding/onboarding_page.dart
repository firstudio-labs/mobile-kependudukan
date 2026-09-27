import 'package:flutter/material.dart';
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
      'color': const Color(0xFF4A47DC),
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
    return Scaffold(
      backgroundColor: const Color(0xFF4A47DC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => _buildOnboardingPage(index),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _onboardingData[_currentPage]['title'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _onboardingData[_currentPage]['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),

                    // Buttons and indicators row
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
                        _currentPage < _onboardingData.length - 1
                            ? SizedBox(
                                width: 120,
                                child: CustomButton(
                                  height: 50,
                                  text: 'Lanjut',
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ],
                    ),

                    // Login & Register buttons (only on the last page)
                    if (_currentPage == _onboardingData.length - 1) ...[
                      const SizedBox(height: 20),
                      CustomButton(text: 'Masuk', onPressed: _navigateToLogin),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Daftar',
                        onPressed: _navigateToRegister,
                        backgroundColor: Colors.white,
                        textColor: const Color(0xFF4A47DC),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(int index) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background decorations
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              right: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Illustration
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60),
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
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                _onboardingData[index]['image'],
                                size: 60,
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
  }

  Widget _buildDotIndicator(int index) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? const Color(0xFF4A47DC)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
