import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/ez_colors.dart';
import '../../core/models/agent_response.dart';
import '../../core/services/api_service.dart';
import '../results/results_screen.dart';
import '../confirm/confirm_screen.dart';
import '../shell/app_shell.dart';

enum MessageRole { user, agent }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String? text;
  final String? audioPath;
  final bool isThinking;
  final AgentRunOut? agentData;

  ChatMessage({
    required this.id,
    required this.role,
    this.text,
    this.audioPath,
    this.isThinking = false,
    this.agentData,
  });
}

class ChatScreen extends StatefulWidget {
  final String? initialQuery;

  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late AnimationController _haloCtrl;
  late Animation<double> _haloScale;

  final _suggestions = const [
    _Suggestion(Icons.ac_unit_rounded, 'AC stopped cooling'),
    _Suggestion(Icons.plumbing_rounded, 'Leaking tap fix'),
    _Suggestion(Icons.bolt_rounded, 'Light fitting'),
    _Suggestion(Icons.cleaning_services_rounded, 'Deep house clean'),
  ];

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _record = AudioRecorder();

  bool _isRecording = false;
  bool _isSending = false;
  String? _conversationId;

  final List<ChatMessage> _messages = [];
  bool get _isHeroPhase => _messages.isEmpty;

  @override
  void initState() {
    super.initState();

    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _haloScale = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut),
    );

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textCtrl.text = widget.initialQuery!;
        _sendMessage();
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _record.dispose();
    _haloCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _textCtrl.text).trim();
    if (text.isEmpty || _isSending) return;

    _textCtrl.clear();

    final userMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _messages
          .add(ChatMessage(id: userMsgId, role: MessageRole.user, text: text));
      _isSending = true;
      _messages.add(ChatMessage(
        id: '${userMsgId}_think',
        role: MessageRole.agent,
        isThinking: true,
      ));
    });
    _scrollToBottom();

    try {
      final response = await ApiService.instance.sendServiceRequest(
        text: text,
        conversationId: _conversationId,
      );

      _conversationId = response.conversationId;

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == '${userMsgId}_think');
          _messages.add(ChatMessage(
            id: '${userMsgId}_resp',
            role: MessageRole.agent,
            agentData: response,
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[EZ] _sendMessage error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == '${userMsgId}_think');
          _messages.add(ChatMessage(
            id: '${userMsgId}_error',
            role: MessageRole.agent,
            text: e.toString().contains('ApiException')
                ? e.toString().replaceAll(RegExp(r'ApiException\(\d+\): '), '')
                : 'Sorry, something went wrong. Please try again.',
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _record.stop();
        setState(() => _isRecording = false);
        if (path != null) {
          try {
            setState(() => _isSending = true);
            final transcribed =
                await ApiService.instance.transcribeAudio(File(path));
            if (mounted && transcribed.isNotEmpty) {
              _textCtrl.text = transcribed;
              _textCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: transcribed.length));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transcription ready — review and tap send'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Transcription failed: $e')),
              );
            }
          } finally {
            if (mounted) setState(() => _isSending = false);
          }
        }
      } else {
        final hasPerm = await _record.hasPermission();
        if (!hasPerm) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Microphone Permission'),
                content: const Text(
                    'EZ needs mic access. Please enable it in Settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _record.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('[EZ] Recording error: $e');
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  if (canPop)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                        child: const Center(
                          child: Icon(Icons.arrow_back_rounded,
                              size: 18, color: EzColors.ink),
                        ),
                      ),
                    ),
                  if (canPop) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EZ Agent',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
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
                                      spreadRadius: 2),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text('Online & ready',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: EzColors.muted,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_messages.isNotEmpty)
                    GestureDetector(
                      onTap: _startNewChat,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: EzColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: EzColors.border),
                        ),
                        child: const Center(
                          child: Icon(Icons.edit_rounded,
                              size: 16, color: EzColors.ink),
                        ),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Chat list
            Expanded(
              child: _isHeroPhase
                  ? _buildHero()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        if (msg.role == MessageRole.user) {
                          return _buildUserBubble(msg);
                        } else {
                          return _buildAgentBubble(msg);
                        }
                      },
                    ),
            ),

            // Input area
            _buildComposerInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
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
                            color: EzColors.yellow.withOpacity(0.4), width: 1),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: EzColors.yellow.withOpacity(0.25), width: 1),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFCD24A), Color(0xFFFFE988)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: EzColors.yellowDeep.withOpacity(0.35),
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
          ).animate().fadeIn(duration: 500.ms).scale(
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
              .slideY(begin: 0.2, end: 0, delay: 250.ms, duration: 400.ms),
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
                      onTap: () => _sendMessage(e.value.label),
                    )
                        .animate()
                        .fadeIn(
                            delay: Duration(milliseconds: 350 + e.key * 60),
                            duration: 300.ms)
                        .slideY(
                            begin: 0.2,
                            end: 0,
                            delay: Duration(milliseconds: 350 + e.key * 60),
                            duration: 300.ms))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildComposerInput() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 20,
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
                    controller: _textCtrl,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Apko konsi service chahiyay?',
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
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      _ToolBtn(icon: Icons.attach_file_rounded),
                      _ToolBtn(icon: Icons.photo_camera_outlined),
                      _ToolBtn(icon: Icons.location_on_outlined),
                      const Spacer(),
                      GestureDetector(
                        onTap: _toggleRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isRecording ? EzColors.ink : EzColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  _isRecording ? EzColors.ink : EzColors.border,
                            ),
                            boxShadow: _isRecording
                                ? [
                                    BoxShadow(
                                      color: EzColors.yellow.withOpacity(0.35),
                                      blurRadius: 0,
                                      spreadRadius: 4,
                                    )
                                  ]
                                : [],
                          ),
                          child: Icon(
                            _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            size: 18,
                            color:
                                _isRecording ? EzColors.yellow : EzColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _textCtrl,
                        builder: (context, value, child) {
                          final hasText = value.text.trim().isNotEmpty;
                          return GestureDetector(
                            onTap: hasText && !_isSending ? _sendMessage : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: hasText
                                    ? EzColors.ink
                                    : const Color(0xFFE8E2D2),
                                shape: BoxShape.circle,
                                boxShadow: hasText
                                    ? [
                                        BoxShadow(
                                          color: EzColors.ink.withOpacity(0.18),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: _isSending
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: EzColors.white,
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: hasText
                                          ? EzColors.yellow
                                          : const Color(0xFFB5AE9E),
                                    ),
                            ),
                          );
                        },
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
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: EzColors.ink,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: msg.audioPath != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic_rounded,
                            color: EzColors.yellow, size: 16),
                        const SizedBox(width: 8),
                        Text('Voice Message',
                            style: GoogleFonts.plusJakartaSans(
                                color: EzColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    )
                  : Text(
                      msg.text ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        color: EzColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1, end: 0, duration: 300.ms),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _fmtService(String s) => s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
      .join(' ');

  static String _fmtSlotTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final min =
          dt.minute == 0 ? '' : ':${dt.minute.toString().padLeft(2, '0')}';
      return '${months[dt.month - 1]} ${dt.day}, $h$min $ampm';
    } catch (_) {
      return iso;
    }
  }

  static IconData _thinkingIcon(String key) {
    switch (key) {
      case 'intent_parser':
        return Icons.psychology_rounded;
      case 'provider_caller':
      case 'tool_executor':
        return Icons.search_rounded;
      case 'ranking':
        return Icons.star_rounded;
      case 'slot_picker':
      case 'booking_step':
        return Icons.calendar_today_rounded;
      case 'followup_step':
        return Icons.notifications_rounded;
      case 'clarifier':
        return Icons.quiz_rounded;
      case 'no_results_handler':
        return Icons.travel_explore_rounded;
      case 'cancel_handler':
        return Icons.cancel_outlined;
      case 'reschedule_handler':
        return Icons.event_repeat_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  static List<Map<String, dynamic>> _thinkingStepMaps(
      List<ThinkingStep> steps) {
    return steps
        .map((step) => {
              'icon': _thinkingIcon(step.key),
              'node': step.key,
              'title': step.title,
              'sub': step.detail,
              'status': step.status,
              if (step.ms != null) 'ms': step.ms,
            })
        .toList();
  }

  // Derive thinking steps from last known agent state + latest user message
  List<Map<String, dynamic>> _getDynamicSteps() {
    AgentRunOut? lastData;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == MessageRole.agent && !m.isThinking && m.agentData != null) {
        lastData = m.agentData;
        break;
      }
    }

    // Also peek at the latest user message to pick up service/area hints
    String latestUserText = '';
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == MessageRole.user && m.text != null) {
        latestUserText = m.text!.toLowerCase();
        break;
      }
    }

    return buildDynamicThinkingStepsForAgent(
      lastData: lastData,
      latestUserText: latestUserText,
    );
  }

  Widget _buildThinkingTimeline() {
    return _ThinkingTimeline(
      steps: _getDynamicSteps(),
      progressLabel: _getProgressLabel(),
    );
  }

  String _getProgressLabel() {
    final lastData = _messages.reversed
        .where((m) =>
            m.role == MessageRole.agent && !m.isThinking && m.agentData != null)
        .map((m) => m.agentData!)
        .firstOrNull;
    final pi = lastData?.partialIntent ?? lastData?.intent;
    if (pi?.serviceType != null &&
        pi?.area != null &&
        pi?.scheduledAt != null) {
      return 'Booking your ${_fmtService(pi!.serviceType!)}...';
    }
    if (pi?.serviceType != null && pi?.area != null) {
      return 'Finding ${_fmtService(pi!.serviceType!)}s in ${pi.area}...';
    }
    if (pi?.serviceType != null) {
      return 'Looking for ${_fmtService(pi!.serviceType!)}s nearby...';
    }
    return 'Finding the best match...';
  }

  Widget _buildAgentBubble(ChatMessage msg) {
    if (msg.isThinking) return _buildThinkingTimeline();

    final content = <Widget>[];

    if (msg.text != null) {
      content.add(_agentText(msg.text!));
    }

    if (msg.agentData != null) {
      final data = msg.agentData!;

      // ── "What I understood" chips (clarification rounds) ──
      if (data.status == 'needs_clarification' && data.partialIntent != null) {
        final pi = data.partialIntent!;
        final chips = <String>[];
        if (pi.serviceType != null)
          chips.add('✓ ${_fmtService(pi.serviceType!)}');
        if (pi.area != null) chips.add('✓ ${pi.area}');
        if (pi.scheduledAt != null)
          chips.add('✓ ${_fmtSlotTime(pi.scheduledAt!)}');
        if (chips.isNotEmpty) {
          content.add(Wrap(
            spacing: 6,
            runSpacing: 4,
            children: chips
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: EzColors.yellowGlow,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: EzColors.yellow, width: 1),
                      ),
                      child: Text(c,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: EzColors.ink)),
                    ))
                .toList(),
          ));
          content.add(const SizedBox(height: 8));
        }
      }

      // Message / clarification question
      final textToShow =
          data.formattedMessage ?? data.reasoning ?? data.question;
      if (textToShow != null && textToShow.isNotEmpty) {
        content.add(_agentText(textToShow));
      }

      // ── Availability slots (cards) ──
      if (data.freeSlots != null && data.freeSlots!.isNotEmpty) {
        content.add(const SizedBox(height: 14));
        content.add(
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 12, color: EzColors.yellowDeep),
              const SizedBox(width: 5),
              Text('Available slots',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: EzColors.inkSoft,
                      letterSpacing: 0.3)),
            ],
          ),
        );
        content.add(const SizedBox(height: 8));
        content.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: data.freeSlots!.map((slot) {
                return GestureDetector(
                  onTap: () => _sendMessage(slot.label),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: EzColors.yellowGlow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EzColors.yellow, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: EzColors.yellowDeep.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 11, color: EzColors.yellowDeep),
                            const SizedBox(width: 4),
                            Text(slot.label,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: EzColors.ink)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Tap to select',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                color: EzColors.muted,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }

      // ── Suggestion / quick-reply chips ──
      if (data.suggestions != null && data.suggestions!.isNotEmpty) {
        // For completed status, suggestions are nav actions (View bookings etc)
        // For needs_clarification, they are quick answers to type
        final isNavSuggestions = data.status == 'completed';
        content.add(const SizedBox(height: 12));
        content.add(Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.suggestions!
              .map((s) => GestureDetector(
                    onTap: () {
                      if (isNavSuggestions &&
                          s.toLowerCase().contains('booking')) {
                        AppShell.of(context)?.switchTo(1);
                      } else {
                        _sendMessage(s);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: isNavSuggestions
                                ? EzColors.border
                                : EzColors.yellow),
                      ),
                      child: Text(s,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: EzColors.ink)),
                    ),
                  ))
              .toList(),
        ));
      }

      // ── Selected Provider card ──
      if (data.selectedProvider != null) {
        content.add(const SizedBox(height: 16));
        final p = data.selectedProvider!;

        String slotText = 'Confirmed';
        if (data.booking != null) {
          try {
            final dt = DateTime.parse(data.booking!.scheduledAt).toLocal();
            const months = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ];
            final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final ampm = dt.hour < 12 ? 'AM' : 'PM';
            final min = dt.minute.toString().padLeft(2, '0');
            slotText = '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
          } catch (_) {
            slotText = data.booking!.scheduledAt;
          }
        }

        content.add(ProviderCard(
          rank: 1,
          name: p.name,
          shop: p.category
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
              .join(' '),
          rating: p.rating ?? 4.5,
          distance: p.distanceKm != null
              ? '${p.distanceKm!.toStringAsFixed(1)} km'
              : (p.area ?? ''),
          price: '',
          slot: slotText,
          reasons: ['AI Matched', 'Top Rated', 'Verified'],
          accent: const Color(0xFFFCD24A),
          isAiPick: true,
          onBook: () {
            _conversationId = null;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConfirmScreen(
                  provider: p,
                  booking: data.booking,
                ),
              ),
            );
          },
        ));
      }

      // ── Alternatives ──
      if (data.alternatives != null && data.alternatives!.isNotEmpty) {
        content.add(const SizedBox(height: 16));
        content.add(
          Row(
            children: [
              const Icon(Icons.list_alt_rounded,
                  size: 12, color: EzColors.muted),
              const SizedBox(width: 5),
              Text('Other Options',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: EzColors.muted,
                      letterSpacing: 0.3)),
            ],
          ),
        );
        content.add(const SizedBox(height: 8));

        for (int i = 0; i < data.alternatives!.length; i++) {
          final alt = data.alternatives![i];
          content.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ProviderCard(
              rank: i + 2,
              name: alt.name,
              shop: alt.category
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w.isNotEmpty
                      ? '${w[0].toUpperCase()}${w.substring(1)}'
                      : w)
                  .join(' '),
              rating: alt.rating ?? 4.5,
              distance: alt.distanceKm != null
                  ? '${alt.distanceKm!.toStringAsFixed(1)} km'
                  : (alt.area ?? ''),
              price: '',
              slot: 'Available today',
              reasons: ['Verified', if (alt.score != null) 'Ranked #${i + 2}'],
              accent: const Color(0xFFF4EFE2),
              isAiPick: false,
              onBook: () {
                _conversationId = null;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmScreen(
                      provider: alt,
                      booking: null,
                    ),
                  ),
                );
              },
            ),
          ));
        }
      }

      // ── Agent reasoning trace (collapsible) ──
      final safeThinkingSteps = data.thinkingSteps != null
          ? _thinkingStepMaps(data.thinkingSteps!)
          : null;
      if (data.status == 'completed' &&
          ((safeThinkingSteps != null && safeThinkingSteps.isNotEmpty) ||
              (data.traceSteps != null && data.traceSteps!.isNotEmpty))) {
        content.add(const SizedBox(height: 12));
        content.add(
            _AgentTraceSection(steps: safeThinkingSteps ?? data.traceSteps!));
      }

      // ── Abandoned / no provider ──
      if (data.status == 'abandoned' &&
          data.selectedProvider == null &&
          data.formattedMessage == null) {
        content.add(const SizedBox(height: 8));
        content.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: EzColors.cream2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EzColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: EzColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.reason ??
                      'No provider found for your request. Please try again.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: EzColors.inkSoft,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ));
      }
    }

    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: EzColors.yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child:
                Image.asset('assets/images/ez_logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: EzColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              ),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1, end: 0, duration: 300.ms),
    );
  }

  Widget _agentText(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: EzColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
}

