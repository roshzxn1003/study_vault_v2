import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfGeneratorHelper {
  /// Generates a structured, multi-page academic study PDF in bytes
  static Uint8List generateStudyGuidePdf({
    required String title,
    required String subject,
    List<Map<String, String>>? customSections,
  }) {
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    final sections = customSections ?? _getDefaultSectionsForTopic(title, subject);

    // Page 1: Cover / Header & Core Invariants
    PdfPage page = document.pages.add();
    final Size pageSize = page.getClientSize();

    // Fonts & Brushes
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont codeFont = PdfStandardFont(PdfFontFamily.courier, 9);

    final PdfBrush primaryBrush = PdfSolidBrush(PdfColor(99, 102, 241)); // Indigo
    final PdfBrush darkTextBrush = PdfSolidBrush(PdfColor(15, 23, 42)); // Slate
    final PdfBrush secondaryTextBrush = PdfSolidBrush(PdfColor(71, 85, 105)); // Gray

    double currentY = 0;

    // Header Banner
    final PdfPen borderPen = PdfPen(PdfColor(226, 232, 240), width: 1);
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(248, 250, 252)),
      pen: borderPen,
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 65),
    );

    page.graphics.drawString(
      "STUDY VAULT ACADEMIC COMPANION • $subject",
      subtitleFont,
      brush: primaryBrush,
      bounds: Rect.fromLTWH(14, currentY + 10, pageSize.width - 28, 16),
    );

    page.graphics.drawString(
      title,
      titleFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(14, currentY + 28, pageSize.width - 28, 26),
    );

    currentY += 80;

    // Draw sections
    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final heading = section['heading'] ?? 'Section ${i + 1}';
      final body = section['body'] ?? '';
      final isCode = section['isCode'] == 'true';

      // Check if space remains on page, else add page
      if (currentY > pageSize.height - 120) {
        page = document.pages.add();
        currentY = 20;
      }

      // Section Heading
      page.graphics.drawString(
        heading,
        headingFont,
        brush: primaryBrush,
        bounds: Rect.fromLTWH(0, currentY, pageSize.width, 20),
      );
      currentY += 22;

      // Section Body / Content
      final PdfLayoutResult layoutResult;
      if (isCode) {
        final PdfTextElement codeElement = PdfTextElement(
          text: body,
          font: codeFont,
          brush: darkTextBrush,
        );
        layoutResult = codeElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, currentY, pageSize.width, pageSize.height - currentY),
        )!;
      } else {
        final PdfTextElement textElement = PdfTextElement(
          text: body,
          font: bodyFont,
          brush: darkTextBrush,
        );
        layoutResult = textElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, currentY, pageSize.width, pageSize.height - currentY),
        )!;
      }

      page = layoutResult.page;
      currentY = layoutResult.bounds.bottom + 16;
    }

    // High Yield Exam Callout Box
    if (currentY > pageSize.height - 90) {
      page = document.pages.add();
      currentY = 20;
    }

    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(238, 242, 255)), // Indigo tint
      pen: PdfPen(PdfColor(99, 102, 241), width: 1.5),
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 60),
    );

    page.graphics.drawString(
      "🎯 High-Yield Exam Review & Active Recall",
      boldBodyFont,
      brush: primaryBrush,
      bounds: Rect.fromLTWH(12, currentY + 8, pageSize.width - 24, 16),
    );

    page.graphics.drawString(
      "• Master key invariant proofs, comparative trade-offs, and boundary edge cases.\n• Use Study Vault's AI Tutor and practice quizzes to verify mastery.",
      bodyFont,
      brush: secondaryTextBrush,
      bounds: Rect.fromLTWH(12, currentY + 26, pageSize.width - 24, 28),
    );

    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static List<Map<String, String>> _getDefaultSectionsForTopic(String title, String subject) {
    if (title.toLowerCase().contains('acid') || title.toLowerCase().contains('transaction') || subject.toLowerCase().contains('dbms')) {
      return [
        {
          'heading': '1. Executive Overview & Transaction Semantics',
          'body': 'A transaction is a logical unit of database processing that includes one or more database operations. To ensure data integrity in concurrent execution and failure conditions, databases enforce ACID properties:\n\n• Atomicity: Entire transaction executes to completion or has no effect.\n• Consistency: Preserves database invariants before and after commit.\n• Isolation: Concurrent transactions do not observe intermediate states.\n• Durability: Once committed, state changes survive system crashes.',
        },
        {
          'heading': '2. Two-Phase Locking (2PL) & Serializability',
          'body': 'Serializability is the standard correctness criterion for concurrent execution:\n• Growing Phase: Locks acquired, none released.\n• Shrinking Phase: Locks released, none acquired.\n• Strict 2PL: All Exclusive locks held until commit to prevent cascading aborts.',
        },
        {
          'heading': '3. Pseudocode & Transaction State Transition',
          'isCode': 'true',
          'body': 'BEGIN TRANSACTION;\n  UPDATE Accounts SET balance = balance - 100 WHERE id = 101;\n  UPDATE Accounts SET balance = balance + 100 WHERE id = 102;\n  IF (balance < 0) ROLLBACK;\n  ELSE COMMIT;',
        },
        {
          'heading': '4. Common Exam Pitfalls & Recovery Mechanisms',
          'body': '1. Dirty Reads (Read Uncommitted data of an aborted transaction).\n2. Unrepeatable Reads (Multiple reads yield different values due to intermediate updates).\n3. Phantom Reads (New tuples inserted by other transactions in range queries).\n4. Write-Ahead Logging (WAL): Log records written to stable storage before data pages to guarantee Atomicity and Durability.',
        },
      ];
    } else if (title.toLowerCase().contains('deadlock') || subject.toLowerCase().contains('operating')) {
      return [
        {
          'heading': '1. Definition & Coffman Conditions',
          'body': 'A deadlock occurs when a set of concurrent processes are permanently blocked because each process holds a resource and waits for another resource held by another process.\n\nFour Necessary & Sufficient Coffman Conditions:\n1. Mutual Exclusion: At least one resource held in non-shareable mode.\n2. Hold and Wait: Process holds resources while requesting additional ones.\n3. No Preemption: Resources cannot be forcibly taken away.\n4. Circular Wait: A closed chain of processes where each waits for the next.',
        },
        {
          'heading': '2. Banker\'s Algorithm & Safe States',
          'body': 'The Banker\'s Algorithm dynamically checks resource allocation requests to ensure the system never transitions into an unsafe state:\n• Vector Available[m]: Available resource instances.\n• Matrix Max[n][m]: Maximum demand of each process.\n• Matrix Allocation[n][m]: Currently allocated instances.\n• Matrix Need[n][m] = Max[n][m] - Allocation[n][m].',
        },
        {
          'heading': '3. High-Yield Recovery Strategies',
          'body': '• Resource Preemption: Selecting a victim process and rolling back state.\n• Process Termination: Aborting circular processes one by one until cycle breaks.\n• Deadlock Ignorance (Ostrich Algorithm): Used in modern general-purpose OS when deadlocks are exceptionally rare.',
        },
      ];
    } else if (title.toLowerCase().contains('tcp') || title.toLowerCase().contains('udp') || subject.toLowerCase().contains('network')) {
      return [
        {
          'heading': '1. Transport Layer Protocols: TCP vs UDP',
          'body': 'Transmission Control Protocol (TCP) and User Datagram Protocol (UDP) represent the fundamental transport paradigms in the Internet Protocol suite:\n\n• TCP: Connection-oriented, reliable, ordered delivery, flow control (sliding window), and congestion control.\n• UDP: Connectionless, unreliable datagram service, minimal latency overhead, ideal for real-time streaming and DNS.',
        },
        {
          'heading': '2. Three-Way Handshake & Flow Control',
          'body': 'TCP establishes connections via SYN -> SYN-ACK -> ACK. Flow control uses the Receive Window (rwnd) advertised in TCP headers to prevent fast senders from overwhelming slow receivers.',
        },
        {
          'heading': '3. High-Yield Examination Comparison Table',
          'body': 'Feature | TCP | UDP\nConnection: | State-oriented | Connectionless\nHeader Size: | 20-60 bytes | 8 bytes\nRetransmission: | Yes (ARQ) | No\nUse Cases: | HTTP, SSH, Files | DNS, VoIP, Gaming',
        },
      ];
    } else {
      return [
        {
          'heading': '1. Core Conceptual Foundations',
          'body': 'Mastering $title requires deep understanding of system architecture, operational constraints, and fundamental principles of $subject.\n\nKey Invariants:\n• Deterministic behavior under load.\n• Safe resource allocation and isolation.\n• Fault tolerance and predictable state recovery.',
        },
        {
          'heading': '2. Theoretical Breakdown & Analytical Model',
          'body': 'When evaluating systems in $subject, analyze time complexity, space overhead, and coordination latency. Formal specifications guide correct implementations and prevent synchronization anomalies.',
        },
        {
          'heading': '3. High-Yield Examination Key Takeaways',
          'body': '• Always verify precondition requirements before applying theorems.\n• Compare alternative architectural paradigms in structured tables.\n• Review boundary cases and algorithmic invariants.',
        },
      ];
    }
  }
}
