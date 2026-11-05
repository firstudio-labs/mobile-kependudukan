import 'package:flutter/material.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/dataku/dataku_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';

class PortalLayananDesaPage extends StatefulWidget {
  final Penduduk penduduk;

  const PortalLayananDesaPage({Key? key, required this.penduduk})
      : super(key: key);

  @override
  State<PortalLayananDesaPage> createState() => _PortalLayananDesaPageState();
}

class _PortalLayananDesaPageState extends State<PortalLayananDesaPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Portal Layanan Desa',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4A47DC),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeaderSection(),
              const SizedBox(height: 24),

              // Quick Services
              _buildQuickServices(),
              const SizedBox(height: 24),

              // Service Categories
              _buildServiceCategories(),
              const SizedBox(height: 24),

              // Recent Activities
              _buildRecentActivities(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 5, // Dataku
        items: [
          AppBottomNavBar.item(icon: Icons.home_outlined, label: 'Beranda'),
          AppBottomNavBar.item(icon: Icons.storefront, label: 'Warungku'),
          AppBottomNavBar.item(
              icon: Icons.grid_view_outlined, label: 'Informasi'),
          AppBottomNavBar.item(
              icon: Icons.account_balance_outlined, label: 'Profil Desa'),
          AppBottomNavBar.item(icon: Icons.receipt_long_outlined, label: 'Tagihan'),
          AppBottomNavBar.item(icon: Icons.description, label: 'Portal'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BerandaPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => WarungkuPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PendudukHomePage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TagihanPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DocumentServicesWebViewPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 5:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DatakuPage(penduduk: widget.penduduk),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A47DC), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portal Layanan Desa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selamat datang, ${widget.penduduk.name}!',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Akses layanan desa secara digital',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Layanan Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickServiceCard(
                title: 'Surat Menyurat',
                icon: Icons.article_outlined,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentServicesWebViewPage(
                          penduduk: widget.penduduk),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickServiceCard(
                title: 'Laporan Desa',
                icon: Icons.report,
                color: Colors.red,
                onTap: () {
                  // TODO: Navigate to village report
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickServiceCard(
                title: 'Pengumuman',
                icon: Icons.announcement,
                color: Colors.orange,
                onTap: () {
                  // TODO: Navigate to announcements
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickServiceCard(
                title: 'Kontak Darurat',
                icon: Icons.emergency,
                color: Colors.red,
                onTap: () {
                  _showEmergencyContacts();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickServiceCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCategories() {
    final categories = [
      {
        'title': 'Administrasi Kependudukan',
        'icon': Icons.people,
        'color': Colors.blue,
        'services': ['KTP', 'KK', 'Akta Kelahiran', 'Akta Kematian']
      },
      {
        'title': 'Surat Menyurat',
        'icon': Icons.article,
        'color': Colors.green,
        'services': ['Surat Keterangan', 'Surat Domisili', 'Surat Usaha']
      },
      {
        'title': 'Layanan Umum',
        'icon': Icons.public,
        'color': Colors.orange,
        'services': ['Izin Mendirikan Bangunan', 'Izin Usaha', 'Laporan']
      },
      {
        'title': 'Informasi Desa',
        'icon': Icons.info,
        'color': Colors.purple,
        'services': ['Berita Desa', 'Pengumuman', 'Kegiatan']
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori Layanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        ...categories.map((category) => _buildCategoryCard(
              title: category['title'] as String,
              icon: category['icon'] as IconData,
              color: category['color'] as Color,
              services: category['services'] as List<String>,
            )),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> services,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        children: services
            .map((service) => ListTile(
                  title: Text(service),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to specific service
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Layanan $service akan segera tersedia')),
                    );
                  },
                ))
            .toList(),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktivitas Terbaru',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 12),
              Text(
                'Belum ada aktivitas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Gunakan layanan untuk melihat riwayat aktivitas',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEmergencyContacts() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Kontak Darurat',
          style: TextStyle(
            color: Color(0xFF4A47DC),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEmergencyContact('Kepala Desa', '0812-3456-7890'),
            const SizedBox(height: 12),
            _buildEmergencyContact('Sekretaris Desa', '0812-3456-7891'),
            const SizedBox(height: 12),
            _buildEmergencyContact('Posko Desa', '0812-3456-7892'),
            const SizedBox(height: 12),
            _buildEmergencyContact('Bidan Desa', '0812-3456-7893'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact(String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Color(0xFF4A47DC), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  phone,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: Implement call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Memanggil $name...')),
              );
            },
            child: const Icon(Icons.call, color: Colors.green, size: 20),
          ),
        ],
      ),
    );
  }
}