// ── Collapsible agent reasoning trace ────────────────────────────────────────
@visibleForTesting
List<Map<String, dynamic>> buildDynamicThinkingStepsForAgent({
  required AgentRunOut? lastData,
  required String latestUserText,
}) {
  if (lastData?.thinkingSteps != null && lastData!.thinkingSteps!.isNotEmpty) {
    return _ChatScreenState._thinkingStepMaps(lastData.thinkingSteps!);
  }

  final text = latestUserText.toLowerCase();
  final intent = lastData?.partialIntent ?? lastData?.intent;
  final serviceLabel = _inferServiceLabel(text) ??
      (intent?.serviceType != null
          ? _ChatScreenState._fmtService(intent!.serviceType!)
          : null);
  final areaLabel = _inferAreaLabel(text) ?? intent?.area;
  final hasService = serviceLabel != null ||
      RegExp(r'plumb|electr|ac\b|technician|beautician|tutor|clean')
          .hasMatch(text);
  final hasArea = areaLabel != null;
  final hasTime = intent?.scheduledAt != null ||
      RegExp(r'\b(today|tomorrow|kal|aaj|\d{1,2}\s*(am|pm|baje))\b')
          .hasMatch(text);

  if (lastData == null || (!hasService && !hasArea)) {
    return [
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'Reading your request',
        'sub': 'Figuring out what you need',
      },
      {
        'icon': Icons.search_rounded,
        'title': 'Scanning Islamabad',
        'sub': 'Looking for nearby providers',
      },
      {
        'icon': Icons.star_rounded,
        'title': 'Ranking by quality',
        'sub': 'Rating, distance & availability',
      },
    ];
  }
  if (hasService && hasArea && hasTime) {
    return [
      {
        'icon': Icons.verified_rounded,
        'title': 'All details confirmed',
        'sub': '$serviceLabel - $areaLabel',
      },
      {
        'icon': Icons.calendar_today_rounded,
        'title': 'Checking provider',
        'sub': 'Confirming availability',
      },
      {
        'icon': Icons.bookmark_add_rounded,
        'title': 'Creating booking',
        'sub': 'Almost there!',
      },
    ];
  }
  if (hasService && hasArea) {
    return [
      {
        'icon': Icons.location_on_rounded,
        'title': 'Got your area',
        'sub': areaLabel,
      },
      {
        'icon': Icons.search_rounded,
        'title': 'Finding ${serviceLabel}s',
        'sub': 'Searching nearby',
      },
      {
        'icon': Icons.calendar_today_rounded,
        'title': 'Checking free slots',
        'sub': 'Matching your schedule',
      },
    ];
  }
  if (hasService) {
    final svc = serviceLabel ?? 'Provider';
    return [
      {
        'icon': Icons.check_rounded,
        'title': 'Got it - $svc',
        'sub': 'Now finding your area',
      },
      {
        'icon': Icons.search_rounded,
        'title': 'Searching providers',
        'sub': 'Scanning Islamabad',
      },
    ];
  }
  return [
    {
      'icon': Icons.auto_awesome_rounded,
      'title': 'Processing your reply',
      'sub': 'Updating search context',
    },
    {
      'icon': Icons.search_rounded,
      'title': 'Finding best match',
      'sub': 'Almost there',
    },
  ];
}

