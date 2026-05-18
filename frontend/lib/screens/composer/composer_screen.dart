import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import '../../core/widgets/wave_bars.dart';
import '../../core/services/api_service.dart';
import '../../core/models/agent_response.dart';
import '../thinking/thinking_screen.dart';

class ComposerScreen extends StatefulWidget {
  const ComposerScreen({super.key});

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _listening = false;
  bool _hasText = false;
  bool _isTranscribing = false;

  late AnimationController _haloCtrl;
  late Animation<double> _haloScale;

  // Clarification state
  String? _conversationId;
  String? _pendingQuestion;

  final _suggestions = const [
    _Suggestion(Icons.ac_unit_rounded, 'AC stopped cooling'),
    _Suggestion(Icons.plumbing_rounded, 'Leaking tap fix'),
    _Suggestion(Icons.bolt_rounded, 'Light fitting'),
    _Suggestion(Icons.cleaning_services_rounded, 'Deep house clean'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.trim().isNotEmpty);
    });

    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _haloScale = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _haloCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Build the future that will call the API
    final Future<AgentRunOut> responseFuture = ApiService.instance
        .sendServiceRequest(
          text: text,
          conversationId: _conversationId,
        );

    // ThinkingScreen pops back with AgentRunOut when status == needs_clarification
    final result = await Navigator.push<AgentRunOut>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ThinkingScreen(
          userText: text,
          responseFuture: responseFuture,
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    // If the agent needs more info, store conversation state for the follow-up
    if (!mounted) return;
    if (result != null && result.status == 'needs_clarification') {
      setState(() {
        _conversationId = result.conversationId;
        _pendingQuestion = result.question;
        _controller.clear();
      });
    }
  }

  Future<void> _onMicTap() async {
    if (_isTranscribing) return;
    // Toggle visual listening state — actual recording via file_picker
    setState(() => _listening = !_listening);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: EzColors.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _CircleBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: EzColors.ink),
                  ),
                  const Spacer(),
                  _CircleBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: EzColors.ink),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ── Center hero ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Animated EZ logo with halo
                    AnimatedBuilder(
                      animation: _haloScale,
                      builder: (_, __) {
                        return SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: _haloScale.value,
                                child: Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        EzColors.yellow.withOpacity(0.55),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: EzColors.yellow.withOpacity(0.4),
                                      width: 1),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: EzColors.yellow.withOpacity(0.25),
                                      width: 1),
                                ),
                              ),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFCD24A),
                                      Color(0xFFFFE988),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EzColors.yellowDeep
                                          .withOpacity(0.35),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Image.asset('assets/images/ez_logo.png',
                                    fit: BoxFit.contain),
                              ),
                              ...[
                                const Offset(-52, -44),
                                const Offset(52, -44),
                                const Offset(-52, 44),
                                const Offset(52, 44),
                              ].asMap().entries.map((e) {
                                return Positioned(
                                  left: 60 + e.value.dx - 3,
                                  top: 60 + e.value.dy - 3,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: e.key % 2 == 0
                                          ? EzColors.ink
                                          : EzColors.yellowDeep,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                            curve: Curves.elasticOut),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 10, color: EzColors.yellowDeep),
                        const SizedBox(width: 4),
                        Text(
                          'EZ AGENT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: EzColors.yellowDeep,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 12),

                    // Pending clarification question banner
                    if (_pendingQuestion != null) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: EzColors.yellowGlow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: EzColors.yellow),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: EzColors.ink,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  size: 13, color: EzColors.yellow),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _pendingQuestion!,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: EzColors.ink,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 12),
                    ],

                    if (_pendingQuestion == null)
                      Text(
                        'How can we assist\nyou today?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: EzColors.ink,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 250.ms, duration: 400.ms)
                          .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 250.ms,
                              duration: 400.ms),

                    const SizedBox(height: 8),

                    Text(
                      'Type, speak, or share a photo.\nUrdu, English, Roman — sab chalega.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: EzColors.inkSoft,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: 22),

                    // Suggestion chips 2×2 (only shown without clarification)
                    if (_pendingQuestion == null)
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.6,
                        children: _suggestions
                            .asMap()
                            .entries
                            .map((e) => _SuggestionChip(
                                  suggestion: e.value,
                                  onTap: () =>
                                      _controller.text = e.value.label,
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: Duration(
                                            milliseconds: 350 + e.key * 60),
                                        duration: 300.ms)
                                    .slideY(
                                        begin: 0.2,
                                        end: 0,
                                        delay: Duration(
                                            milliseconds: 350 + e.key * 60),
                                        duration: 300.ms))
                            .toList(),
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Voice listening strip ──
            if (_listening)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EzColors.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const WaveBars(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Listening… speak now',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: EzColors.white)),
                            Text('Urdu, English, Roman — sab samjhta hai',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: EzColors.white.withOpacity(0.6))),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _listening = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: EzColors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('STOP',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: EzColors.white)),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms).slideY(
                    begin: 0.3, end: 0, duration: 250.ms),
              ),

            // ── Composer box ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 24,
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: EzColors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: EzColors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: EzColors.ink.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: EzColors.ink.withOpacity(0.08),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                          child: TextField(
                            controller: _controller,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: _pendingQuestion != null
                                  ? 'Your reply…'
                                  : 'Apko konsi service chahiyay?',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: EzColors.muted2,
                                  fontWeight: FontWeight.w500),
                              border: InputBorder.none,
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: EzColors.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Tool row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Row(
                            children: [
                              _ToolBtn(icon: Icons.attach_file_rounded),
                              _ToolBtn(icon: Icons.photo_camera_outlined),
                              _ToolBtn(icon: Icons.location_on_outlined),
                              const Spacer(),
                              // Mic
                              GestureDetector(
                                onTap: _onMicTap,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _listening
                                        ? EzColors.ink
                                        : EzColors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _listening
                                          ? EzColors.ink
                                          : EzColors.border,
                                    ),
                                    boxShadow: _listening
                                        ? [
                                            BoxShadow(
                                              color: EzColors.yellow
                                                  .withOpacity(0.35),
                                              blurRadius: 0,
                                              spreadRadius: 4,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: _isTranscribing
                                      ? const Padding(
                                          padding: EdgeInsets.all(9),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: EzColors.yellow),
                                        )
                                      : Icon(
                                          Icons.mic_rounded,
                                          size: 18,
                                          color: _listening
                                              ? EzColors.yellow
                                              : EzColors.ink,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Send
                              GestureDetector(
                                onTap: _hasText ? _submit : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _hasText
                                        ? EzColors.ink
                                        : const Color(0xFFE8E2D2),
                                    shape: BoxShape.circle,
                                    boxShadow: _hasText
                                        ? [
                                            BoxShadow(
                                              color: EzColors.ink
                                                  .withOpacity(0.18),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: _hasText
                                        ? EzColors.yellow
                                        : const Color(0xFFB5AE9E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EZ may suggest local providers. Confirm before booking.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: EzColors.muted,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _CircleBtn({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: EzColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: EzColors.border),
          boxShadow: [
            BoxShadow(
                color: EzColors.ink.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _Suggestion {
  final IconData icon;
  final String label;
  const _Suggestion(this.icon, this.label);
}

class _SuggestionChip extends StatelessWidget {
  final _Suggestion suggestion;
  final VoidCallback onTap;
  const _SuggestionChip(
      {super.key, required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: EzColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EzColors.border),
          boxShadow: [
            BoxShadow(
                color: EzColors.ink.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: EzColors.yellowGlow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(suggestion.icon, size: 13, color: EzColors.ink),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                suggestion.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: EzColors.ink,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  const _ToolBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Icon(icon, size: 18, color: EzColors.inkSoft),
    );
  }
}
