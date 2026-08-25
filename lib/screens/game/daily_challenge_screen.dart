import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/audio_service.dart';
import '../../services/scoring_service.dart';
import '../../utils/responsive.dart';
import 'widgets/skribbl_avatar.dart';
import '../../models/app_user.dart';

enum DailyChallengeState { selecting, loading, playing, revealing, finished }

class DailyChallengeScreen extends ConsumerStatefulWidget {
  final String? initialVibe;
  const DailyChallengeScreen({super.key, this.initialVibe});

  @override
  ConsumerState<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  final _audioService = SongAudioService();
  final _scoring = ScoringService();
  final _guessCtrl = TextEditingController();
  late ConfettiController _confettiCtrl;

  DailyChallengeState _state = DailyChallengeState.selecting;
  String? _selectedVibe;
  List<Song> _songs = [];
  int _currentIndex = 0;
  int _totalScore = 0;
  int _correctCount = 0;
  int _totalTries = 0;
  int _totalTimeMs = 0;
  int _stageSeconds = 2;
  bool _playingAudio = false;
  bool _correctInRound = false;
  
  DateTime? _roundStart;
  DateTime? _challengeStart;
  int _currentRoundSeconds = 0;
  Timer? _roundTimer;
  Timer? _sequenceTimer;
  Timer? _revealTimer;

