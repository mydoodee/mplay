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
  Timer? _loadingWatchdog; // ตรวจจับกรณีที่ player ค้างอยู่ที่ loading นานเกินไป
  bool _isChangingSong = false; // ป้องกัน race condition

  MyAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [equalizer, loudnessEnhancer],
      ),
      audioLoadConfiguration: AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: const Duration(minutes: 1),
          maxBufferDuration: const Duration(minutes: 5),
          bufferForPlaybackDuration: const Duration(seconds: 1),
          bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 2),
          targetBufferBytes: 1024 * 1024 * 30, // 30MB
        ),
        darwinLoadControl: DarwinLoadControl(
          preferredForwardBufferDuration: const Duration(minutes: 3),
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

    // เลื่อนเวลาเพลงโชว์ที่จอ UI (ลดโหลด UI เหลือ 4 frame/วิ)
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_player.playing) {
        playbackState.add(
          playbackState.value.copyWith(
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
          ),
        );
      }
    });

    // ตรวจจับการเลื่อนเพลง -> แจ้งเตือน UI ว่าเล่นเพลงไหนอยู่
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
        _preCacheNextTracksInServer(index);
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

    // ตรวจจับ error จาก player โดยตรง
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle && _isChangingSong == false) {
        // Player กลับมา idle โดยไม่ได้ตั้งใจ (ไม่ใช่ระหว่างเปลี่ยนเพลง)
        // รอแล้ว recover
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_player.processingState == ProcessingState.idle && !_player.playing) {
            _recoverIdlePlayer();
          }
        });
      }
    });
  }

  void _handlePlaybackError() {
    _cancelLoadingWatchdog();
    Future.delayed(const Duration(seconds: 1), () async {
      if (!_player.playing) {
        if (kDebugMode) print('🔄 Attempting playback recovery...');
        // ถ้า player ยังมี source ให้ลอง seek + play ใหม่
        if (_player.processingState != ProcessingState.idle) {
          try {
            await _player.seek(_player.position);
            await _player.play();
          } catch (e) {
            if (kDebugMode) print('❌ Recovery failed: $e');
          }
        } else {
          // player เป็น idle จริงๆ ให้ลอง reconnect
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
    _loadingWatchdog = Timer(const Duration(seconds: 20), () {
      // ถ้าค้างอยู่ที่ loading เกิน 20 วินาที
      if (_player.processingState == ProcessingState.loading) {
        if (kDebugMode) print('⚠️ Loading watchdog triggered — player stuck');
        _handlePlaybackError();
      }
    });
  }

  void _cancelLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
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
      _isChangingSong = true;
      try {
        await _player.seek(Duration.zero, index: existingIndex);
        await _player.play();
      } catch (e) {
        if (kDebugMode) print('❌ Seek to existing error: $e');
      } finally {
        _isChangingSong = false;
      }
    } else {
      // เพิ่มเข้าคิวใหม่
      final currentQueue = List<MediaItem>.from(queue.value);
      currentQueue.add(item);
      queue.add(currentQueue);
      // 📌 จับ index ตอนนี้เลย ก่อนที่ async จะเปลี่ยนแปลง
      final targetIndex = currentQueue.length - 1;

      final AudioSource source;
      if (song.isLocal && song.filePath != null) {
        // 🎵 เล่นไฟล์จากเครื่อง
        source = AudioSource.file(song.filePath!, tag: item);
      } else {
        // 🌐 เล่นจาก YouTube stream
        source = AudioSource.uri(
          Uri.parse(ApiConfig.streamUrl(song.id)),
          tag: item,
          headers: {'User-Agent': 'Mozilla/5.0'},
        );
        // 🚀 บอกให้ Server เริ่มโหลดลิงก์ไว้เลย (parallel กับ player setup)
        ApiService().getAudioUrl(song.id).catchError((_) => null);
      }

      _isChangingSong = true;
      // 🚀 add + seek + play แบบ non-blocking — ไม่รอ I/O
      unawaited(_playlist.add(source).then((_) async {
        try {
          await _player.seek(Duration.zero, index: targetIndex); // ✅ ใช้ index ที่ capture ไว้
          await _player.play();
        } catch (e) {
          if (kDebugMode) print('❌ Playback error in playSong: $e');
        } finally {
          _isChangingSong = false;
        }
      }).catchError((e) {
        _isChangingSong = false;
        if (kDebugMode) print('❌ Playlist add error: $e');
      }));
    }
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;

    // สร้าง copy ป้องกัน RangeError กรณี list ต้นทางถูกแก้ไขระหว่าง await
    songs = List<Song>.from(songs);

    final items = songs.map(_songToMediaItem).toList();
    queue.add(items);

    // 🚀 Step 1: โชว์ UI ทันที
    if (initialIndex >= 0 && initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
    }

    final Song firstSong = songs[initialIndex];
    final MediaItem firstItem = items[initialIndex];

    // 🚀 Step 2: บอกให้ Server เริ่มโหลดลิงก์ไว้ทันที (แบบ parallel)
    // เพื่อให้เวลา yt-dlp ทำงานพร้อมกับที่แอปเตรียม Player
    if (!firstSong.isLocal) {
      ApiService().getAudioUrl(firstSong.id).catchError((_) => null);
    }

    // 🚀 Step 3: สร้าง source เพลงแรก
    final AudioSource firstSource = firstSong.isLocal && firstSong.filePath != null
        ? AudioSource.file(firstSong.filePath!, tag: firstItem)
        : AudioSource.uri(
            Uri.parse(ApiConfig.streamUrl(firstSong.id)),
            tag: firstItem,
            headers: {'User-Agent': 'Mozilla/5.0'},
          );

    await _playlist.clear();
    _isChangingSong = true;
    try {
      await _playlist.add(firstSource);
      await _player.seek(Duration.zero, index: 0);
      await _player.play(); // 🚀 เล่นทันที ไม่รอโหลดเพลงอื่น
    } catch (e) {
      if (kDebugMode) print('❌ Error starting first song: $e');
      _handlePlaybackError();
    } finally {
      _isChangingSong = false;
    }

    // 🚀 Step 4: โหลดเพลงที่เหลือใน background
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
    // 🚀 พยายามดึง direct URL ล่วงหน้า 10 เพลงถัดไปเพื่อข้าม Redirect
    final List<String> nextBatchIds = [];
    for (int i = initialIndex + 1; i < songs.length && i < initialIndex + 11; i++) {
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
      // ✅ หลัง insert เพลงก่อน initialIndex index ของเพลงที่เล่นอยู่จะเลื่อนไป
      // ต้อง seek ไปที่ index ใหม่เพื่อไม่ให้เพลงกระโดด
      final newIndex = _player.currentIndex ?? 0;
      // ถ้า player ยังเล่นอยู่ที่เพลงแรก (index 0) ให้ seek ไป initialIndex
      if (newIndex == 0 || newIndex < initialIndex) {
        await _player.seek(Duration.zero, index: initialIndex);
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
      _isChangingSong = true;
      mediaItem.add(queue.value[nextIndex]); // โชว์ใน UI เร็วขึ้น
      try {
        await _player.seekToNext();
      } catch (e) {
        if (kDebugMode) print('❌ skipToNext error: $e');
        _handlePlaybackError();
      } finally {
        _isChangingSong = false;
      }
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
        _isChangingSong = true;
        mediaItem.add(queue.value[prevIndex]); // โชว์ใน UI เร็วขึ้น
        try {
          await _player.seekToPrevious();
        } catch (e) {
          if (kDebugMode) print('❌ skipToPrevious error: $e');
          _handlePlaybackError();
        } finally {
          _isChangingSong = false;
        }
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (_isChangingSong) return;
    if (index >= 0 && index < queue.value.length) {
      _isChangingSong = true;
      mediaItem.add(queue.value[index]); // โชว์ใน UI ทันทีที่กดเลือกเพลง
      try {
        await _player.seek(Duration.zero, index: index);
        await _player.play();
      } catch (e) {
        if (kDebugMode) print('❌ skipToQueueItem error: $e');
        _handlePlaybackError();
      } finally {
        _isChangingSong = false;
      }
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
