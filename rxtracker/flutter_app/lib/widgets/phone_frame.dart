import 'package:flutter/material.dart';

class PhoneFrame extends StatelessWidget {
  final Widget child;

  const PhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On mobile, just show the app full screen
        if (constraints.maxWidth < 600) {
          return child;
        }

        // On desktop, show the phone frame
        double phoneHeight = constraints.maxHeight * 0.9;
        double phoneWidth = phoneHeight * (9 / 19.5); // Standard smartphone aspect ratio

        return Center(
          child: Container(
            width: phoneWidth,
            height: phoneHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(10, 10),
                ),
              ],
              border: Border.all(
                color: Colors.grey[800]!,
                width: 8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  child,
                  // Top Notch/Speaker area
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 30,
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A1A1A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
