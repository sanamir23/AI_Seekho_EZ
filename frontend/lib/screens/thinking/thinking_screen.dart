import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ez_colors.dart';
import '../../core/widgets/wave_bars.dart';
import '../../core/models/agent_response.dart';
import '../results/results_screen.dart';
import '../home/home_screen.dart';

class ThinkingScreen extends StatefulWidget {
  final String userText;
  final Future<AgentRunOut> responseFuture;

  const ThinkingScreen({
    super.key,
    required this.userText,
    required this.responseFuture,
  });

  @override
  State<ThinkingScreen> createState() => _ThinkingScreenState();
}

class _ThinkingScreenState extends State<ThinkingScreen>
    with TickerProviderStateMixin {
  // ── Animated UI steps (decorative progress while waiting) ──────
  int _active = 0;
  final List<int> _done = [];

  // ── Backend node → UI label mapping ─────────────────────────────────
  static const _nodeLabels = {
    'intent_parser':      ('Understanding request',   Icons.psychology_rounded,    'Parsing your service need…'),
    'provider_caller':    ('Scanning providers',      Icons.radar_rounded,          'Searching verified pros in your area…'),
    'tool_executor':      ('Searching database',      Icons.manage_search_rounded,  'Querying provider database…'),
    'ranking':            ('Ranking & filtering',     Icons.star_rounded,           'Filtering top-rated providers…'),
    'decision':           ('Picking best match',      Icons.emoji_events_rounded,   'Selecting the best fit for you…'),
    'response_formatter': ('Preparing response',      Icons.auto_awesome_rounded,   'Crafting your result…'),
    'booking_step':       ('Confirming booking',      Icons.calendar_today_rounded, 'Securing your appointment…'),
    'followup_step':      ('Setting reminder',        Icons.notifications_rounded,  'Scheduling follow-up alert…'),
    'clarifier':          ('Checking details',        Icons.quiz_rounded,           'Clarifying your request…'),
    'inquiry_formatter':  ('Preparing info',          Icons.info_outline_rounded,   'Formatting provider information…'),
    'no_results_handler': ('Checking nearby coverage', Icons.travel_explore_rounded, 'Looking for useful alternatives…'),
    'decision_and_format': ('Preparing response',     Icons.auto_awesome_rounded,   'Crafting your result…'),
    'cancel_handler':     ('Cancelling booking',      Icons.cancel_outlined,        'Updating your appointment…'),
    'reschedule_handler': ('Rescheduling booking',    Icons.event_repeat_rounded,   'Applying the new time…'),
    'give_up':            ('Stopping safely',         Icons.info_outline_rounded,   'Waiting for clearer details…'),
  };

  // ── Fallback static steps shown while waiting for backend ────────────
  static const _fallbackSteps = [
    _Step('understand', Icons.psychology_rounded, 'Understanding request',
        'Parsing your service need…'),
    _Step('scan', Icons.radar_rounded, 'Scanning nearby providers',
        'Searching verified pros in your area…'),
    _Step('rate', Icons.star_rounded, 'Checking ratings & reviews',
        'Filtering top-rated providers…'),
    _Step('price', Icons.attach_money_rounded, 'Comparing prices',
        'Analysing price ranges…'),
    _Step('avail', Icons.calendar_today_rounded, 'Checking availability',
        'Matching your preferred time slot…'),
    _Step('pick', Icons.emoji_events_rounded, 'Shortlisting top matches',
        'Picking the best fits for you…'),
  ];

  List<_Step> _steps = List.from(_ThinkingScreenState._fallbackSteps);

  @override
  void initState() {
    super.initState();
    _advanceUI();
    _awaitApi();
  }

  void _advanceUI() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _done.add(_active);
        if (_active < _steps.length - 1) {
          _active++;
          _advanceUI();
        }
      });
    });
  }

  void _awaitApi() {
    widget.responseFuture.then((result) {
      if (!mounted) return;

      if (result.thinkingSteps != null && result.thinkingSteps!.isNotEmpty) {
        setState(() {
          _steps = result.thinkingSteps!
              .map((step) => _Step(
                    step.key,
                    _nodeLabels[step.key]?.$2 ?? Icons.auto_awesome_rounded,
                    step.title,
                    step.detail,
                  ))
              .toList();
          _done.clear();
          _done.addAll(List.generate(_steps.length, (i) => i));
          _active = _steps.length - 1;
        });
      } else
      // ── Sync timeline steps from backend trace_steps ──────────────────
      if (result.traceSteps != null && result.traceSteps!.isNotEmpty) {
        final backendSteps = result.traceSteps!
            .map((t) {
              final node = t['node']?.toString() ?? '';
              final label = _nodeLabels[node];
              if (label == null) return null;
              return _Step(node, label.$2, label.$1, label.$3);
            })
            .whereType<_Step>()
            .toList();

        if (backendSteps.isNotEmpty) {
          setState(() {
            _steps = backendSteps;
            _done.clear();
            // Mark all steps as done since backend already finished
            _done.addAll(List.generate(_steps.length, (i) => i));
            _active = _steps.length - 1;
          });
        } else {
          // No recognized nodes — just mark all fallback steps done
          setState(() {
            _done.addAll(
              List.generate(_steps.length, (i) => i)
                  .where((i) => !_done.contains(i)),
            );
            _active = _steps.length - 1;
          });
        }
      } else {
        // No trace_steps — mark all fallback steps done
        setState(() {
          _done.addAll(
            List.generate(_steps.length, (i) => i)
                .where((i) => !_done.contains(i)),
          );
          _active = _steps.length - 1;
        });
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _navigate(result);
      });
    }).catchError((e) {
      if (!mounted) return;
      _showError(e.toString());
    });
  }

  void _navigate(AgentRunOut result) {
    if (result.status == 'completed') {
      // completed: always go to ResultsScreen (handles null selectedProvider too)
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => ResultsScreen(agentResult: result),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else if (result.status == 'needs_clarification') {
      // Pop back to composer with conversation state
      Navigator.pop(context, result);
    } else {
      // Abandoned or unknown — go home with message
      _showError(result.reason ?? 'EZ could not find a match. Please try again.');
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: EzColors.white,
        title: Text('Something went wrong',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: EzColors.ink)),
        content: Text(msg,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: EzColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (r) => false,
              );
            },
            child: Text('Go Home',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: EzColors.ink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final progress = _done.length / _steps.length;

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: EzColors.yellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset('assets/images/ez_logo.png',
                        fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EZ Agent',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: EzColors.ink)),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: EzColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: EzColors.success.withOpacity(0.3),
                                    spreadRadius: 3),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('Thinking live',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: EzColors.muted,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: EzColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: EzColors.border),
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          size: 15, color: EzColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            // ── Query echo ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Text('You said',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: EzColors.muted,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: EzColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EzColors.border),
                    ),
                    child: Text(
                      '"${widget.userText}"',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: EzColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            // ── Reasoning label ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 2),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: EzColors.yellowDeep),
                      const SizedBox(width: 6),
                      Text('REASONING',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: EzColors.yellowDeep,
                              letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ShimmerText(
                    text: 'Thinking through your request…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: EzColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),

            // ── Timeline ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Stack(
                  children: [
                    Positioned(
                      left: 17,
                      top: 18,
                      bottom: 18,
                      width: 2,
                      child: Container(
                          decoration: BoxDecoration(
                        color: EzColors.border,
                        borderRadius: BorderRadius.circular(2),
                      )),
                    ),
                    Positioned(
                      left: 17,
                      top: 18,
                      width: 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        height: progress * 320,
                        decoration: BoxDecoration(
                          color: EzColors.ink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Column(
                      children: _steps.asMap().entries.map((e) {
                        final i = e.key;
                        final s = e.value;
                        final isDone = _done.contains(i);
                        final isActive = !isDone && i == _active;
                        final isPending = !isDone && i != _active;
                        return _TimelineStep(
                          step: s,
                          isDone: isDone,
                          isActive: isActive,
                          isPending: isPending,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: EzColors.ink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const WaveBars(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Finding the best match…',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: EzColors.white)),
                          Text(
                              '~ ${(_steps.length - _done.length).clamp(1, _steps.length)} sec remaining',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: EzColors.white.withOpacity(0.6))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: EzColors.yellow.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: EzColors.yellow.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_done.length.toString().padLeft(2, '0')}/${_steps.length}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: EzColors.yellow),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step widget ─────────────────────────────────────────────

class _TimelineStep extends StatelessWidget {
  final _Step step;
  final bool isDone;
  final bool isActive;
  final bool isPending;

  const _TimelineStep({
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    final filled = isDone || isActive;

    return AnimatedOpacity(
      opacity: isPending ? 0.35 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: filled ? EzColors.yellow : EzColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: filled ? EzColors.yellow : EzColors.border,
                  width: 2,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: EzColors.yellow.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Icon(
                  isDone ? Icons.check_rounded : step.icon,
                  size: 18,
                  color: EzColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                decoration: BoxDecoration(
                  color: filled ? EzColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: filled ? EzColors.yellow : EzColors.border,
                  ),
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: EzColors.yellow.withOpacity(0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isPending ? EzColors.muted : EzColors.ink,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (isActive) ...[
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: EzColors.yellowDeep,
                              shape: BoxShape.circle,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .fadeIn(duration: 900.ms)
                              .then()
                              .fadeOut(duration: 900.ms),
                          const SizedBox(width: 4),
                          Text('RUNNING',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: EzColors.yellowDeep,
                              )),
                        ],
                        if (isDone) ...[
                          const Icon(Icons.check_rounded,
                              size: 10, color: EzColors.yellowDeep),
                          const SizedBox(width: 3),
                          Text('DONE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: EzColors.yellowDeep,
                              )),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.sub,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: EzColors.muted,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 6),
                      _ShimmerBar(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      )
          .animate(key: ValueKey('step_$isDone$isActive'))
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.15, end: 0, duration: 350.ms),
    );
  }
}

class _Step {
  final String key;
  final IconData icon;
  final String title;
  final String sub;
  const _Step(this.key, this.icon, this.title, this.sub);
}

// ─── Shimmer bar ──────────────────────────────────────────────

class _ShimmerBar extends StatefulWidget {
  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: const [
                Colors.transparent,
                EzColors.yellow,
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}

// ─── Shimmer text ─────────────────────────────────────────────

class _ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _ShimmerText({required this.text, required this.style});

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              stops: [
                (_ctrl.value - 0.15).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.15).clamp(0.0, 1.0),
              ],
              colors: [
                EzColors.inkSoft,
                EzColors.yellowDeep,
                EzColors.inkSoft,
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: widget.style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}
