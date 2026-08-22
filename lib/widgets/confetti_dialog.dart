import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class ConfettiDialog extends StatefulWidget {
  final String title;
  final String message;
  final Widget? image;

  const ConfettiDialog({
    Key? key,
    required this.title,
    required this.message,
    this.image,
  }) : super(key: key);

  @override
  State<ConfettiDialog> createState() => _ConfettiDialogState();
}

class _ConfettiDialogState extends State<ConfettiDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade900, Colors.grey.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.amber.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // הצגת התמונה המועברת, או הפוקדור המעוצב והחתוך שלנו
                if (widget.image != null)
                  widget.image!
                else
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.2),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    builder: (context, double scale, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4 * scale),
                              blurRadius: 30 * scale,
                              spreadRadius: 5 * scale,
                            ),
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.2 * scale),
                              blurRadius: 15 * scale,
                              spreadRadius: 2 * scale,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    // חיתוך התמונה לעיגול מושלם שמסיר את הרקע הלבן שמסביב לכדור
                    child: ClipOval(
                      child: Container(
                        color: Colors.white, // רקע לבן פנימי למקרה הצורך
                        padding: const EdgeInsets.all(4), // רווח עדין פנימי
                        child: Image.asset(
                          'assets/icons/pokeball.png',
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.catching_pokemon,
                                color: Colors.redAccent,
                                size: 80,
                              ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 50,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            emissionFrequency: 0.02,
            maxBlastForce: 25,
            minBlastForce: 8,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.amber,
              Colors.redAccent,
            ],
          ),
        ),
      ],
    );
  }
}