String? _inferServiceLabel(String text) {
  if (RegExp(r'plumb|tap|pipe|leak').hasMatch(text)) return 'Plumber';
  if (RegExp(r'electr|light|switch|wiring').hasMatch(text)) {
    return 'Electrician';
  }
  if (RegExp(r'\bac\b|air\s*condition|cooling').hasMatch(text)) {
    return 'AC Technician';
  }
  if (RegExp(r'beautician|salon|makeup').hasMatch(text)) return 'Beautician';
  if (RegExp(r'tutor|teacher|study').hasMatch(text)) return 'Tutor';
  if (RegExp(r'clean|deep\s*house').hasMatch(text)) return 'Cleaner';
  if (RegExp(r'technician|provider').hasMatch(text)) return 'Provider';
  return null;
}

String? _inferAreaLabel(String text) {
  final match = RegExp(r'\b([a-i])-?\s*(\d{1,2})\b', caseSensitive: false)
      .firstMatch(text);
  if (match == null) return null;
  return '${match.group(1)!.toUpperCase()}-${match.group(2)}';
}

class _AgentTraceSection extends StatefulWidget {
  final List<Map<String, dynamic>> steps;
  const _AgentTraceSection({required this.steps});

  @override
  State<_AgentTraceSection> createState() => _AgentTraceSectionState();
}

