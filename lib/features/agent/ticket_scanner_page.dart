import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

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
        _verifyTicket(barcode.rawValue!);
        break; 
      }
    }
  }

  Future<void> _verifyTicket(String rawData) async {
    setState(() => _isProcessing = true);
    controller.stop();

    try {
      String bookingId = rawData;
      
      // 1. Secure Parse: STAYHUB|ID|REF
      if (rawData.startsWith("STAYHUB|")) {
        final parts = rawData.split("|");
        if (parts.length >= 2) bookingId = parts[1];
      } else if (rawData.contains("/")) {
        // Prevent path traversal attacks or format errors
        throw Exception("Invalid Security Format");
      }

      // 2. Direct Document Fetch
      final docRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
      final docSnap = await docRef.get();
      
      if (!docSnap.exists) {
        _showResultDialog(
           title: "Invalid Ticket",
           message: "This ticket (ID: $bookingId) does not exist in our secure database.",
           isSuccess: false,
        );
        return;
      }

      final data = docSnap.data() as Map<String, dynamic>;
      final String? bookingAgentId = data['agentId'];
      final String currentAgentId = FirebaseAuth.instance.currentUser?.uid ?? "";

      // 3. Security check: Must be the owner or authorized agent
      if (bookingAgentId != currentAgentId) {
         _showResultDialog(
           title: "Unauthorized Access",
           message: "This ticket belongs to a different hostel operator.",
           isSuccess: false,
           data: data,
         );
         return;
      }

      final status = data['status'] ?? 'UNKNOWN';
      final userName = data['userName'] ?? 'Student';
      
      // 4. Verification Flow
      if (status == 'CHECKED_IN') {
         _showResultDialog(
           title: "Already Used",
           message: "$userName has already used this ticket for check-in.",
           isSuccess: true,
           data: data,
           customIcon: Icons.verified_user,
         );
      } else if (status == 'PAID') {
         _showResultDialog(
           title: "Verified Ticket", 
           message: "Payment confirmed. Proceed with physical check-in.",
           isSuccess: true,
           data: data,
           showCheckInButton: true,
           onConfirm: () async {
             // Atomic update to prevent double entry
             await docRef.update({
               'status': 'CHECKED_IN',
               'checkInDate': FieldValue.serverTimestamp(),
             });
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Student Checked In Successfully!"), backgroundColor: Colors.green)
               );
             }
           }
         );
      } else {
         _showResultDialog(
           title: "Payment Unverified",
           message: "This booking is currently: $status. Entry is denied.",
           isSuccess: false,
           data: data,
         );
      }

    } catch (e) {
      debugPrint("Scanner Error: $e");
      _showResultDialog(
        title: "Scan Error", 
        message: "Unable to process ticket. ${e.toString().contains('Invalid Security Format') ? 'Invalid QR code.' : 'System error.'}", 
        isSuccess: false
      );
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
                            isSuccess ? (showCheckInButton ? "Payment Verified" : "Valid Status") : "Attention Required",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[200]!)
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(Icons.person_rounded, "Student", data?['userName'] ?? 'N/A'),
                                const Divider(height: 24),
                                _buildInfoRow(Icons.hotel_rounded, "Hostel", data?['hostelName'] ?? 'N/A'),
                                const Divider(height: 24),
                                _buildInfoRow(Icons.payment_rounded, "Status", data?['status'] ?? 'N/A', 
                                  color: isSuccess ? Colors.green[700] : Colors.red[700]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                              child: Text("CANCEL", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
                                  backgroundColor: const Color(0xFF2E2AB7),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 8,
                                  shadowColor: const Color(0xFF2E2AB7).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text("CHECK IN", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13, letterSpacing: 1.2)),
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (color ?? Colors.grey[400])!.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(
          value, 
          style: TextStyle(fontWeight: FontWeight.w800, color: color ?? Colors.black87, fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Ticket Verification", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleDetection,
          ),
          const ScannerOverlay(borderColor: Colors.blue, cutOutSize: 280),
          Positioned(
             bottom: 80,
             left: 40,
             right: 40,
             child: ClipRRect(
               borderRadius: BorderRadius.circular(30),
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                   decoration: BoxDecoration(
                     color: Colors.black.withOpacity(0.5),
                     borderRadius: BorderRadius.circular(30),
                     border: Border.all(color: Colors.white10),
                   ),
                   child: const Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                       SizedBox(width: 12),
                       Text("Scan Student's Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                     ],
                   ),
                 ),
               ),
             ),
          )
        ],
      ),
    );
  }
}

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

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.7);
    final bgPath = Path()..fillType = PathFillType.evenOdd;
    bgPath.addRect(rect);
    bgPath.addRRect(RRect.fromRectAndRadius(cutOutRect, const Radius.circular(30)));
    canvas.drawPath(bgPath, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const cornerLength = 40.0;
    const r = 30.0;

    final path = Path();
    path.moveTo(cutOutRect.left, cutOutRect.top + cornerLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + r);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.top, cutOutRect.left + r, cutOutRect.top);
    path.lineTo(cutOutRect.left + cornerLength, cutOutRect.top);

    path.moveTo(cutOutRect.right - cornerLength, cutOutRect.top);
    path.lineTo(cutOutRect.right - r, cutOutRect.top);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.top, cutOutRect.right, cutOutRect.top + r);
    path.lineTo(cutOutRect.right, cutOutRect.top + cornerLength);

    path.moveTo(cutOutRect.right, cutOutRect.bottom - cornerLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - r);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, cutOutRect.right - r, cutOutRect.bottom);
    path.lineTo(cutOutRect.right - cornerLength, cutOutRect.bottom);

    path.moveTo(cutOutRect.left + cornerLength, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + r, cutOutRect.bottom);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, cutOutRect.left, cutOutRect.bottom - r);
    path.lineTo(cutOutRect.left, cutOutRect.bottom - cornerLength);

    canvas.drawPath(path, borderPaint);

    final scanY = cutOutRect.top + (cutOutRect.height * scanValue);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue.withOpacity(0), Colors.blue, Colors.blue.withOpacity(0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cutOutRect.left, scanY, cutOutRect.width, 4));
    
    canvas.drawRect(Rect.fromLTWH(cutOutRect.left + 20, scanY, cutOutRect.width - 40, 2), linePaint);
    
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0)],
      ).createShader(Rect.fromLTWH(cutOutRect.left, scanY, cutOutRect.width, 40));

    canvas.drawRect(Rect.fromLTWH(cutOutRect.left + 20, scanY, cutOutRect.width - 40, 40), glowPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) => oldDelegate.scanValue != scanValue;
}
