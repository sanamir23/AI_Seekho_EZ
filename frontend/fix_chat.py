import re

with open('lib/screens/composer/chat_screen.dart', 'r') as f:
    chat_content = f.read()

# Fix the clarification question bug
chat_content = chat_content.replace(
    'final textToShow = data.formattedMessage ?? data.reasoning;',
    'final textToShow = data.formattedMessage ?? data.reasoning ?? data.question;'
)

# Remove the system init message from initState
init_state_pattern = r'''  @override\n  void initState\(\) \{\n    super\.initState\(\);\n    _messages\.add\(\n      ChatMessage\(\n        id: 'system_init',\n        role: MessageRole\.agent,\n        text: 'Assalam-o-Alaikum! Apko konsi service chahiyay\? Type or say it\.',\n      \),\n    \);\n'''
chat_content = re.sub(init_state_pattern, '''  @override
  void initState() {
    super.initState();
''', chat_content)

# We need to add the Animation controller for the halo
class_def_pattern = r'''class _ChatScreenState extends State<ChatScreen> \{'''
class_def_repl = '''class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late AnimationController _haloCtrl;
  late Animation<double> _haloScale;
  
  final _suggestions = const [
    _Suggestion(Icons.ac_unit_rounded, 'AC stopped cooling'),
    _Suggestion(Icons.plumbing_rounded, 'Leaking tap fix'),
    _Suggestion(Icons.bolt_rounded, 'Light fitting'),
    _Suggestion(Icons.cleaning_services_rounded, 'Deep house clean'),
  ];
'''
chat_content = chat_content.replace('class _ChatScreenState extends State<ChatScreen> {', class_def_repl)

init_state_end_repl = '''    _haloCtrl = AnimationController(
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
  }'''
chat_content = chat_content.replace('''    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _textCtrl.text = widget.initialQuery!;
      _sendMessage();
    }
  }''', init_state_end_repl)

dispose_pattern = r'''  @override
  void dispose\(\) \{
    _textCtrl\.dispose\(\);
    _scrollCtrl\.dispose\(\);
    _record\.dispose\(\);
    super\.dispose\(\);
  \}'''
dispose_repl = '''  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _record.dispose();
    _haloCtrl.dispose();
    super.dispose();
  }'''
chat_content = re.sub(dispose_pattern, dispose_repl, chat_content)

# Now inject the _buildHero() and _buildComposerInput() methods
methods_to_add = '''
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
            'How can we assist\\nyou today?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: EzColors.ink,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(
              begin: 0.2, end: 0, delay: 250.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Type, speak, or share a photo.\\nUrdu, English, Roman — sab chalega.',
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
                            color: _isRecording
                                ? EzColors.ink
                                : EzColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording
                                  ? EzColors.ink
                                  : EzColors.border,
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
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 18,
                            color: _isRecording ? EzColors.yellow : EzColors.ink,
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
'''

chat_content = chat_content.replace('  Widget _buildUserBubble(ChatMessage msg) {', methods_to_add + '\\n  Widget _buildUserBubble(ChatMessage msg) {')

# Modify build method to swap between states
build_pattern = r'''            // ── Chat List ──
            Expanded\(
              child: ListView\.builder\('''
build_repl = '''            // ── Chat/Hero Area ──
            Expanded(
              child: _messages.isEmpty
                  ? _buildHero()
                  : ListView.builder('''
chat_content = re.sub(build_pattern, build_repl, chat_content)

input_area_pattern = r'''            // ── Input Area ──
            Container\(
              padding: const EdgeInsets\.fromLTRB\(16, 12, 16, 16\),.*?            \),'''
input_area_repl = '''            // ── Input Area ──
            if (_messages.isEmpty)
              _buildComposerInput()
            else
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: EzColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: EzColors.ink.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: EzColors.cream2,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: EzColors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textCtrl,
                                enabled: !_isSending && !_isRecording,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: EzColors.ink),
                                decoration: InputDecoration(
                                  hintText: _isRecording
                                      ? 'Recording...'
                                      : 'Message EZ Agent...',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                      color: EzColors.muted),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            if (_isRecording)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .fadeIn(duration: 400.ms),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSending
                          ? null
                          : () {
                              if (_textCtrl.text.isNotEmpty) {
                                _sendMessage();
                              } else {
                                _toggleRecording();
                              }
                            },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? Colors.red
                              : EzColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: EzColors.white,
                                  ),
                                )
                              : Icon(
                                  _textCtrl.text.isNotEmpty ? Icons.send_rounded : (_isRecording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded),
                                  color: EzColors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),'''
chat_content = re.sub(input_area_pattern, input_area_repl, chat_content, flags=re.DOTALL)

helpers_to_add = '''
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
'''
chat_content = chat_content + '\\n' + helpers_to_add

with open('lib/screens/composer/chat_screen.dart', 'w') as f:
    f.write(chat_content)
