import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class TicketScannerPage extends StatefulWidget {
  const TicketScannerPage({super.key});

  @override
  State<TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<TicketScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // Assume rawValue is the Booking ID
        _verifyTicket(barcode.rawValue!);
        break; 
      }
    }
  }

  Future<void> _verifyTicket(String bookingId) async {
    setState(() => _isProcessing = true);
    
    // Pause camera while processing
    controller.stop();

    try {
      // 1. Search for Booking ID across all user collections
      // Note: In a real app with millions of users, we'd index this differently.
      // For now, we query collectionGroup 'bookings' where FieldPath.documentId == bookingId
      // Firestore does not natively support querying by Doc ID in collection groups easily without exact path.
      // BUT, we can assume the QR code contains the full JSON or we just query by a 'ticketId' field if we had one.
      // Let's assume the QR Code contains "bookingId|userId" or just "bookingId" and we try to find it.
      // Easiest Hack: Query collectionGroup('bookings') where 'id' == bookingId (if we stored it).
      // Wait, we didn't store 'id' field in the document explicitly (it's the doc ID).
      // Better approach: QR Code contains "userId:bookingId".
      
      // Let's assume for now the QR just has the Booking ID.
      // We will search for it.
      
      final querySnapshot = await FirebaseFirestore.instance.collectionGroup('bookings').get();
      // This is inefficient but works for MVP. Efficient way: QR has path "users/{uid}/bookings/{bid}"
      
      DocumentSnapshot? foundDoc;
      String? foundUserId;
      
      for (var doc in querySnapshot.docs) {
        if (doc.id == bookingId) {
          foundDoc = doc;
          foundUserId = doc.reference.parent.parent!.id; // users/{uid}
          break;
        }
      }

      if (foundDoc == null) {
        _showResultDialog(
          title: "Invalid Ticket",
          message: "Ticket ID not found in system.",
          isSuccess: false,
        );
        return;
      }

      final data = foundDoc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'UNKNOWN';
      final userName = data['userName'] ?? 'Unknown Student';
      final hostelName = data['hostelName'] ?? 'Unknown Hostel';
      final studentSex = data['studentSex'] ?? 'N/A';
      
      // Check Payment
      if (status == 'PAID') {
         _showResultDialog(
           title: "Verified: $userName",
           message: "Hostel: $hostelName\nSex: $studentSex\nStatus: PAID ✅\n\nAccess Granted.",
           isSuccess: true,
           onConfirm: () {
             // Optional: Mark as Checked In
             // foundDoc.reference.update({'status': 'CHECKED_IN'});
           }
         );
      } else if (status == 'CONFIRMED') {
        _showResultDialog(
          title: "Payment Pending",
          message: "Student has been approved but has NOT paid yet.\n\nPlease collect payment first.",
          isSuccess: false,
        );
      } else {
        _showResultDialog(
          title: "Invalid Status",
          message: "Ticket Status: $status\nAccess Denied.",
          isSuccess: false,
        );
      }

    } catch (e) {
      _showResultDialog(title: "Error", message: e.toString(), isSuccess: false);
    }
  }

  void _showResultDialog({required String title, required String message, required bool isSuccess, VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: isSuccess ? Colors.green : Colors.red, fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              setState(() => _isProcessing = false);
              controller.start(); // Resume Scanning
            },
            child: const Text("Scan Next"),
          ),
          if (isSuccess && onConfirm != null)
             ElevatedButton(
               onPressed: () {
                 onConfirm();
                 Navigator.pop(context);
                 setState(() => _isProcessing = false);
                 controller.start();
               },
               child: const Text("Check In"),
             )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Ticket")),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleDetection,
          ),
          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.blue,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          Positioned(
             bottom: 50,
             left: 0,
             right: 0,
             child: Center(
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                 color: Colors.black54,
                 child: const Text("Align QR Code within frame", style: TextStyle(color: Colors.white)),
               ),
             ),
          )
        ],
      ),
    );
  }
}

// Helper class for overlay shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _cutOutSize = cutOutSize;
    final _cutOutBottomOffset = cutOutBottomOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top + height / 2 - _cutOutSize / 2 + _cutOutBottomOffset + borderOffset,
      _cutOutSize - borderWidth,
      _cutOutSize - borderWidth,
    );

    canvas.saveLayer(
      rect,
      backgroundPaint,
    );

    canvas.drawRect(
      rect,
      backgroundPaint,
    );

    // Draw cut out
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cutOutRect,
        Radius.circular(borderRadius),
      ),
      boxPaint,
    );

    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cutOutRect,
        Radius.circular(borderRadius),
      ),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
