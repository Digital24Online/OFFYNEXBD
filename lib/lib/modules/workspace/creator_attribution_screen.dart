import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CreatorAttributionScreen extends StatelessWidget {
  const CreatorAttributionScreen({super.key, required this.isBangla});

  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF14233B);
    const muted = Color(0xFF66758B);
    const blue = Color(0xFF1769B5);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(isBangla ? 'নির্মাতা পরিচিতি' : 'Creator'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF082B68), Color(0xFF0877C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: SvgPicture.asset(
                      'assets/branding/offynexbd_icon.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'OFFYNEXBD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'The Future of Office Productivity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD66B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE3EAF3)),
              ),
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/branding/founder_profile.jpg',
                      width: 124,
                      height: 124,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 124,
                        height: 124,
                        alignment: Alignment.center,
                        color: const Color(0xFFE7F0FC),
                        child: const Text(
                          'MD',
                          style: TextStyle(
                            color: blue,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'MD PIYARUL ISLAM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBangla
                        ? 'প্রতিষ্ঠাতা ও মূল নির্মাতা'
                        : 'Founder & Original Creator',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFE8EDF4)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: blue,
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          isBangla ? 'নির্মাতার স্বীকৃতি' : 'Creator Recognition',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isBangla
                        ? 'OFFYNEXBD-এর মূল ধারণা, পরিকল্পনা ও নির্মাণ উদ্যোগের স্রষ্টা MD PIYARUL ISLAM। এই পৃষ্ঠায় অ্যাপটির ঘোষিত প্রতিষ্ঠাতা ও মূল নির্মাতার পরিচয় সংরক্ষিত রয়েছে।'
                        : 'MD PIYARUL ISLAM is the originator of the OFFYNEXBD concept and the initiative behind its planning and development. This page records the app’s declared founder and original creator attribution.',
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                '© 2026 OFFYNEXBD. All Rights Reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
