import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
           title: "Invalid Ticket", // Use helper
           message: "Ticket ID not found in system.",
           isSuccess: false,
        );
        return;
      }

      // 🔐 SECURITY CHECK: Does this ticket belong to the logged-in Agent?
      // Assuming 'hostelOwnerId' or similar field exists, OR we check if the Agent ID matches the hostel ID logic.
      // Based on typical schema: agent.uid == booking.agentId (or similar)
      
      final data = foundDoc.data() as Map<String, dynamic>;
      final String? bookingAgentId = data['agentId']; // Ensure this field exists in your Booking model
      final String currentAgentId = FirebaseAuth.instance.currentUser?.uid ?? "";

      if (bookingAgentId != currentAgentId) {
         _showResultDialog(
           title: "Wrong Hostel",
           message: "This ticket does not belong to your hostel.\n\nTicket belongs to agent: ${bookingAgentId ?? 'Unknown'}",
           isSuccess: false,
           data: data,
         );
         return;
      }

      final status = data['status'] ?? 'UNKNOWN';
      final userName = data['userName'] ?? 'Unknown Student';
      final hostelName = data['hostelName'] ?? 'Unknown Hostel';
      final studentSex = data['studentSex'] ?? 'N/A';
      
      // Check Payment & Status
      if (status == 'CHECKED_IN') {
         _showResultDialog(
           title: "Already Checked In",
           message: "$userName is already checked in.",
           isSuccess: true,
           data: data,
           customIcon: Icons.verified_user, // New param
         );
      } else if (status == 'PAID') {
         _showResultDialog(
           title: "Valid Ticket", 
           message: "Payment Confirmed. Ready for Check-In.",
           isSuccess: true,
           data: data, // Pass Data
           showCheckInButton: true, // New logic control
           onConfirm: () async {
             // Mark as Checked In
             await foundDoc!.reference.update({'status': 'CHECKED_IN'});
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student Checked In Successfully!"), backgroundColor: Colors.green));
             }
           }
         );
      } else if (status == 'CONFIRMED') {
        _showResultDialog(
          title: "Payment Pending",
          message: "Student has not paid yet.",
          isSuccess: false,
          data: data,
        );
      } else {
        _showResultDialog(
          title: "Invalid Status",
          message: "Current Status: $status",
          isSuccess: false,
          data: data,
        );
      }

    } catch (e) {
      _showResultDialog(title: "Error", message: e.toString(), isSuccess: false);
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onConfirm,
    Map<String, dynamic>? data,
    bool showCheckInButton = false,
    IconData? customIcon,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Result",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Container(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(anim1.value),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.transparent,
            child: SingleChildScrollView(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Header with Icon
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      color: isSuccess ? const Color(0xFF00C853) : const Color(0xFFD32F2F),
                      child: Column(
                        children: [
                          Icon(
                            customIcon ?? (isSuccess ? Icons.check_circle_outline : Icons.error_outline),
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSuccess ? (showCheckInButton ? "Payment Verified" : "Success") : "Attention",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 2. Content Body
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                             message,
                             textAlign: TextAlign.center,
                             style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          
                          // Richer Details Section
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!)
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(Icons.person, "Student", data?['userName'] ?? 'N/A'),
                                const Divider(),
                                _buildInfoRow(Icons.wc, "Gender", data?['studentSex'] ?? 'N/A'),
                                const Divider(),
                                _buildInfoRow(Icons.hotel, "Hostel", data?['hostelName'] ?? 'N/A'),
                                const Divider(),
                                _buildInfoRow(Icons.payment, "Status", data?['status'] ?? 'N/A', 
                                  color: isSuccess ? Colors.green : Colors.red),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() => _isProcessing = false);
                                controller.start();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey[300]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text("Close", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (showCheckInButton && onConfirm != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  onConfirm();
                                  Navigator.pop(context);
                                  setState(() => _isProcessing = false);
                                  controller.start();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E2AB7), // Primary Brand Color
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text("CHECK IN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: color ?? Colors.black87,
                fontSize: 14
              ),
            ),
          ),
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
          const ScannerOverlay(borderColor: Colors.blue, cutOutSize: 300),
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

// Creative Scanner Overlay with Animation
class ScannerOverlay extends StatefulWidget {
  final Color borderColor;
  final double cutOutSize;

  const ScannerOverlay({super.key, required this.borderColor, required this.cutOutSize});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ScannerOverlayPainter(
            borderColor: widget.borderColor,
            cutOutSize: widget.cutOutSize,
            scanValue: _controller.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double cutOutSize;
  final double scanValue;

  ScannerOverlayPainter({required this.borderColor, required this.cutOutSize, required this.scanValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutOutRect = Rect.fromCenter(center: rect.center, width: cutOutSize, height: cutOutSize);

    // 1. Background (Darkened with hole)
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.6);
    final bgPath = Path()..fillType = PathFillType.evenOdd;
    bgPath.addRect(rect);
    bgPath.addRRect(RRect.fromRectAndRadius(cutOutRect, const Radius.circular(20)));
    canvas.drawPath(bgPath, bgPaint);

    // 2. Corners
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 // Thinner
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    const r = 20.0; // Corner radius matching cutOut

    final path = Path();
    // Top Left
    path.moveTo(cutOutRect.left, cutOutRect.top + cornerLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + r);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.top, cutOutRect.left + r, cutOutRect.top);
    path.lineTo(cutOutRect.left + cornerLength, cutOutRect.top);

    // Top Right
    path.moveTo(cutOutRect.right - cornerLength, cutOutRect.top);
    path.lineTo(cutOutRect.right - r, cutOutRect.top);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.top, cutOutRect.right, cutOutRect.top + r);
    path.lineTo(cutOutRect.right, cutOutRect.top + cornerLength);

    // Bottom Right
    path.moveTo(cutOutRect.right, cutOutRect.bottom - cornerLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - r);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, cutOutRect.right - r, cutOutRect.bottom);
    path.lineTo(cutOutRect.right - cornerLength, cutOutRect.bottom);

    // Bottom Left
    path.moveTo(cutOutRect.left + cornerLength, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + r, cutOutRect.bottom);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, cutOutRect.left, cutOutRect.bottom - r);
    path.lineTo(cutOutRect.left, cutOutRect.bottom - cornerLength);

    canvas.drawPath(path, borderPaint);

    // 3. Scanning Line (Creative part)
    final scanY = cutOutRect.top + (cutOutRect.height * scanValue);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [borderColor.withOpacity(0), borderColor, borderColor.withOpacity(0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cutOutRect.left, scanY, cutOutRect.width, 4));
    
    canvas.drawRect(Rect.fromLTWH(cutOutRect.left + 10, scanY, cutOutRect.width - 20, 2), linePaint);
    
    // Glow Effect
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [borderColor.withOpacity(0.3), borderColor.withOpacity(0)],
      ).createShader(Rect.fromLTWH(cutOutRect.left, scanY, cutOutRect.width, 20));

    canvas.drawRect(Rect.fromLTWH(cutOutRect.left + 10, scanY, cutOutRect.width - 20, 30), glowPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) => oldDelegate.scanValue != scanValue;
}