class _AgentTraceSectionState extends State<_AgentTraceSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: EzColors.cream2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: EzColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.auto_awesome_rounded,
                  size: 13,
                  color: EzColors.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  _expanded ? 'Hide agent steps' : 'How I got here',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: EzColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          ...widget.steps.map((step) {
            final node = step['node'] as String? ?? '';
            final title = step['title'] as String? ?? node;
            final ms = step['ms'] as num?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      color: EzColors.yellowDeep,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      ms != null ? '$title  ${ms.round()}ms' : title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: EzColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Progressive thinking timeline ────────────────────────────────────────────
class _ThinkingTimeline extends StatefulWidget {
  final List<Map<String, dynamic>> steps;
  final String progressLabel;
  const _ThinkingTimeline({required this.steps, required this.progressLabel});

  @override
  State<_ThinkingTimeline> createState() => _ThinkingTimelineState();
}

class _ThinkingTimelineState extends State<_ThinkingTimeline> {
  int _activeStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted && _activeStep < widget.steps.length - 1) {
        setState(() => _activeStep++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('+ WORKING',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: EzColors.yellowDeep,
                      letterSpacing: 1.2))
              .animate()
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: EzColors.ink,
                  height: 1.2),
              children: [
                const TextSpan(text: 'Thinking through '),
                TextSpan(
                    text: 'your request',
                    style: const TextStyle(color: EzColors.muted)),
                const TextSpan(text: '...'),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isDone = i < _activeStep;
            final isActive = i == _activeStep;
            final stepDelay = Duration(milliseconds: 150 + i * 200);

            Color iconBg;
            Color iconColor;
            Color borderColor;
            if (isDone) {
              iconBg = const Color(0xFFD4F0DC);
              iconColor = const Color(0xFF2E7D4F);
              borderColor = const Color(0xFF7BC89A);
            } else if (isActive) {
              iconBg = EzColors.yellow;
              iconColor = EzColors.ink;
              borderColor = EzColors.yellowDeep;
            } else {
              iconBg = EzColors.cream2;
              iconColor = EzColors.muted;
              borderColor = EzColors.border;
            }

            return Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 40,
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Color(0xFF2E7D4F))
                            : Icon(step['icon'] as IconData,
                                size: 16, color: iconColor),
                      ),
                      if (i < steps.length - 1)
                        Container(width: 2, height: 28, color: EzColors.border),
                    ])),
                const SizedBox(width: 10),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step['title'] as String,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: (isDone || isActive)
                                    ? EzColors.ink
                                    : EzColors.muted)),
                        const SizedBox(height: 2),
                        Text(step['sub'] as String,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: EzColors.muted,
                                fontWeight: FontWeight.w500)),
                      ]),
                )),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: EzColors.yellowGlow,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('NOW',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: EzColors.yellowDeep)),
                  ),
              ]),
            ]).animate().fadeIn(delay: stepDelay, duration: 350.ms).slideX(
                begin: -0.04, end: 0, delay: stepDelay, duration: 350.ms);
          }),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: EzColors.ink, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: EzColors.yellow)),
              const SizedBox(width: 10),
              Text(widget.progressLabel,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: EzColors.white)),
            ]),
          ).animate().fadeIn(
              delay: const Duration(milliseconds: 1200), duration: 400.ms),
        ],
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
