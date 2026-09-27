import 'package:flutter/material.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/data/models/tagihan_model.dart';
import 'package:ladimas/data/services/tagihan_service.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_detail_page.dart';

class TagihanPage extends StatefulWidget {
  final Penduduk penduduk;

  const TagihanPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<TagihanPage> createState() => _TagihanPageState();
}

class _TagihanPageState extends State<TagihanPage> {
  String _selectedFilter = 'Semua';
  final List<String> _filters = [
    'Semua',
    'Belum Lunas',
    'Lunas',
    'Jatuh Tempo'
  ];
  bool _showFilters = false; // State untuk mengontrol visibility filter

  TagihanService? _tagihanService;
  List<TagihanModel> _tagihanList = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _totalTagihan = 0;
  double _sudahLunas = 0;

  // Filter kategori & sub kategori & tanggal
  int? _selectedKategoriId;
  int? _selectedSubKategoriId;
  List<KategoriTagihanModel> _kategoriList = [];
  List<SubKategoriTagihan> _subKategoriList = [];
  String? _startDate; // YYYY-MM-DD
  String? _endDate; // YYYY-MM-DD

  @override
  void initState() {
    super.initState();

    // Validate penduduk data
    if (widget.penduduk.nik.isEmpty || widget.penduduk.token.isEmpty) {
      setState(() {
        _errorMessage = 'Data penduduk tidak lengkap. Silakan login ulang.';
        _isLoading = false;
      });
      return;
    }

    _tagihanService = TagihanService(token: widget.penduduk.token);
    _loadKategori();
    _loadTagihan();
  }

