import 'package:ladimas/data/models/pengumuman_model.dart';
import 'package:ladimas/data/models/berita_desa_model.dart';
import 'package:ladimas/data/models/laporan_model.dart';
import 'package:ladimas/data/models/agenda_model.dart';

/// Global data manager untuk menyimpan data PendudukHomePage
/// Menggunakan singleton pattern untuk memastikan data persisten di level aplikasi
class PendudukHomeDataManager {
  static final PendudukHomeDataManager _instance =
      PendudukHomeDataManager._internal();
  factory PendudukHomeDataManager() => _instance;
  PendudukHomeDataManager._internal();

  // Data storage
  List<PengumumanModel> _pengumuman = [];
  List<BeritaDesaModel> _beritaDesa = [];
  List<VillageReportModel> _laporan = [];
  List<AgendaModel> _agenda = [];

  // Loading states
  bool _isLoadingPengumuman = false;
  bool _isLoadingBerita = false;
  bool _isLoadingLaporan = false;
  bool _isLoadingAgenda = false;

  // Data loading flags
  bool _hasLoadedData = false;
  DateTime? _lastDataLoadTime;

  // Getters
  List<PengumumanModel> get pengumuman => _pengumuman;
  List<BeritaDesaModel> get beritaDesa => _beritaDesa;
  List<VillageReportModel> get laporan => _laporan;
  List<AgendaModel> get agenda => _agenda;

  bool get isLoadingPengumuman => _isLoadingPengumuman;
  bool get isLoadingBerita => _isLoadingBerita;
  bool get isLoadingLaporan => _isLoadingLaporan;
  bool get isLoadingAgenda => _isLoadingAgenda;

  bool get hasLoadedData => _hasLoadedData;
  DateTime? get lastDataLoadTime => _lastDataLoadTime;

  // Setters
  void setPengumuman(List<PengumumanModel> data) {
    _pengumuman = data;
  }

  void setBeritaDesa(List<BeritaDesaModel> data) {
    _beritaDesa = data;
  }

  void setLaporan(List<VillageReportModel> data) {
    _laporan = data;
  }

  void setAgenda(List<AgendaModel> data) {
    _agenda = data;
  }

  void setLoadingPengumuman(bool loading) {
    _isLoadingPengumuman = loading;
  }

  void setLoadingBerita(bool loading) {
    _isLoadingBerita = loading;
  }

  void setLoadingLaporan(bool loading) {
    _isLoadingLaporan = loading;
  }

  void setLoadingAgenda(bool loading) {
    _isLoadingAgenda = loading;
  }

  void setDataLoaded(bool loaded) {
    _hasLoadedData = loaded;
  }

  void setLastDataLoadTime(DateTime? time) {
    _lastDataLoadTime = time;
  }

  // Method untuk cek apakah data masih fresh (dalam 1 menit - lebih agresif untuk data real-time)
  bool get isDataFresh {
    if (!_hasLoadedData || _lastDataLoadTime == null) return false;
    final now = DateTime.now();
    return now.difference(_lastDataLoadTime!).inMinutes < 1;
  }

  // Method untuk reset semua data
  void resetAllData() {
    _pengumuman = [];
    _beritaDesa = [];
    _laporan = [];
    _agenda = [];
    _isLoadingPengumuman = false;
    _isLoadingBerita = false;
    _isLoadingLaporan = false;
    _isLoadingAgenda = false;
    _hasLoadedData = false;
    _lastDataLoadTime = null;
  }

  // Method untuk reset loading states
  void resetLoadingStates() {
    _isLoadingPengumuman = false;
    _isLoadingBerita = false;
    _isLoadingLaporan = false;
    _isLoadingAgenda = false;
  }

  // Method untuk update data loaded status
  void markDataAsLoaded() {
    _hasLoadedData = true;
    _lastDataLoadTime = DateTime.now();
  }

  // Method untuk clear semua data dan cache (dipanggil saat logout)
  void clearAllData() {
    _pengumuman = [];
    _beritaDesa = [];
    _laporan = [];
    _agenda = [];
    _isLoadingPengumuman = false;
    _isLoadingBerita = false;
    _isLoadingLaporan = false;
    _isLoadingAgenda = false;
    _hasLoadedData = false;
    _lastDataLoadTime = null;
    print('✅ PendudukHomeDataManager data cleared');
  }

  // Method untuk cek apakah ada perubahan signifikan dalam data
  // (misalnya jumlah item berbeda yang menandakan ada data baru/dihapus)
  bool hasSignificantDataChanges({
    required List pengumuman,
    required List beritaDesa,
    required List laporan,
    required List agenda,
  }) {
    return _pengumuman.length != pengumuman.length ||
           _beritaDesa.length != beritaDesa.length ||
           _laporan.length != laporan.length ||
           _agenda.length != agenda.length;
  }
}
