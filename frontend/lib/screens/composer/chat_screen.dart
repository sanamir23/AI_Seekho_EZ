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
      _textCtrl.text = widget.initialQuery!;
      _sendMessage();
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
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final query = text;
    _textCtrl.clear();

    final userMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _messages.add(ChatMessage(
        id: userMsgId,
        role: MessageRole.user,
        text: query,
      ));
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
        text: query,
        conversationId: _conversationId,
      );

      // Store conversation_id for follow-ups
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
          // Transcribe and populate text field (don't auto-send)
          try {
            setState(() => _isSending = true);
            final transcribed = await ApiService.instance.transcribeAudio(File(path));
            if (mounted && transcribed.isNotEmpty) {
              _textCtrl.text = transcribed;
              _textCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: transcribed.length),
              );
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
                  'EZ needs mic access to transcribe your voice. '
                  'Please enable it in Settings.',
                ),
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
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // â”€â”€ Header â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
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
                  const SizedBox(width: 12),
                  Column(
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
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // â”€â”€ Chat List â”€â”€
            Expanded(
              child: _isHeroPhase
                  ? _buildHero()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

            // â”€â”€ Input Area â”€â”€
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
                          colors: [
                            Color(0xFFFCD24A),
                            Color(0xFFFFE988),
                          ],
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
                      onTap: () {
                        _textCtrl.text = e.value.label;
                        _sendMessage();
                      },
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

  Widget _buildThinkingTimeline() {
    const steps = [
      {'icon': Icons.auto_awesome_rounded, 'title': 'Understanding request', 'sub': 'Parsing your message...'},
      {'icon': Icons.radar_rounded, 'title': 'Scanning nearby providers', 'sub': 'Searching within 5 km'},
      {'icon': Icons.star_rounded, 'title': 'Checking ratings & reviews', 'sub': 'Filtered to 4.5\u2605 and above'},
      {'icon': Icons.monetization_on_outlined, 'title': 'Comparing prices', 'sub': 'Finding best value'},
      {'icon': Icons.calendar_today_rounded, 'title': 'Checking availability', 'sub': 'Matching your schedule'},
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('+ REASONING',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: EzColors.yellowDeep, letterSpacing: 1.2))
              .animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: EzColors.ink, height: 1.2),
              children: [
                const TextSpan(text: 'Thinking through '),
                TextSpan(text: 'your request', style: TextStyle(color: EzColors.muted)),
                const TextSpan(text: '...'),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isFirst = i == 0;
            return Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 40, child: Column(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: isFirst ? EzColors.yellow : EzColors.cream2,
                      shape: BoxShape.circle,
                      border: Border.all(color: isFirst ? EzColors.yellowDeep : EzColors.border, width: 1.5),
                    ),
                    child: Icon(step['icon'] as IconData, size: 16,
                        color: isFirst ? EzColors.ink : EzColors.muted),
                  ),
                  if (i < steps.length - 1) Container(width: 2, height: 28, color: EzColors.border),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(step['title'] as String, style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: isFirst ? EzColors.ink : EzColors.muted)),
                    const SizedBox(height: 2),
                    Text(step['sub'] as String, style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: EzColors.muted, fontWeight: FontWeight.w500)),
                  ]),
                )),
                if (isFirst) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: EzColors.yellowGlow, borderRadius: BorderRadius.circular(6)),
                  child: Text('RUNNING', style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w800, color: EzColors.yellowDeep)),
                ),
              ]),
            ]).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 400), duration: 400.ms)
                .slideX(begin: -0.05, end: 0);
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: EzColors.ink, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: EzColors.yellow)),
              const SizedBox(width: 10),
              Text('Finding the best match...', style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: EzColors.white)),
            ]),
          ).animate().fadeIn(delay: 2200.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildAgentBubble(ChatMessage msg) {
    if (msg.isThinking) {
      return _buildThinkingTimeline();
    }

    // Determine the content to show based on AgentRunOut or raw text
    final content = <Widget>[];

    if (msg.text != null) {
      content.add(Text(
        msg.text!,
        style: GoogleFonts.plusJakartaSans(
          color: EzColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ));
    }

    if (msg.agentData != null) {
      final data = msg.agentData!;

      // AI Insight / Reasoning or Clarification
      final textToShow =
          data.formattedMessage ?? data.reasoning ?? data.question;
      if (textToShow != null && textToShow.isNotEmpty) {
        content.add(Text(
          textToShow,
          style: GoogleFonts.plusJakartaSans(
            color: EzColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ));
      }

      if (data.status == 'needs_clarification' && data.suggestions != null) {
        content.add(const SizedBox(height: 12));
        content.add(Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.suggestions!
              .map((s) => GestureDetector(
                    onTap: () {
                      _textCtrl.text = s;
                      _sendMessage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: EzColors.yellow),
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

      // Selected Provider
      if (data.selectedProvider != null) {
        content.add(const SizedBox(height: 16));
        final p = data.selectedProvider!;

        String slotText = 'Confirmed';
        if (data.booking != null) {
          try {
            final dt = DateTime.parse(data.booking!.scheduledAt).toLocal();
            final months = [
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
          shop: 'Provider',
          rating: p.rating ?? 4.5,
          distance: p.distanceKm != null
              ? '${p.distanceKm!.toStringAsFixed(1)} km'
              : (p.area ?? ''),
          price: '',
          slot: slotText,
          reasons:
              data.suggestions?.take(3).toList() ?? ['AI Matched', 'Verified'],
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

      // Alternatives
      if (data.alternatives != null && data.alternatives!.isNotEmpty) {
        content.add(const SizedBox(height: 12));
        content.add(Text('Other Options',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: EzColors.muted,
            )));
        content.add(const SizedBox(height: 8));

        for (final alt in data.alternatives!) {
          content.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ProviderCard(
              rank: 2,
              name: alt.name,
              shop: 'Provider',
              rating: alt.rating ?? 4.5,
              distance: alt.distanceKm != null
                  ? '${alt.distanceKm!.toStringAsFixed(1)} km'
                  : (alt.area ?? ''),
              price: '',
              slot: 'Available today',
              reasons: ['Verified'],
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
    }

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
