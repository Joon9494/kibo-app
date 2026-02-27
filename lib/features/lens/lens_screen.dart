import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../calendar/schedule_service.dart';

class LensScreen extends StatefulWidget {
  const LensScreen({super.key});

  @override
  State<LensScreen> createState() => _LensScreenState();
}

class _LensScreenState extends State<LensScreen> {
  final _scheduleService = ScheduleService();
  final _picker = ImagePicker();

  File? _selectedImage;
  bool _loading = false;
  String _resultText = '';
  List<Map<String, dynamic>> _parsedSchedules = [];
  final Set<int> _savedIndices = {};

  final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiFlashModel,
    apiKey: AppConstants.geminiApiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    ),
  );

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _selectedImage = File(picked.path);
      _resultText = '';
      _parsedSchedules = [];
      _savedIndices.clear();
    });
    await _analyzeImage(_selectedImage!);
  }

  Future<void> _analyzeImage(File imageFile) async {
    if (!mounted) return;
    setState(() => _loading = true);

    // todayStr을 try 블록 밖에서 선언 — catch에서도 접근 가능
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      final imageBytes = await imageFile.readAsBytes();

      final prompt = '''
오늘 날짜: $todayStr

이 이미지에서 일정 정보를 추출해줘.
메모, 포스터, 문서, 캘린더 사진 등에서 날짜/시간/장소/내용을 찾아줘.
일정이 여러 개면 모두 포함해.
일정이 없으면 빈 배열을 반환해.

반환 형식 (JSON 배열):
[
  {
    "title": "일정 제목",
    "date": "YYYY-MM-DD",
    "time": "HH:MM",
    "location": "장소 (없으면 빈 문자열)",
    "description": "추가 설명 (없으면 빈 문자열)"
  }
]

규칙:
- 날짜가 없으면 오늘 날짜 사용
- 시간이 없으면 "09:00" 사용
- 오전/오후를 24시간으로 변환
''';

      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      if (!mounted) return;

      final text = response.text;
      if (text == null || text.isEmpty) {
        setState(() {
          _resultText = '이미지에서 일정을 찾지 못했어요.';
          _loading = false;
        });
        return;
      }

      final decoded = jsonDecode(text);
      final List<dynamic> rawList = decoded is List ? decoded : [];

      final List<Map<String, dynamic>> schedules = rawList
          .whereType<Map>()
          .map((item) => {
                'title': item['title']?.toString() ?? '제목 없음',
                'date': item['date']?.toString() ?? todayStr,
                'time': item['time']?.toString() ?? '09:00',
                'location': item['location']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _parsedSchedules = schedules;
        _resultText = schedules.isEmpty
            ? '이미지에서 일정을 찾지 못했어요.'
            : '${schedules.length}개의 일정을 찾았어요!';
        _loading = false;
      });
    } catch (e) {
      debugPrint('렌즈 오류: $e');
      if (!mounted) return;
      setState(() {
        _resultText = '분석 중 오류가 발생했어요.';
        _loading = false;
      });
    }
  }

  Future<void> _saveSchedule(Map<String, dynamic> schedule, int index) async {
    final success = await _scheduleService.saveSchedule(schedule);
    if (!mounted) return;
    if (success) {
      setState(() => _savedIndices.add(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${schedule['title']}" 저장됐어요!'),
          backgroundColor: KiboTheme.teal,
          action: SnackBarAction(
            label: '홈으로',
            textColor: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장 중 오류가 발생했어요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('렌즈', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 텍스트
            Text(
              '📷 사진을 찍거나 갤러리에서 선택하면\nAI가 일정을 자동으로 찾아드려요!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 버튼 영역
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _loading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('카메라'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 이미지 미리보기 또는 플레이스홀더
            _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          '이미지를 선택해주세요',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),

            // 로딩 상태
            if (_loading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'AI가 이미지를 분석 중이에요...',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],

            // 결과 텍스트
            if (_resultText.isNotEmpty && !_loading) ...[
              const SizedBox(height: 20),
              Text(
                _resultText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _parsedSchedules.isEmpty
                      ? Colors.grey
                      : KiboTheme.teal,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 파싱된 일정 목록
            if (_parsedSchedules.isNotEmpty && !_loading) ...[
              const SizedBox(height: 16),
              ..._parsedSchedules.asMap().entries.map((entry) {
                final index = entry.key;
                final schedule = entry.value;
                final location = schedule['location'] as String? ?? '';
                final description = schedule['description'] as String? ?? '';
                final isSaved = _savedIndices.contains(index);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                schedule['title'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            isSaved
                                ? Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: KiboTheme.teal, size: 20),
                                      const SizedBox(width: 4),
                                      Text('저장됨',
                                          style: TextStyle(
                                              color: KiboTheme.teal,
                                              fontSize: 13)),
                                    ],
                                  )
                                : ElevatedButton(
                                    onPressed: () =>
                                        _saveSchedule(schedule, index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: KiboTheme.teal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('저장'),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '📅 ${schedule['date']} ${schedule['time']}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📍 $location',
                            style: TextStyle(
                                fontSize: 13, color: KiboTheme.teal),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}