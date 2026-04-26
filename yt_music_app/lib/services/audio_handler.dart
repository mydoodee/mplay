import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
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

  MyAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [equalizer, loudnessEnhancer],
      ),
      audioLoadConfiguration: AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: const Duration(minutes: 5),
          maxBufferDuration: const Duration(minutes: 10),
          bufferForPlaybackDuration: const Duration(seconds: 2),
          bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 3),
          targetBufferBytes: 1024 * 1024 * 50,
        ),
        darwinLoadControl: DarwinLoadControl(
          preferredForwardBufferDuration: const Duration(minutes: 5),
          automaticallyWaitsToMinimizeStalling: true,
        ),
      ),
    );
    _init();
  }

  Future<void> _init() async {
    await _player.setAudioSource(_playlist);
    _player.playbackEventStream.listen(_broadcastState);

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
        // แอบโหลดลิงก์เพลงถัดไป 1-2 เพลงส่งไปแคชไว้ที่ API Server แบบเบื้องหลัง
        _preCacheNextTracksInServer(index);
      }
    });
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

    // 🚀 อัพเดท UI ทันทีไม่ต้องรอโหลด เพื่อไม่ให้หน้าเพลย์เยอร์หายหรือค้าง
    mediaItem.add(item);

    if (existingIndex != -1) {
      // มีอยู่ในคิวแล้ว ให้เล่นเลย
      await _player.seek(Duration.zero, index: existingIndex);
      _player.play();
    } else {
      // เพิ่มเข้าคิวใหม่
      final currentQueue = List<MediaItem>.from(queue.value);
      currentQueue.add(item);
      queue.add(currentQueue);

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
        // รีบแคชลิงก์เพลงแรกแบบเบื้องหลัง (ไม่หน่วง UI)
        ApiService().getAudioUrl(song.id).catchError((_) => null);
      }

      await _playlist.add(source);
      await _player.seek(Duration.zero, index: currentQueue.length - 1);
      _player.play();
    }
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;

    final items = songs.map(_songToMediaItem).toList();
    queue.add(items);

    if (initialIndex >= 0 && initialIndex < items.length) {
      // 🚀 อัพเดท UI ให้โชว์หน้าต่างเล่นเพลงเด้งขึ้นมา "ทันที"
      mediaItem.add(items[initialIndex]);

      // รีบแคชลิงก์เพลงแรกด่วนแบบเบื้องหลัง (เฉพาะ YouTube)
      if (!songs[initialIndex].isLocal) {
        ApiService().getAudioUrl(songs[initialIndex].id).catchError((_) => null);
      }
    }

    final sources = songs.map((s) {
      if (s.isLocal && s.filePath != null) {
        // 🎵 ไฟล์จากเครื่อง
        return AudioSource.file(s.filePath!, tag: _songToMediaItem(s));
      } else {
        // 🌐 YouTube stream
        return AudioSource.uri(
          Uri.parse(ApiConfig.streamUrl(s.id)),
          tag: _songToMediaItem(s),
          headers: {'User-Agent': 'Mozilla/5.0'},
        );
      }
    }).toList();

    await _playlist.clear();
    await _playlist.addAll(sources);

    if (initialIndex >= 0 && initialIndex < sources.length) {
      await _player.seek(Duration.zero, index: initialIndex);
      _player.play();
    }
  }

  // =============================================
  // การเปลี่ยนเพลง
  // =============================================

  @override
  Future<void> skipToNext() async {
    final nextIndex = (_player.currentIndex ?? 0) + 1;
    if (nextIndex < queue.value.length) {
      mediaItem.add(queue.value[nextIndex]); // โชว์ใน UI เร็วขึ้น
    }
    await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      final prevIndex = (_player.currentIndex ?? 0) - 1;
      if (prevIndex >= 0) {
        mediaItem.add(queue.value[prevIndex]); // โชว์ใน UI เร็วขึ้น
      }
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      mediaItem.add(queue.value[index]); // โชว์ใน UI ทันทีที่กดเลือกเพลง
      await _player.seek(Duration.zero, index: index);
      _player.play();
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    _positionTimer?.cancel();
  }

  MediaItem _songToMediaItem(Song song) {
    Uri? artUri;
    if (song.isLocal) {
      // Local file — ไม่มี network art URI ให้ใช้ dummy URI
      artUri = Uri.parse('local_art://${song.id}');
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
