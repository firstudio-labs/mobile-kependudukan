import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/data/models/tagihan_model.dart';
import 'package:ladimas/data/services/tagihan_service.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_detail_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';

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
  bool _showFilters = false;

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
              return !isLunas;
            case 'Lunas':
              return isLunas;
            case 'Jatuh Tempo':
              return isOverdue && !isLunas;
            default:
              return true;
          }
        }).toList();
      }

      if (mounted) {
        setState(() {
          _tagihanList = filteredList;
          _calculateSummary();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (showErrorDialog) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Gagal Memuat Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Gagal memperbarui data tagihan. Periksa koneksi internet Anda.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      await _loadTagihan(showErrorDialog: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data tagihan berhasil diperbarui'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Gagal Memperbarui Data',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Tidak dapat memperbarui data tagihan terbaru. '
              'Pastikan koneksi internet Anda stabil dan coba lagi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _refreshData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
      if (mounted) {
        setState(() {
          _kategoriList = res.data;
          _updateSubKategoriOptions();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _kategoriList = [];
          _subKategoriList = [];
        });
      }
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tagihan',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => setState(() => _showFilters = !_showFilters),
          icon: Icon(
            _showFilters
                ? Icons.filter_list_off_rounded
                : Icons.filter_list_rounded,
            color: _showFilters ? AppTheme.primaryColor : AppTheme.primaryColor,
            size: 22,
          ),
          tooltip: _showFilters ? 'Sembunyikan Filter' : 'Tampilkan Filter',
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        child: Column(
          children: [
            // Filter Section - dengan animasi
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
                      padding: const EdgeInsets.only(top: 0),
                      child: _buildFilterSection(),
                    )
                  : const SizedBox.shrink(key: ValueKey('filter_hidden')),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 16),

                    // Bills List
                    Expanded(child: _buildBillsList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4, // Tagihan
        items: [
          AppBottomNavBar.item(icon: Icons.home_outlined, label: 'Beranda'),
          AppBottomNavBar.item(icon: Icons.storefront, label: 'Warungku'),
          AppBottomNavBar.item(
              icon: Icons.grid_view_outlined, label: 'Informasi'),
          AppBottomNavBar.item(
              icon: Icons.account_balance_outlined, label: 'Profil Desa'),
          AppBottomNavBar.item(icon: Icons.receipt_long, label: 'Tagihan'),
          AppBottomNavBar.item(
              icon: Icons.description_outlined, label: 'Portal'),
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
                    initialTabIndex: 0,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Chips status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _onFilterChanged(filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Baris 2: Kategori, Sub Kategori, Tanggal, Reset
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;
              if (isSmallScreen) {
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
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKategoriDropdown(),
                      const SizedBox(width: 10),
                      _buildSubKategoriDropdown(),
                      const SizedBox(width: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 15, color: Color(0xFFDC2626)),
            SizedBox(width: 4),
            Text(
              'Reset',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriDropdown() {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.category_outlined,
              size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedKategoriId,
                hint: const Text('Kategori',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                isDense: true,
                isExpanded: true,
                style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label_outline,
              size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSubKategoriId,
                hint: const Text('Sub Kategori',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                isDense: true,
                isExpanded: true,
                style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
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
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range_outlined,
                color: AppTheme.primaryColor, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
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
            color: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            icon: Icons.receipt_long_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Sudah Lunas',
            amount: _tagihanService != null
                ? _tagihanService!.formatNominal(_sudahLunas)
                : 'Rp ${_sudahLunas.toStringAsFixed(0)}',
            color: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required Color color,
    required Color iconBg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
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
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Data Tagihan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTagihan,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Tagihan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tagihan akan tercatat di sini saat tersedia.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Tagihan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              '${_tagihanList.length} Tagihan',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _tagihanList.length,
            itemBuilder: (context, index) {
              final tagihan = _tagihanList[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
    required Color statusBgColor,
    required IconData statusIcon,
    TagihanModel? tagihan,
  }) {
    return GestureDetector(
      onTap: () {
        if (tagihan != null) {
          _navigateToDetail(tagihan);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nominal',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tempo: $dueDate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    Color bgColor;
    IconData icon;

    if (tagihan.status.toLowerCase() == 'lunas' ||
        tagihan.status.toLowerCase() == 'sudah_bayar') {
      status = 'Lunas';
      color = const Color(0xFF059669);
      bgColor = const Color(0xFFD1FAE5);
      icon = Icons.check_circle_rounded;
    } else {
      final DateTime today = DateTime.now();
      final DateTime tagihanDate = DateTime.parse(tagihan.tanggal);
      final bool isOverdue = tagihanDate.isBefore(today);

      if (isOverdue) {
        status = 'Jatuh Tempo';
        color = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        icon = Icons.warning_amber_rounded;
      } else {
        status = 'Belum Lunas';
        color = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEE2E2);
        icon = Icons.error_outline_rounded;
      }
    }

    return _buildBillItem(
      title: title,
      amount: amount,
      dueDate: dueDate,
      status: status,
      statusColor: color,
      statusBgColor: bgColor,
      statusIcon: icon,
      tagihan: tagihan,
    );
  }

  void _navigateToDetail(TagihanModel tagihan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TagihanDetailPage(tagihan: tagihan, penduduk: widget.penduduk),
      ),
    );
  }
}
