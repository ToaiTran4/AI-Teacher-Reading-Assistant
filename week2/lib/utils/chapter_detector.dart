import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Class chứa thông tin Chương
class ChapterInfo {
  final int pageNumber;
  final String title;
  final int lineIndex;
  final List<SectionInfo> sections;

  ChapterInfo({
    required this.pageNumber,
    required this.title,
    required this.lineIndex,
    List<SectionInfo>? sections,
  }) : sections = sections ?? [];

  @override
  String toString() => '$title (Trang $pageNumber) - ${sections.length} mục';
}

/// Class chứa thông tin Mục con
class SectionInfo {
  final int pageNumber;
  final String title;
  final int lineIndex;

  SectionInfo({
    required this.pageNumber,
    required this.title,
    required this.lineIndex,
  });

  @override
  String toString() => '$title';
}

class ChapterDetector {
  /// Hàm chính để quét toàn bộ PDF
  static List<ChapterInfo> detectChapters(PdfDocument document) {
    final chapters = <ChapterInfo>[];
    final textExtractor = PdfTextExtractor(document);

    // Biến lưu chương hiện tại đang quét
    ChapterInfo? currentChapter;

    // --- CẤU HÌNH REGEX ---
    final chapterPatterns = [
      RegExp(
          r'^(\d+\.\s+)?(Chương|CHƯƠNG|Bài|BÀI|Phần|PHẦN|Chapter|CHAPTER|Part|PART|Lesson|LESSON)\s+\d+.*',
          caseSensitive: false),
      RegExp(r'^(\d+\.\s+)?(Chương|Chapter)\s+[IVX]+.*', caseSensitive: false),
    ];

    final sectionPatterns = [
      RegExp(r'^\d+\.\d+(\.\d+)?\s+.+', caseSensitive: false),
      RegExp(r'^(Mục|MỤC|Tiểu mục|Section|SECTION)\s+\d+.*',
          caseSensitive: false),
    ];

    // Regex dùng riêng cho việc đếm mật độ từ khóa để phát hiện Mục Lục
    // Chỉ đếm khi có "Chương" đi kèm với "Số" để tránh đếm nhầm từ "chương" trong văn xuôi
    final tocDensityPattern = RegExp(
        r'(Chương|CHƯƠNG|Bài|BÀI|Chapter|CHAPTER)\s+(\d+|[IVX]+)',
        caseSensitive: false);

    // --- BẮT ĐẦU QUÉT ---
    for (int pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
      try {
        final pageText = textExtractor.extractText(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );

        if (pageText.trim().isEmpty) continue;

        // --- LOGIC MỚI: PHÁT HIỆN TRANG MỤC LỤC DỰA TRÊN MẬT ĐỘ TỪ KHÓA ---
        // Đếm số lần xuất hiện cụm từ "Chương X" trong toàn bộ trang
        int chapterKeywordCount = tocDensityPattern.allMatches(pageText).length;

        // Nếu một trang có quá 2 lần nhắc đến "Chương X", coi đó là Mục Lục
        // (Bình thường 1 trang chỉ chứa tiêu đề của 1 chương, hoặc tối đa 2 nếu chương cũ kết thúc ngắn)
        if (chapterKeywordCount > 2) {
          // print("Bỏ qua trang ${pageIndex + 1} vì nghi ngờ là Mục Lục ($chapterKeywordCount chương).");
          continue;
        }
        // -------------------------------------------------------------------

        final lines = pageText.split('\n');

        for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          final line = lines[lineIndex].trim();
          if (line.isEmpty) continue;

          // 1. KIỂM TRA CHƯƠNG (CHAPTER)
          bool isChapterFound = false;
          for (final pattern in chapterPatterns) {
            if (pattern.hasMatch(line)) {
              if (_isValidChapterTitle(line, lineIndex, lines)) {
                final newChapter = ChapterInfo(
                  pageNumber: pageIndex + 1,
                  title: line,
                  lineIndex: lineIndex,
                );

                chapters.add(newChapter);
                currentChapter = newChapter;
                isChapterFound = true;
                break;
              }
            }
          }

          if (isChapterFound) continue;

          // 2. KIỂM TRA MỤC CON (SECTION)
          if (currentChapter != null) {
            for (final pattern in sectionPatterns) {
              if (pattern.hasMatch(line)) {
                if (_isValidSectionTitle(line)) {
                  currentChapter.sections.add(SectionInfo(
                    pageNumber: pageIndex + 1,
                    title: line,
                    lineIndex: lineIndex,
                  ));
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        print("Lỗi đọc trang ${pageIndex + 1}: $e");
        continue;
      }
    }

    return chapters;
  }

  /// Kiểm tra tính hợp lệ của tiêu đề Chương
  static bool _isValidChapterTitle(
      String title, int lineIndex, List<String> lines) {
    if (title.length > 150 || title.length < 4) return false;

    // Các logic lọc TOC cũ vẫn giữ lại để bổ trợ
    if (title.contains('....')) return false;
    if (RegExp(r'.+\s+\d+$').hasMatch(title)) return false;

    if (lineIndex + 1 < lines.length) {
      final nextLine = lines[lineIndex + 1].trim();
      if (RegExp(r'^\d+$').hasMatch(nextLine)) return false;
      if (nextLine.contains('....')) return false;
    }

    return true;
  }

  static bool _isValidSectionTitle(String title) {
    if (title.length > 150 || title.length < 3) return false;
    if (RegExp(r'^\d+\.\d+(\.\d+)?$').hasMatch(title)) return false;
    if (title.contains('....')) return false;
    if (RegExp(r'.+\s+\d+$').hasMatch(title)) return false;
    return true;
  }
}
