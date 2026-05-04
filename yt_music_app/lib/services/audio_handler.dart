import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  final equalizer = AndroidEqualizer();
  final loudnessEnhancer = AndroidLoudnessEnhancer();

  // สร้าง Player พร้อมตั้งค่าให้โหลด Buffer เพลงเก็บไว้ล่วงหน้าเยอะๆ (5-10 นาที) เพื่อไม่ให้เพลงหยุดกลางคัน
  late final AudioPlayer _player;

  // ใช้ ConcatenatingAudioSource เพื่อระบบ Gapless Playback
  final _playlist = ConcatenatingAudioSource(children: []);
  Timer? _positionTimer;
  Timer? _loadingWatchdog;
  Timer? _changingSongTimeout; // auto-reset _isChangingSong
  bool _isChangingSong = false;
  static const int _maxQueueSize = 200; // จำกัดขนาด queue

  MyAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [equalizer, loudnessEnhancer],
      ),
      audioLoadConfiguration: AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: const Duration(seconds: 30),
          maxBufferDuration: const Duration(minutes: 2),
          bufferForPlaybackDuration: const Duration(seconds: 1),
          bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 2),
          targetBufferBytes: 1024 * 1024 * 10, // 10MB — ลดจาก 30MB เพื่อประหยัด RAM
        ),
        darwinLoadControl: DarwinLoadControl(
          preferredForwardBufferDuration: const Duration(minutes: 2),
          automaticallyWaitsToMinimizeStalling: false,
        ),
      ),
    );
    _init();
  }

  Future<void> _init() async {
    await _player.setAudioSource(_playlist);
    _player.playbackEventStream.listen(_broadcastState);

    // Sync shuffle mode changes -> update UI button state
    _player.shuffleModeEnabledStream.listen((enabled) {
      playbackState.add(
        playbackState.value.copyWith(
          shuffleMode: enabled
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
        ),
      );
    });

    // Sync loop/repeat mode changes -> update UI button state
    _player.loopModeStream.listen((mode) {
      AudioServiceRepeatMode repeatMode;
      switch (mode) {
        case LoopMode.one:
          repeatMode = AudioServiceRepeatMode.one;
          break;
        case LoopMode.all:
          repeatMode = AudioServiceRepeatMode.all;
          break;
        default:
          repeatMode = AudioServiceRepeatMode.none;
      }
      playbackState.add(
        playbackState.value.copyWith(repeatMode: repeatMode),
      );
    });

    // เลื่อนเวลาเพลงโชว์ที่จอ UI (ลดโหลด UI เหลือ 2 frame/วิ เพื่อประหยัด CPU)
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_player.playing &&
          _player.processingState == ProcessingState.ready) {
        playbackState.add(
          playbackState.value.copyWith(
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
          ),
        );
      }
    });

    // ตรวจจับการเปลี่ยนเพลงผ่าน sequenceStateStream เพื่อให้ได้ tag (MediaItem) ที่ถูกต้องเสมอ
    // แก้ปัญหา UI (ตัว select) เด้งไปมาเมื่อ index ของ playlist และ queue ไม่ตรงกันชั่วคราว
    _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState?.currentSource != null) {
        final tag = sequenceState!.currentSource!.tag;
        if (tag is MediaItem) {
          mediaItem.add(tag);
          
          // สั่ง pre-cache โดยใช้ index จาก queue (ค้นหาจาก id ปัจจุบัน)
          final currentIndexInQueue = queue.value.indexWhere((item) => item.id == tag.id);
          if (currentIndexInQueue != -1) {
            _preCacheNextTracksInServer(currentIndexInQueue);
          }
        }
      }
    });

    // 🚀 เพิ่มระบบจัดการ Error ของ Player
    _player.playbackEventStream.listen((event) {
      // ตรวจจับ stuck loading: ถ้าอยู่ใน loading นานเกิน 20 วินาทีให้ recover
      if (event.processingState == ProcessingState.loading) {
        _startLoadingWatchdog();
      } else {
        _cancelLoadingWatchdog();
      }
    }, onError: (Object e, StackTrace st) {
      if (kDebugMode) print('🎵 Player Stream Error: $e');
      _handlePlaybackError();
    });

    // ตรวจจับ state ของ player
    _player.playerStateStream.listen((state) {
      // 🔧 เมื่อ playlist เล่นจบทั้งหมด (completed) — ไม่ต้อง recover ใดๆ
      if (state.processingState == ProcessingState.completed) {
        if (kDebugMode) print('⏹️ Playlist completed — all songs done');
        return;
      }

      // 🔧 idle ที่ไม่คาดคิด (ไม่ใช่ระหว่างเปลี่ยนเพลง)
      if (state.processingState == ProcessingState.idle && !_isChangingSong) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_player.processingState != ProcessingState.idle || _isChangingSong) return;
          if (_player.playing) return;

          // ลอง advance ไปเพลงถัดไปก่อน
          final currentIdx = _player.currentIndex ?? 0;
          final nextIdx = currentIdx + 1;
          if (nextIdx < queue.value.length) {
            if (kDebugMode) print('🔄 Idle detected — advancing to next song ($nextIdx)');
            _safeSkipToIndex(nextIdx);
          } else {
            // ไม่มีเพลงถัดไป — ลอง recover เพลงปัจจุบัน
            if (kDebugMode) print('🔄 Idle detected — recovering current song');
            _recoverIdlePlayer();
          }
        });
      }
    });
  }

  void _handlePlaybackError() {
    _cancelLoadingWatchdog();
    final currentItem = mediaItem.value;
    if (currentItem == null) return;

    Future.delayed(const Duration(seconds: 1), () async {
      if (!_player.playing) {
        if (kDebugMode) print('🔄 Attempting direct URL recovery for: ${currentItem.id}');
        try {
          final directUrl = await ApiService().getAudioUrl(currentItem.id);
          if (directUrl != null) {
            final newSource = AudioSource.uri(
              Uri.parse(directUrl),
              tag: currentItem,
              headers: {'User-Agent': 'Mozilla/5.0'},
            );
            
            final index = _player.currentIndex ?? 0;
            if (index < _playlist.length) {
              // Replace failing source with direct URL
              await _playlist.removeAt(index);
              await _playlist.insert(index, newSource);
              await _player.seek(Duration.zero, index: index);
              await _player.play();
            }
          } else {
             if (kDebugMode) print('❌ Direct recovery failed: No direct URL found');
             await _recoverIdlePlayer();
          }
        } catch (e) {
          if (kDebugMode) print('❌ Direct recovery failed: $e');
          await _recoverIdlePlayer();
        }
      }
    });
  }

  /// ดึง player กลับมาเล่นเมื่อหลุดไปอยู่ใน idle state
  Future<void> _recoverIdlePlayer() async {
    try {
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && currentIndex < _playlist.length) {
        if (kDebugMode) print('🔄 Recovering idle player at index $currentIndex');
        await _player.seek(Duration.zero, index: currentIndex);
        await _player.play();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Idle recovery failed: $e');
    }
  }

  void _startLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = Timer(const Duration(seconds: 10), () {
      if (_player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering) {
        if (kDebugMode) print('⚠️ Loading watchdog triggered — player stuck');
        _forceResetIfStuck();
      }
    });
  }

  void _cancelLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
  }

  /// ปลดล็อก _isChangingSong อัตโนมัติ ป้องกัน deadlock
  void _startChangingSongGuard() {
    _changingSongTimeout?.cancel();
    _isChangingSong = true;
    _changingSongTimeout = Timer(const Duration(seconds: 10), () {
      if (_isChangingSong) {
        if (kDebugMode) print('⚠️ _isChangingSong timeout — force reset');
        _isChangingSong = false;
      }
    });
  }

  void _endChangingSong() {
    _changingSongTimeout?.cancel();
    _isChangingSong = false;
  }

  /// Reset player ทั้งระบบเมื่อค้างรุนแรง
  Future<void> _forceResetIfStuck() async {
    if (kDebugMode) print('🔧 Force resetting stuck player...');
    _endChangingSong();
    _cancelLoadingWatchdog();
    try {
      await _player.stop();
    } catch (_) {}

    // ลอง re-play เพลงปัจจุบัน
    final currentItem = mediaItem.value;
    if (currentItem != null) {
      final currentIdx = _player.currentIndex ?? 0;
      if (currentIdx < _playlist.length) {
        try {
          await _player.seek(Duration.zero, index: currentIdx);
          await _player.play();
          if (kDebugMode) print('✅ Force reset succeeded');
        } catch (e) {
          if (kDebugMode) print('❌ Force reset failed: $e');
          // ถ้ายังไม่ได้ → ลอง recovery ด้วย direct URL
          _handlePlaybackError();
        }
      }
    }
  }

  /// ลบ source เก่าที่เล่นผ่านไปแล้ว ประหยัด memory
  Future<void> _trimOldSources() async {
    final currentIdx = _player.currentIndex ?? 0;
    // ลบ source ที่อยู่ห่างจากตำแหน่งปัจจุบันมากกว่า 50 ตัว
    if (currentIdx > 50 && _playlist.length > _maxQueueSize) {
      final removeCount = currentIdx - 30; // เก็บไว้ 30 เพลงก่อนหน้า
      if (removeCount > 0) {
        try {
          await _playlist.removeRange(0, removeCount);
          // อัปเดต queue ให้ตรงกัน
          final currentQueue = List<MediaItem>.from(queue.value);
          currentQueue.removeRange(0, removeCount);
          queue.add(currentQueue);
          if (kDebugMode) print('🧹 Trimmed $removeCount old sources');
        } catch (e) {
          if (kDebugMode) print('❌ Trim failed: $e');
        }
      }
    }
  }

  /// ตรวจสอบและเพิ่ม AudioSource ให้ _playlist ครบถึง targetIndex
  /// แก้ปัญหา: skip ไปเพลงที่ _playlist ยังไม่มี source → player หยุดทำงาน
  Future<void> _ensurePlaylistHasIndex(int targetIndex) async {
    while (_playlist.length <= targetIndex) {
      final idx = _playlist.length;
      if (idx >= queue.value.length) break;

      final item = queue.value[idx];
      final isLocal = item.extras?['isLocal'] == true;
      final filePath = item.extras?['filePath'] as String?;

      final AudioSource source;
      if (isLocal && filePath != null) {
        source = AudioSource.file(filePath, tag: item);
      } else {
        source = AudioSource.uri(
          Uri.parse(ApiConfig.streamUrl(item.id)),
          tag: item,
          headers: {'User-Agent': 'Mozilla/5.0'},
        );
      }
      if (kDebugMode) print('➕ Adding missing source at idx=$idx: ${item.title}');
      await _playlist.add(source);
    }
  }

  /// Skip ไปยัง index ที่ต้องการอย่างปลอดภัย
  /// — ตรวจให้ _playlist มี source พร้อมก่อนเสมอ
  /// — อัปเดต UI ทันที
  Future<void> _safeSkipToIndex(int index) async {
    if (index < 0 || index >= queue.value.length || _isChangingSong) return;

    _startChangingSongGuard();
    mediaItem.add(queue.value[index]);

    try {
      await _ensurePlaylistHasIndex(index);
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      if (kDebugMode) print('❌ safeSkipToIndex($index) error: $e');
      _handlePlaybackError();
    } finally {
      _endChangingSong();
    }
  }

  Future<void> _preCacheNextTracksInServer(int currentIndex) async {
    for (int offset = 1; offset <= 2; offset++) {
      int nextIndex = currentIndex + offset;
      if (nextIndex < queue.value.length) {
        final songId = queue.value[nextIndex].id;
        // ข้ามเพลง local — ไม่ต้อง pre-cache
        if (songId.startsWith('local_')) continue;
        try {
          await ApiService().getAudioUrl(songId);
        } catch (_) {}
      }
    }
  }

  // =============================================
  // ระบบเล่นเพลง & โหลดคิว
  // =============================================

  Future<void> playSong(Song song) async {
    final item = _songToMediaItem(song);
    int existingIndex = queue.value.indexWhere((i) => i.id == song.id);

    // 🚀 อัพเดท UI ทันทีไม่ต้องรอโหลด
    mediaItem.add(item);

    if (existingIndex != -1) {
      // มีอยู่ในคิวแล้ว seek + play ทันที
      _startChangingSongGuard();
      try {
        await _player.seek(Duration.zero, index: existingIndex);
        await _player.play();
      } catch (e) {
        if (kDebugMode) print('❌ Seek to existing error: $e');
      } finally {
        _endChangingSong();
      }
    } else {
      // เพิ่มเข้าคิวใหม่
      final currentQueue = List<MediaItem>.from(queue.value);
      currentQueue.add(item);
      queue.add(currentQueue);
      final targetIndex = currentQueue.length - 1;

      final AudioSource source;
      if (song.isLocal && song.filePath != null) {
        source = AudioSource.file(song.filePath!, tag: item);
      } else {
        source = AudioSource.uri(
          Uri.parse(ApiConfig.streamUrl(song.id)),
          tag: item,
          headers: {'User-Agent': 'Mozilla/5.0'},
        );
        ApiService().getAudioUrl(song.id).catchError((_) => null);
      }

      _startChangingSongGuard();
      try {
        await _playlist.add(source);
        await _player.seek(Duration.zero, index: targetIndex);
        await _player.play();
        // ลบ source เก่าถ้า queue ใหญ่เกินไป
        unawaited(_trimOldSources());
      } catch (e) {
        if (kDebugMode) print('❌ Playback error in playSong: $e');
        _handlePlaybackError();
      } finally {
        _endChangingSong();
      }
    }
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;

    songs = List<Song>.from(songs);

    final items = songs.map(_songToMediaItem).toList();
    queue.add(items);

    if (initialIndex >= 0 && initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
    }

    final Song firstSong = songs[initialIndex];
    final MediaItem firstItem = items[initialIndex];

    if (!firstSong.isLocal) {
      ApiService().getAudioUrl(firstSong.id).catchError((_) => null);
    }

    final AudioSource firstSource = firstSong.isLocal && firstSong.filePath != null
        ? AudioSource.file(firstSong.filePath!, tag: firstItem)
        : AudioSource.uri(
            Uri.parse(ApiConfig.streamUrl(firstSong.id)),
            tag: firstItem,
            headers: {'User-Agent': 'Mozilla/5.0'},
          );

    // 🔧 Stop player ก่อน clear เพื่อป้องกัน race condition
    _startChangingSongGuard();
    try {
      await _player.stop();
      await _playlist.clear();
      await _playlist.add(firstSource);
      await _player.seek(Duration.zero, index: 0);
      await _player.play();
    } catch (e) {
      if (kDebugMode) print('❌ Error starting first song: $e');
      _handlePlaybackError();
    } finally {
      _endChangingSong();
    }

    if (songs.length > 1) {
      unawaited(_loadRemainingQueue(songs, items, initialIndex));
    }
  }

  /// โหลดเพลงที่เหลือใน background หลังจากเพลงแรกเริ่มเล่นแล้ว
  Future<void> _loadRemainingQueue(
    List<Song> songs,
    List<MediaItem> items,
    int initialIndex,
  ) async {
    // Pre-cache แค่ 3 เพลงถัดไป (ลดจาก 10 เพื่อประหยัด Network/CPU)
    final List<String> nextBatchIds = [];
    for (int i = initialIndex + 1; i < songs.length && i < initialIndex + 4; i++) {
      if (!songs[i].isLocal) nextBatchIds.add(songs[i].id);
    }

    Map<String, String?> directUrls = {};
    if (nextBatchIds.isNotEmpty) {
      try {
        directUrls = await ApiService().batchResolveUrls(nextBatchIds);
      } catch (e) {
        if (kDebugMode) print('❌ Batch resolve failed: $e');
      }
    }

    final otherSources = <AudioSource>[];

    // เพลงก่อน initialIndex (ใช้ streamUrl ปกติเพราะโอกาสเล่นน้อยกว่า)
    for (int i = 0; i < initialIndex; i++) {
      final s = songs[i];
      otherSources.add(
        s.isLocal && s.filePath != null
            ? AudioSource.file(s.filePath!, tag: items[i])
            : AudioSource.uri(
                Uri.parse(ApiConfig.streamUrl(s.id)),
                tag: items[i],
                headers: {'User-Agent': 'Mozilla/5.0'},
              ),
      );
    }

    // เพลงหลัง initialIndex (ใช้ streamUrl ปกติ แต่ Server จะมี Cache แล้วเพราะเราสั่ง batchResolve)
    for (int i = initialIndex + 1; i < songs.length; i++) {
      final s = songs[i];
      otherSources.add(
        s.isLocal && s.filePath != null
            ? AudioSource.file(s.filePath!, tag: items[i])
            : AudioSource.uri(
                Uri.parse(ApiConfig.streamUrl(s.id)),
                tag: items[i],
                headers: {'User-Agent': 'Mozilla/5.0'},
              ),
      );
    }

    // insert เพลงก่อน initialIndex ที่ตำแหน่ง 0
    if (initialIndex > 0) {
      await _playlist.insertAll(0, otherSources.sublist(0, initialIndex));
      // 🔧 หลัง insert: seek ไป initialIndex โดยคงตำแหน่งเวลาเดิมไว้
      // ไม่ reset เป็น Duration.zero เพื่อไม่ให้กระโดดกลับต้นเพลง
      final currentPosition = _player.position;
      final currentIdx = _player.currentIndex ?? 0;
      if (currentIdx < initialIndex) {
        await _player.seek(currentPosition, index: initialIndex);
      }
    }
    // add เพลงหลัง initialIndex
    if (initialIndex + 1 < songs.length) {
      final afterSources = otherSources.sublist(initialIndex > 0 ? initialIndex : 0);
      if (afterSources.isNotEmpty) {
        await _playlist.addAll(afterSources);
      }
    }
  }

  // =============================================
  // การเปลี่ยนเพลง
  // =============================================

  @override
  Future<void> skipToNext() async {
    if (_isChangingSong) return;
    final nextIndex = (_player.currentIndex ?? 0) + 1;
    if (nextIndex < queue.value.length) {
      await _safeSkipToIndex(nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_isChangingSong) return;
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      final prevIndex = (_player.currentIndex ?? 0) - 1;
      if (prevIndex >= 0) {
        await _safeSkipToIndex(prevIndex);
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (_isChangingSong) return;
    if (index >= 0 && index < queue.value.length) {
      await _safeSkipToIndex(index);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      await _player.setShuffleModeEnabled(true);
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      if (kDebugMode) print('❌ Manual play error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      if (kDebugMode) print('❌ Manual pause error: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      if (kDebugMode) print('❌ Manual seek error: $e');
    }
  }

  @override
  Future<void> stop() async {
    _cancelLoadingWatchdog();
    _endChangingSong();
    await _player.stop();
    _positionTimer?.cancel();
  }

  MediaItem _songToMediaItem(Song song) {
    Uri? artUri;
    if (song.isLocal) {
      // Local file — ตั้งเป็น null เพื่อป้องกัน Android SystemUI crash จาก dummy URI
      artUri = null;
    } else if (song.thumbnail.isNotEmpty && song.thumbnail != "NA") {
      artUri = Uri.parse(song.thumbnail);
    }

    return MediaItem(
      id: song.id,
      album: song.isLocal ? 'Local Music' : 'YouTube Music',
      title: song.title,
      artist: song.artist,
      artUri: artUri,
      duration: Duration(seconds: song.duration),
      extras: {
        'isLocal': song.isLocal,
        'filePath': song.filePath,
      },
    );
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex ?? (_player.currentIndex ?? 0),
      ),
    );
  }
}