  Future<void> _loadTagihan({bool showErrorDialog = true}) async {
    if (_tagihanService == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Ambil data tagihan dari API dengan filter server-side untuk kategori/sub/tanggal
      final response = await _tagihanService!.getTagihan(
        kategoriId: _selectedKategoriId,
        subKategoriId: _selectedSubKategoriId,
        startDate: _startDate,
        endDate: _endDate,
      );

      List<TagihanModel> filteredList = response.data;

      // Apply local filtering based on selected filter
      if (_selectedFilter != 'Semua') {
        final DateTime today = DateTime.now();
        filteredList = response.data.where((tagihan) {
          final DateTime tagihanDate = DateTime.parse(tagihan.tanggal);
          final bool isOverdue = tagihanDate.isBefore(today);
          final bool isLunas = tagihan.status.toLowerCase() == 'lunas' ||
              tagihan.status.toLowerCase() == 'sudah_bayar';

          switch (_selectedFilter) {
            case 'Belum Lunas':
              // Tagihan yang belum lunas (tidak peduli sudah overdue atau belum)
              return !isLunas;
            case 'Lunas':
              return isLunas;
            case 'Jatuh Tempo':
              // Tagihan yang sudah melewati tanggal jatuh tempo DAN belum lunas
              return isOverdue && !isLunas;
            default:
              return true;
          }
        }).toList();
      }

      setState(() {
        _tagihanList = filteredList;
        _calculateSummary();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        if (showErrorDialog) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Gagal Memuat Data'),
              content: const Text(
                  'Tidak dapat memuat data. Periksa koneksi internet Anda.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Untuk refresh, tampilkan snackbar error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Gagal memperbarui data tagihan. Periksa koneksi internet Anda.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    try {
      await _loadTagihan(showErrorDialog: false);
      // Tampilkan snackbar sukses jika berhasil refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data tagihan berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Tampilkan alert error yang lebih jelas
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Gagal Memperbarui Data',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Tidak dapat memperbarui data tagihan terbaru. '
              'Pastikan koneksi internet Anda stabil dan coba lagi. '
              'Jika masalah berlanjut, hubungi administrator.',
              textAlign: TextAlign.left,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _refreshData(); // Coba lagi
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A47DC),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadKategori() async {
    try {
      final res = await _tagihanService!.getKategoriTagihan();
      setState(() {
        _kategoriList = res.data;
        // Reset sub kategori jika kategori berubah
        _updateSubKategoriOptions();
      });
    } catch (_) {
      // Biarkan kosong jika gagal
      setState(() {
        _kategoriList = [];
        _subKategoriList = [];
      });
    }
  }

  void _onKategoriChanged(int? kategoriId) async {
    setState(() {
      _selectedKategoriId = kategoriId;
      _selectedSubKategoriId = null;
      _updateSubKategoriOptions();
    });
    await _loadTagihan();
  }

  void _onSubKategoriChanged(int? subId) async {
    setState(() {
      _selectedSubKategoriId = subId;
    });
    await _loadTagihan();
  }

  void _updateSubKategoriOptions() {
    if (_selectedKategoriId == null) {
      _subKategoriList = [];
      return;
    }
    final found = _kategoriList.firstWhere(
      (k) => k.id == _selectedKategoriId,
      orElse: () => KategoriTagihanModel(id: -1, nama: '', subKategori: []),
    );
    _subKategoriList = found.subKategori;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _startDate = _formatYmd(picked);
      });
      await _loadTagihan();
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _endDate = _formatYmd(picked);
      });
      await _loadTagihan();
    }
  }

  String _formatYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  void _calculateSummary() {
    _totalTagihan =
        _tagihanList.fold(0, (sum, tagihan) => sum + tagihan.nominal);
    _sudahLunas = _tagihanList
        .where((tagihan) =>
            tagihan.status.toLowerCase() == 'lunas' ||
            tagihan.status.toLowerCase() == 'sudah_bayar')
        .fold(0, (sum, tagihan) => sum + tagihan.nominal);
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadTagihan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Header Section (tanpa AppBar, seragam dengan halaman lain)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFFF5F6FA)),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 20, 20, 20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                      icon: Icon(
                        _showFilters
                            ? Icons.filter_list_off
                            : Icons.filter_list,
                        color: Color(0xFF4A47DC),
                        size: 24,
                      ),
                      tooltip: _showFilters
                          ? 'Sembunyikan Filter'
                          : 'Tampilkan Filter',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Tagihan',
                          style: TextStyle(
                            color: Color(0xFF4A47DC),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _refreshData,
                      icon: Icon(
                        Icons.refresh,
                        color: Color(0xFF4A47DC),
                        size: 24,
                      ),
                      tooltip: 'Refresh Data',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
            // Filter Section - dengan animasi
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.vertical,
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _showFilters
                  ? Padding(
                      key: const ValueKey('filter_visible'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFilterSection(),
                    )
                  : const SizedBox.shrink(key: ValueKey('filter_hidden')),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),

                    // Bills List
                    Expanded(child: _buildBillsList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF4A47DC),
        unselectedItemColor: Colors.grey,
        currentIndex: 4, // Tagihan
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.storefront_sharp, size: 28), label: 'Warungku'),
          BottomNavigationBarItem(
              icon: Icon(Icons.apps, size: 28), label: 'Informasi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance, size: 28),
              label: 'Profil Desa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long, size: 28), label: 'Tagihan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.description, size: 28), label: 'Portal'),
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
                  builder: (_) => PendudukHomePage(
                    penduduk: widget.penduduk,
                    initialTabIndex: 0, // Berita Desa tab
                  ),
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilDesaPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 4:
              // Current page - Tagihan
              break;
            case 5:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DocumentServicesWebViewPage(penduduk: widget.penduduk),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Chips status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onFilterChanged(filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4A47DC)
                              : const Color(0xFFEDEBFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF4A47DC),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Baris 2: Kategori, Sub Kategori, Tanggal, Reset
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;
              if (isSmallScreen) {
                // Layout vertikal untuk layar kecil
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildKategoriDropdown()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSubKategoriDropdown()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                              label: _startDate == null
                                  ? 'Mulai'
                                  : 'Mulai: $_startDate',
                              onTap: _pickStartDate),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDateButton(
                              label: _endDate == null
                                  ? 'Selesai'
                                  : 'Selesai: $_endDate',
                              onTap: _pickEndDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildResetButton(),
                  ],
                );
              } else {
                // Layout horizontal untuk layar besar
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKategoriDropdown(),
                      const SizedBox(width: 12),
                      _buildSubKategoriDropdown(),
                      const SizedBox(width: 12),
                      _buildDateButton(
                          label: _startDate == null
                              ? 'Mulai'
                              : 'Mulai: $_startDate',
                          onTap: _pickStartDate),
                      const SizedBox(width: 8),
                      _buildDateButton(
                          label: _endDate == null
                              ? 'Selesai'
                              : 'Selesai: $_endDate',
                          onTap: _pickEndDate),
                      const SizedBox(width: 8),
                      _buildResetButton(),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedKategoriId = null;
          _selectedSubKategoriId = null;
          _subKategoriList = [];
          _startDate = null;
          _endDate = null;
        });
        _loadTagihan();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear, size: 16, color: Colors.red),
            SizedBox(width: 6),
            Text('Reset', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriDropdown() {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.category, size: 14, color: Color(0xFF4A47DC)),
          const SizedBox(width: 2),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedKategoriId,
                hint: const Text('Kategori', style: TextStyle(fontSize: 11)),
                isDense: true,
                isExpanded: true,
                style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
                items: _kategoriList
                    .map((k) => DropdownMenuItem<int>(
                          value: k.id,
                          child: Text(k.nama, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _onKategoriChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubKategoriDropdown() {
    return Container(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 150),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label, size: 14, color: Color(0xFF4A47DC)),
          const SizedBox(width: 2),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSubKategoriId,
                hint:
                    const Text('Sub Kategori', style: TextStyle(fontSize: 11)),
                isDense: true,
                isExpanded: true,
                style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
                items: _subKategoriList
                    .map((s) => DropdownMenuItem<int>(
                          value: s.id,
                          child: Text(s.nama, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _onSubKategoriChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(
      {required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 130),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, color: Color(0xFF4A47DC), size: 14),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4A47DC),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Tagihan',
            amount: _tagihanService != null
                ? _tagihanService!.formatNominal(_totalTagihan)
                : 'Rp ${_totalTagihan.toStringAsFixed(0)}',
            color: Colors.red,
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Sudah Lunas',
            amount: _tagihanService != null
                ? _tagihanService!.formatNominal(_sudahLunas)
                : 'Rp ${_sudahLunas.toStringAsFixed(0)}',
            color: Colors.green,
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A47DC)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data tagihan',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTagihan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A47DC),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_tagihanList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada tagihan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tagihan akan muncul di sini ketika tersedia',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Tagihan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _tagihanList.length,
            itemBuilder: (context, index) {
              final tagihan = _tagihanList[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBillItemFromModel(tagihan),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBillItem({
    required String title,
    required String amount,
    required String dueDate,
    required String status,
    required Color statusColor,
    TagihanModel? tagihan,
  }) {
    return GestureDetector(
      onTap: () {
        if (tagihan != null) {
          _navigateToDetail(tagihan);
        }
      },
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A47DC),
                  ),
                ),
                Text(
                  'Jatuh Tempo: $dueDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBillItemFromModel(TagihanModel tagihan) {
    final String baseTitle = tagihan.kategori?.nama ?? 'Tagihan';
    final String owner = [
      if ((tagihan.fullName ?? '').isNotEmpty) tagihan.fullName,
      if ((tagihan.nik ?? '').isNotEmpty) '(${tagihan.nik})',
    ].whereType<String>().join(' ');
    final String title = owner.isNotEmpty ? '$baseTitle • $owner' : baseTitle;
    final String amount =
        tagihan.nominalFormatted ?? 'Rp ${tagihan.nominal.toStringAsFixed(0)}';
    final String dueDate =
        _tagihanService?.formatTanggal(tagihan.tanggal) ?? tagihan.tanggal;

    // Determine status based on date and API status
    String status;
    Color color;

    if (tagihan.status.toLowerCase() == 'lunas' ||
        tagihan.status.toLowerCase() == 'sudah_bayar') {
      status = 'Lunas';
      color = Colors.green;
    } else {
      // Check if tagihan is overdue
      final DateTime today = DateTime.now();
      final DateTime tagihanDate = DateTime.parse(tagihan.tanggal);
      final bool isOverdue = tagihanDate.isBefore(today);

      if (isOverdue) {
        status = 'Jatuh Tempo';
        color = Colors.orange;
      } else {
        status = 'Belum Lunas';
        color = Colors.red;
      }
    }

    return _buildBillItem(
      title: title,
      amount: amount,
      dueDate: dueDate,
      status: status,
      statusColor: color,
      tagihan: tagihan,
    );
  }

  void _navigateToDetail(TagihanModel tagihan) {
    // TODO: Implement navigation to detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TagihanDetailPage(tagihan: tagihan, penduduk: widget.penduduk),
      ),
    );
  }

  void _showPaymentDialog(String title, String amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            color: Color(0xFF4A47DC),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tagihan: $title'),
            const SizedBox(height: 8),
            Text('Jumlah: $amount'),
            const SizedBox(height: 16),
            const Text(
              'Pilih metode pembayaran:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildPaymentMethod('Transfer Bank', Icons.account_balance),
            const SizedBox(height: 8),
            _buildPaymentMethod('E-Wallet', Icons.phone_android),
            const SizedBox(height: 8),
            _buildPaymentMethod('Tunai', Icons.money),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pembayaran berhasil diproses'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A47DC),
              foregroundColor: Colors.white,
            ),
            child: const Text('BAYAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String method, IconData icon) {
    return GestureDetector(
      onTap: () {
        // TODO: Handle payment method selection
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF4A47DC)),
            const SizedBox(width: 12),
            Text(method),
          ],
        ),
      ),
    );
  }
}