  // New state variables for the advanced flow
  int _countdownValue = 0;
  String _announcementText = '';
  bool _showCountdown = false;
  bool _replayEnabled = false;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));
    
    // Check for maintenance lockout (11:55 PM to 12:00 AM)
    final now = DateTime.now();
    if (now.hour == 23 && now.minute >= 55) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMaintenanceDialog();
      });
    }

    if (widget.initialVibe != null && ['Bollywood', 'English', 'International'].contains(widget.initialVibe)) {
      _selectedVibe = widget.initialVibe;
      _loadChallenge();
    }
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Arena Maintenance 🛠️', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'We are currently calculating today\'s results and awarding MusCoins! '
          'Daily Challenges will resume at 12:00 AM sharp.'
        ),
        actions: [
          FilledButton(onPressed: () => context.go('/home'), child: const Text('BACK TO HOME')),
        ],
      ),
    );
  }

  void _showVerificationRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verification Required 🔐', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'Only verified players can participate in the Daily Challenge.\n\n'
          'Please verify your Email or Phone number in your Profile to unlock this feature.'
        ),
        actions: [
          FilledButton(
            onPressed: () => context.go('/profile'),
            child: const Text('GO TO PROFILE'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    _guessCtrl.dispose();
    _sequenceTimer?.cancel();
    _revealTimer?.cancel();
    _roundTimer?.cancel();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    if (_selectedVibe == null) return;
    setState(() => _state = DailyChallengeState.loading);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      // Wait a moment for profile to load
      await Future.delayed(const Duration(seconds: 1));
    }
    
    final finalProfile = ref.read(userProfileProvider).valueOrNull;
    final isVerified = finalProfile?.isEmailVerified == true || finalProfile?.isPhoneVerified == true;
    
    if (!isVerified && !user.isAnonymous) {
       if (mounted) {
         _showVerificationRequiredDialog();
       }
       return;
    }

    final service = ref.read(dailyChallengeServiceProvider);
    
    // Check if already attempted
    final attempt = await service.getAttempt(user.uid, _selectedVibe!);
    if (attempt != null && attempt.completed) {
      final challenge = await service.getOrCreateChallenge(_selectedVibe!);
      setState(() {
        _songs = challenge.songs;
        _totalScore = attempt.score;
        _totalTries = attempt.totalTries;
        _totalTimeMs = attempt.totalTimeMs;
        _correctCount = attempt.correctCount;
        _state = DailyChallengeState.finished;
      });
      return;
    }

    final challenge = await service.getOrCreateChallenge(_selectedVibe!);
    
    if (mounted) {
      setState(() {
        _songs = challenge.songs;
        _challengeStart = DateTime.now();
        _state = DailyChallengeState.playing;
        _startRound();
      });
      
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null) {
        await service.startAttempt(
          user.uid,
          profile.displayName,
          profile.photoUrl,
          profile.avatarConfig,
          _selectedVibe!,
        );
      }
    }
  }

  void _startRound() {
    _roundStart = null; // Don't start timer until 2s clip plays
    _stageSeconds = 2;
    _correctInRound = false;
    _currentRoundSeconds = 0;
    _countdownValue = 0;
    _showCountdown = false;
    _replayEnabled = false;
    _announcementText = '';
    _guessCtrl.clear();
    
    _runGameSequence();
  }

  Future<void> _doCountdown(int from, {String msg = ''}) async {
    if (!mounted || _correctInRound) return;
    setState(() {
      _showCountdown = true;
      _announcementText = msg;
      _countdownValue = from;
    });
    
    for (int i = from; i >= 1; i--) {
      if (!mounted || _correctInRound) return;
      setState(() => _countdownValue = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (mounted) setState(() => _showCountdown = false);
  }

  Future<void> _runGameSequence() async {
    if (!mounted || _correctInRound) return;

    // 1. Initial Countdown
    await _doCountdown(3, msg: 'Get ready...');
    if (_correctInRound) return;
    
    // 2. Play 2s clip & start total time timer
    _roundStart = DateTime.now();
    _startRoundTimer();
    _stageSeconds = 2;
    await _loadAndPlayClip(2);
    
    // 3. 10s Window (7s Replay, 3s Next Clip Countdown)
    await _handleClipWindow(duration: 2, nextSeconds: 3, windowSeconds: 7);
    if (_correctInRound) return;

    // 4. 3s Clip
    _stageSeconds = 3;
    await _loadAndPlayClip(3);
    await _handleClipWindow(duration: 3, nextSeconds: 5, windowSeconds: 7);
    if (_correctInRound) return;

    // 5. 5s Clip
    _stageSeconds = 5;
    await _loadAndPlayClip(5);
    // 10s Replay window for 5s stage
    setState(() => _replayEnabled = true);
    for (int i = 0; i < 10; i++) {
       await Future.delayed(const Duration(seconds: 1));
       if (_correctInRound) return;
    }
    setState(() => _replayEnabled = false);
    await _doCountdown(3, msg: 'Playing 8 sec clip in');
    if (_correctInRound) return;

    // 6. 8s Clip
    _stageSeconds = 8;
    await _loadAndPlayClip(8);
    
    // 7. 15s Replay Window
    setState(() => _replayEnabled = true);
    for (int i = 0; i < 15; i++) {
       await Future.delayed(const Duration(seconds: 1));
       if (_correctInRound) return;
    }
    setState(() => _replayEnabled = false);

    // 8. Reveal
    await _doCountdown(3, msg: 'Song reveal in');
    if (_correctInRound) return;
    _revealSong();
  }

  Future<void> _handleClipWindow({required int duration, required int nextSeconds, required int windowSeconds}) async {
    if (!mounted || _correctInRound) return;
    
    // Enable replay for windowSeconds (e.g. 7s)
    setState(() => _replayEnabled = true);
    for (int i = 0; i < windowSeconds; i++) {
       await Future.delayed(const Duration(seconds: 1));
       if (_correctInRound) return;
    }
    setState(() => _replayEnabled = false);
    
    // Last 3s countdown
    await _doCountdown(3, msg: 'Playing $nextSeconds sec clip in');
  }

  void _startRoundTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _state != DailyChallengeState.playing || _correctInRound) {
        timer.cancel();
        return;
      }
      setState(() => _currentRoundSeconds++);
    });
  }

  Future<void> _loadAndPlayClip(int seconds) async {
    if (_songs.isEmpty || _correctInRound) return;
    final song = _songs[_currentIndex];
    setState(() => _playingAudio = true);
    await _audioService.loadSong(song.audioUrl, silenceOffset: song.silenceOffset);
    await _audioService.playClip(seconds);
    if (mounted) setState(() => _playingAudio = false);
  }

  void _submitGuess() {
    if (_state != DailyChallengeState.playing || _correctInRound) return;
    final guess = _guessCtrl.text.trim();
    if (guess.isEmpty) return;

    _totalTries++;
    final song = _songs[_currentIndex];
    final isCorrect = _scoring.isCorrectGuess(guess: guess, title: song.title, artist: '');

    if (isCorrect) {
      _sequenceTimer?.cancel();
      _roundTimer?.cancel();
      _confettiCtrl.play();
      
      final now = DateTime.now();
      final elapsed = _roundStart != null ? now.difference(_roundStart!).inMilliseconds : 10000;
      
      final points = _scoring.calculatePoints(
        revealedSeconds: _stageSeconds,
        elapsedMs: elapsed,
        isFirstCorrect: true, 
        songDifficulty: song.difficulty,
      );

      setState(() {
        _correctInRound = true;
        _correctCount++;
        _totalScore += points;
      });

      _revealSong();
    } else {
      _guessCtrl.clear();
    }
  }

  Future<void> _revealSong() async {
    _sequenceTimer?.cancel();
    _roundTimer?.cancel();
    setState(() {
      _state = DailyChallengeState.revealing;
      _showCountdown = false;
      _replayEnabled = false;
    });
    
    await _audioService.setVolume(0.5);
    _audioService.playClip(30);

    // Wait 10s total on reveal screen
    // Last 3s show countdown for next song
    await Future.delayed(const Duration(seconds: 7));
    if (mounted && _currentIndex < _songs.length - 1) {
      await _doCountdown(3, msg: 'Get ready for next song in');
    } else {
      await Future.delayed(const Duration(seconds: 3));
    }
    
    _nextRound();
  }

  void _nextRound() {
    _revealTimer?.cancel();
    _audioService.stopClip();
    _audioService.setVolume(1.0);

    if (_currentIndex < _songs.length - 1) {
      setState(() {
        _currentIndex++;
        _state = DailyChallengeState.playing;
        _startRound();
      });
    } else {
      _finishChallenge();
    }
  }

  Future<void> _finishChallenge() async {
    setState(() => _state = DailyChallengeState.finished);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    _totalTimeMs = _challengeStart != null ? now.difference(_challengeStart!).inMilliseconds : 0;

    try {
      await ref.read(dailyChallengeServiceProvider).completeAttempt(
        user.uid,
        _selectedVibe!,
        _totalScore,
        _correctCount,
        _totalTimeMs,
        _totalTries,
      );
      debugPrint('Challenge completed and recorded for ${user.uid}');
    } catch (e) {
      debugPrint('Error recording challenge result: $e');
    }
  }

  Future<void> _launchSpotify(String trackId) async {
    final song = _songs[_currentIndex];
    final query = Uri.encodeComponent('${song.title} ${song.artist} Spotify');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _state == DailyChallengeState.selecting || _state == DailyChallengeState.finished;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quit Challenge?', style: TextStyle(fontWeight: FontWeight.w900)),
            content: const Text(
              'If you leave now, you won\'t be able to take on this challenge today again. '
              'You will have to wait till tomorrow for the next one. Count your attempt?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('CONFIRM & QUIT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldLeave == true && mounted) {
          await _finishChallenge();
          if (mounted) GoRouter.of(context).go('/home');
        }
      },
      child: Stack(
        children: [
          PageShell(
            showHeader: true,
            child: Column(
              children: [
                // Compact Header Row
                Row(
                  children: [
                    NeubrutalistButton(
                      label: '← BACK',
                      color: Colors.white,
                      onPressed: () {
                        if (canPop) {
                          context.go('/home');
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                    ),
                    const Spacer(),
                    if (_state == DailyChallengeState.selecting && ref.watch(isDevProvider))
                      TextButton(
                        onPressed: () async {
                          await ref.read(dailyChallengeServiceProvider).clearTodayAttempts();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attempts cleared!')));
                          }
                        },
                        child: const Text('RESET ATTEMPTS (DEV)', style: TextStyle(fontSize: 10, color: Colors.black26)),
                      ),
                  ],
                ),
                const Gap(16),
                _buildBody(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case DailyChallengeState.selecting:
        return _buildSelection();
      case DailyChallengeState.loading:
        return const Center(child: CircularProgressIndicator());
      case DailyChallengeState.playing:
        return _buildPlaying();
      case DailyChallengeState.revealing:
        return _buildRevealing();
      case DailyChallengeState.finished:
        return _buildFinished();
    }
  }

  Widget _buildSelection() {
    return Column(
      children: [
        Text('Daily Challenges', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: context.ff(24, max: 32), fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.displayLarge?.color), textAlign: TextAlign.center),
        const Gap(8),
        Text('Bollywood • English • International', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor)),
        const Gap(4),
        Text('One attempt per day for each category. Aim for the Top 20!', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
        const Gap(24),
        _VibeSelectCard(
          label: 'Bollywood', icon: '🇮🇳', color: const Color(0xFFFFFF00), textColor: Colors.black,
          onTap: () { setState(() => _selectedVibe = 'Bollywood'); _loadChallenge(); },
        ),
        const Gap(16),
        _VibeSelectCard(
          label: 'English', icon: '🇺🇸', color: const Color(0xFF00FF00), textColor: Colors.black,
          onTap: () { setState(() => _selectedVibe = 'English'); _loadChallenge(); },
        ),
        const Gap(16),
        _VibeSelectCard(
          label: 'International', icon: '🌎', color: const Color(0xFF4D4DFF), textColor: Colors.white,
          onTap: () { setState(() => _selectedVibe = 'International'); _loadChallenge(); },
        ),
      ],
    );
  }

  Widget _buildPlaying() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderProgress(currentIndex: _currentIndex, vibe: _selectedVibe!, score: _totalScore, tries: _totalTries, seconds: _currentRoundSeconds),
        const Gap(24),
        NeubrutalistContainer(
          padding: const EdgeInsets.all(32),
          useEntryAnimation: true,
          child: Column(
            children: [
              if (_showCountdown)
                Column(
                  children: [
                    Text(_announcementText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const Gap(8),
                    Text('$_countdownValue', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 64, color: Color(0xFF0001BB)))
                        .animate(key: ValueKey(_countdownValue)).scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
                  ],
                )
              else ...[
                const Icon(Icons.music_note, size: 64, color: Color(0xFF0001BB)).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: const Duration(milliseconds: 1200), color: Colors.white24).shake(hz: 2, curve: Curves.easeInOut),
                const Gap(24),
                NeubrutalistButton(
                  label: _playingAudio ? 'PLAYING...' : 'REPLAY ${_stageSeconds}s CLIP',
                  color: const Color(0xFF0001BB),
                  textColor: Colors.white,
                  onPressed: (_playingAudio || !_replayEnabled) ? null : () => _loadAndPlayClip(_stageSeconds),
                ),
                const Gap(12),
                Text('Stage: ${_stageSeconds}s', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).hintColor)),
              ],
            ],
          ),
        ),
        const Gap(24),
        NeubrutalistContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _guessCtrl, 
                  onSubmitted: (_) => _submitGuess(), 
                  autofocus: true, 
                  style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'Type song title...', 
                    hintStyle: TextStyle(color: Theme.of(context).hintColor),
                    border: InputBorder.none, 
                    enabledBorder: InputBorder.none, 
                    focusedBorder: InputBorder.none
                  )
                )
              ),
              NeubrutalistButton(label: 'SUBMIT', color: const Color(0xFF00FF00), onPressed: _submitGuess),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevealing() {
    final song = _songs[_currentIndex];
    return Column(
      children: [
        _HeaderProgress(currentIndex: _currentIndex, vibe: _selectedVibe!, score: _totalScore, tries: _totalTries, seconds: 0),
        const Gap(24),
        if (_showCountdown)
           Padding(
             padding: const EdgeInsets.only(bottom: 24),
             child: Column(
               children: [
                 Text(_announcementText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF00FF00))),
                 const Gap(4),
                 Text('$_countdownValue', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Color(0xFF00FF00))),
               ],
             ),
           ),
        NeubrutalistContainer(
          color: _correctInRound ? const Color(0xFF00FF00) : const Color(0xFF720100),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shadowOffset: 0,
          child: Center(child: Text(_correctInRound ? 'WELL DONE!' : 'NOT QUITE!', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18))),
        ).animate().scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut, duration: const Duration(milliseconds: 600)),
        const Gap(12),
        NeubrutalistContainer(
          padding: const EdgeInsets.all(24),
          useEntryAnimation: true,
          child: Column(
            children: [
              Container(width: 180, height: 180, decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 3), borderRadius: BorderRadius.circular(4), image: DecorationImage(image: NetworkImage(song.albumArtUrl), fit: BoxFit.cover))).animate().fadeIn(delay: const Duration(milliseconds: 200)).slideY(begin: 0.2),
              const Gap(24),
              Text(song.title, style: TextStyle(fontSize: context.ff(20, max: 24), fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color), textAlign: TextAlign.center).animate().fadeIn(delay: const Duration(milliseconds: 400)),
              Text(song.artist, style: TextStyle(fontSize: context.ff(14, max: 18), fontWeight: FontWeight.w700, color: Theme.of(context).hintColor), textAlign: TextAlign.center).animate().fadeIn(delay: const Duration(milliseconds: 500)),
              const Gap(24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                MouseRegion(cursor: SystemMouseCursors.click, child: OutlinedButton.icon(onPressed: () => _launchSpotify(song.id), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('LISTEN ON SPOTIFY'), style: OutlinedButton.styleFrom(side: BorderSide(color: Theme.of(context).dividerColor, width: 2), foregroundColor: Theme.of(context).textTheme.bodyLarge?.color, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))))),
              ]).animate().fadeIn(delay: const Duration(milliseconds: 600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    return Column(
      children: [
        NeubrutalistContainer(
          color: const Color(0xFFFFFF00),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text('CHALLENGE COMPLETE!', style: TextStyle(fontSize: context.ff(22, max: 28), fontWeight: FontWeight.w900, color: Colors.black)),
              const Gap(16),
              Text('Category: $_selectedVibe', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
              const Gap(32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ResultStat(label: 'CORRECT', value: '$_correctCount/5'),
                  _ResultStat(label: 'TOTAL TRIES', value: '$_totalTries'),
                  _ResultStat(label: 'TOTAL TIME', value: _formatTime(_totalTimeMs)),
                ],
              ),
            ],
          ),
        ),
        const Gap(32),
        AdaptiveRow(
          collapseBelow: 800,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Leaderboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const Gap(16),
                Consumer(
                  builder: (context, ref, _) {
                    final leaderboard = ref.watch(dailyLeaderboardProvider(_selectedVibe!));
                    final user = ref.watch(currentUserProvider);
                    return leaderboard.when(
                      data: (attempts) {
                        final userRank = attempts.indexWhere((a) => a.userId == user?.uid);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (userRank != -1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: NeubrutalistContainer(color: const Color(0xFF00FF00), padding: const EdgeInsets.all(12), child: Text('YOUR LIVE RANKING: #${userRank + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black))),
                              ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attempts.length,
                              itemBuilder: (context, i) {
                                final a = attempts[i];
                                final isMe = a.userId == user?.uid;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: NeubrutalistContainer(
                                    color: isMe ? const Color(0xFFFFFF00) : (i < 20 ? Theme.of(context).cardColor.withOpacity(0.5) : Theme.of(context).cardColor),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shadowOffset: 2,
                                    child: Row(
                                      children: [
                                        Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                        const Gap(12),
                                        Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)), child: Center(child: SkribblAvatar(config: AvatarConfig.fromMap(a.avatarConfig), size: 20))),
                                        const Gap(10),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isMe ? 'YOU' : a.displayName, style: TextStyle(fontWeight: FontWeight.w800, color: isMe ? Colors.black : Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis), Text('${a.correctCount}/5 correct · ${a.totalTries} tries · ${_formatTime(a.totalTimeMs)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isMe ? Colors.black54 : Theme.of(context).hintColor))])),
                                        Text('${a.score}', style: TextStyle(fontWeight: FontWeight.w900, color: isMe ? Colors.black : Theme.of(context).primaryColor)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => const Center(child: Text('Error loading.')),
                    );
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Songs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const Gap(16),
                ..._songs.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeubrutalistContainer(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), image: DecorationImage(image: NetworkImage(s.albumArtUrl), fit: BoxFit.cover))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis), Text(s.artist, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Theme.of(context).hintColor), overflow: TextOverflow.ellipsis)])),
                      ],
                    ),
                  ),
                )).toList(),
              ],
            ),
          ],
        ),
        const Gap(40),
        NeubrutalistButton(label: 'BACK TO ARENA', color: Theme.of(context).primaryColor, textColor: Colors.white, onPressed: () => context.go('/home')),
        const Gap(40),
      ],
    );
  }

  String _formatTime(int ms) {
    final s = ms ~/ 1000;
    final min = s ~/ 60;
    final sec = s % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _VibeSelectCard extends StatefulWidget {
  final String label;
  final String icon;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;
  const _VibeSelectCard({required this.label, required this.icon, required this.color, this.textColor, required this.onTap});
  @override
  State<_VibeSelectCard> createState() => _VibeSelectCardState();
}

class _VibeSelectCardState extends State<_VibeSelectCard> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovering ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          child: NeubrutalistContainer(color: widget.color, padding: const EdgeInsets.all(24), child: Row(children: [Text(widget.icon, style: const TextStyle(fontSize: 32)), const SizedBox(width: 24), Text(widget.label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: widget.textColor ?? Colors.black)), const Spacer(), Icon(Icons.arrow_forward_ios, color: widget.textColor ?? Colors.black)])),
        ),
      ),
    );
  }
}

class _HeaderProgress extends StatelessWidget {
  final int currentIndex;
  final String vibe;
  final int score;
  final int tries;
  final int seconds;
  const _HeaderProgress({required this.currentIndex, required this.vibe, required this.score, required this.tries, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return NeubrutalistContainer(
      color: const Color(0xFFFFFF00),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Challenge: $vibe', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)), Text('Song ${currentIndex + 1} / 5', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black54))]),
          _Stat(label: 'SCORE', value: '$score', isBlack: true),
          _Stat(label: 'TRIES', value: '$tries', isBlack: true),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('TIME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Colors.black54)), Text('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF720100)))]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool isBlack;
  const _Stat({required this.label, required this.value, this.isBlack = false});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: isBlack ? Colors.black54 : Theme.of(context).hintColor)), Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isBlack ? Colors.black : Theme.of(context).textTheme.bodyLarge?.color))]);
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  const _ResultStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54))]);
  }
}
