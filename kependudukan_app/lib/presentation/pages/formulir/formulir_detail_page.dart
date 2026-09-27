import 'package:flutter/material.dart';
import 'package:ladimas/data/models/formulir_model.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/data/datasources/formulir_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:http/http.dart' as http;

class FormulirDetailPage extends StatefulWidget {
  final FormulirModel formulir;
  final Penduduk penduduk;

  const FormulirDetailPage({
    Key? key,
    required this.formulir,
    required this.penduduk,
  }) : super(key: key);

  @override
  State<FormulirDetailPage> createState() => _FormulirDetailPageState();
}

class _FormulirDetailPageState extends State<FormulirDetailPage> {
  final Map<int, String> _answers = {};
  bool _isSubmitting = false;
  late final FormulirApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = FormulirApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
  }

  Future<void> _submit() async {
    // Validate all questions answered
    if (_answers.length < widget.formulir.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon jawab semua pertanyaan sebelum mengirim.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _apiService.submitFormulir(
        widget.formulir.id,
        _answers.map((key, value) => MapEntry(key.toString(), value)),
      );

      if (success) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Berhasil Terkirim',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Terima kasih atas partisipasi Anda mengisi ${widget.formulir.title}.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Return to Beranda with true to refresh
                  },
                  child: const Text('Tutup'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Gagal mengirim jawaban');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Isi Kuesioner',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D336B), Color(0xFF4A56A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.formulir.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.formulir.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.formulir.description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Questions List
            ...widget.formulir.questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D336B),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            question.questionText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (question.questionType == 'pilihan_ganda' &&
                        question.options != null)
                      ...question.options!.map((option) {
                        final isSelected = _answers[question.id] == option;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2D336B)
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: RadioListTile<String>(
                            value: option,
                            groupValue: _answers[question.id],
                            activeColor: const Color(0xFF2D336B),
                            title: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF2D336B)
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _answers[question.id] = value!;
                              });
                            },
                          ),
                        );
                      }).toList(),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 16),
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D336B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Kirim Jawaban',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
