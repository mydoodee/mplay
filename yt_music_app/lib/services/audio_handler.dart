import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  // 🎧 AudioPlayer with optimized buffer settings for smooth streaming
  final _player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 15),     // Buffer ขั้นต่ำ 15 วินาที
        maxBufferDuration: const Duration(seconds: 50),     // Buffer สูงสุด 50 วินาที
        bufferForPlaybackDuration: const Duration(seconds: 4),  // Buffer 4 วิ ก่อนเริ่มเล่น
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 8),  // Buffer 8 วิ หลัง rebuffer
        targetBufferBytes: -1,  // ไม่จำกัดขนาด buffer
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: const Duration(seconds: 20),  // iOS/macOS buffer
        automaticallyWaitsToMinimizeStalling: true,
      ),
    ),
  );
  final _playlist = ConcatenatingAudioSource(
    children: [],
    useLazyPreparation: true,  // Prepare next track lazily for gapless
  );

  // 🎵 URL cache — เก็บ direct URL ที่ resolve แล้ว
  final Map<String, String> _urlCache = {};
  
  // 🛡️ Prevent duplicate resolve calls
  final Set<String> _resolving = {};

  // 📊 Position throttle — ลด UI rebuild
  Timer? _positionTimer;

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_playlist, preload: false);
    } catch (e) {
      print('AudioHandler init source error: $e');
    }

    // =============================================
    // 🔄 Event Streams — อัพเดท UI & pre-resolve
    // =============================================
    
    // Forward playback events to audio service
    _player.playbackEventStream.listen(_broadcastState);

    // Handle current track change — update mediaItem + pre-resolve next
    _player.currentIndexStream.listen((index) async {
      if (index != null && index >= 0 && index < _playlist.length) {
        try {
          final child = _playlist.children[index];
          if (child is IndexedAudioSource) {
            final item = child.tag as MediaItem;
            mediaItem.add(item);
            
            // 🚀 Pre-resolve NEXT track URL in background (non-destructive)
            _preResolveNextTrack(index);
          }
        } catch (e) {
          print('AudioHandler Index Listener Error: $e');
        }
      }
    });

    // 📊 Throttled position updates — ลด UI rebuild จากทุก frame เหลือ 4 ครั้ง/วินาที
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_player.playing) {
        playbackState.add(playbackState.value.copyWith(
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ));
      }
    });

    // 🎵 Duration changes
    _player.durationStream.listen((duration) {
      if (duration == null) return;
      final item = mediaItem.value;
      if (item == null) return;
      mediaItem.add(item.copyWith(duration: duration));
    });

    // 🛡️ Error Recovery — auto-retry on player errors
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle && 
          _player.playing == false &&
          _playlist.length > 0) {
        // Player stopped unexpectedly — might be a stream error
        print('⚠️ Player stopped unexpectedly, attempting recovery...');
        _attemptRecovery();
      }
    });
  }

  // =============================================
  // 🚀 Pre-resolve next track URL (NON-DESTRUCTIVE)
  // ไม่ทำ removeAt/insert — แค่ cache URL ไว้ล่วงหน้า
  // =============================================
  Future<void> _preResolveNextTrack(int currentIndex) async {
    // Pre-resolve next 2 tracks
    for (int offset = 1; offset <= 2; offset++) {
      final nextIndex = currentIndex + offset;
      if (nextIndex >= _playlist.length) break;
      
      try {
        final child = _playlist.children[nextIndex];
        if (child is IndexedAudioSource) {
          final item = child.tag as MediaItem;
          
          // Skip if already cached
          if (_urlCache.containsKey(item.id)) continue;
          if (_resolving.contains(item.id)) continue;
          
          _resolving.add(item.id);
          print('🔮 Pre-resolving next track: ${item.title}');
          
          String? directUrl = await ApiService().getAudioUrl(item.id);
          if (directUrl != null) {
            _urlCache[item.id] = directUrl;
            print('✅ Pre-cached URL for: ${item.title}');
          }
          _resolving.remove(item.id);
        }
      } catch (e) {
        print('Pre-resolve error: $e');
      }
    }
  }

  // =============================================
  // 🛡️ Error Recovery
  // =============================================
  Future<void> _attemptRecovery() async {
    try {
      final index = _player.currentIndex;
      if (index == null || index >= _playlist.length) return;

      final child = _playlist.children[index];
      if (child is IndexedAudioSource) {
        final item = child.tag as MediaItem;
        print('🔄 Recovering playback for: ${item.title}');
        
        // Get a fresh URL
        String? freshUrl = await ApiService().getAudioUrl(item.id);
        if (freshUrl != null) {
          _urlCache[item.id] = freshUrl;
          
          // Replace the source with fresh URL
          final newSource = AudioSource.uri(Uri.parse(freshUrl), tag: item);
          final position = _player.position;
          
          await _playlist.removeAt(index);
          await _playlist.insert(index, newSource);
          await _player.seek(position, index: index);
          await _player.play();
          
          print('✅ Recovery successful for: ${item.title}');
        }
      }
    } catch (e) {
      print('❌ Recovery failed: $e');
    }
  }

  // =============================================
  // 🎵 Play a single song — resolve URL ก่อนเล่นเสมอ
  // =============================================
  Future<void> playSong(Song song) async {
    try {
      // Always try to get direct CDN URL first
      String url;
      
      if (_urlCache.containsKey(song.id)) {
        url = _urlCache[song.id]!;
        print('⚡ Using cached URL for: ${song.title}');
      } else {
        String? directUrl = await ApiService().getAudioUrl(song.id);
        if (directUrl != null) {
          url = directUrl;
          _urlCache[song.id] = directUrl;
          print('✅ Resolved direct URL for: ${song.title}');
        } else {
          url = ApiConfig.streamUrl(song.id);
          print('⚠️ Falling back to proxy for: ${song.title}');
        }
      }

      final item = _songToMediaItem(song);
      
      // Check if song is already in playlist
      int existingIndex = _findSongIndex(song.id);

      if (existingIndex != -1) {
        // Already in playlist — update source with fresh URL and seek
        final source = AudioSource.uri(Uri.parse(url), tag: item);
        await _playlist.removeAt(existingIndex);
        await _playlist.insert(existingIndex, source);
        await _player.seek(Duration.zero, index: existingIndex);
      } else {
        // Add new source to playlist
        final source = AudioSource.uri(Uri.parse(url), tag: item);
        await _playlist.add(source);
        await _player.seek(Duration.zero, index: _playlist.length - 1);
      }
      
      // Update mediaItem immediately for responsive UI
      mediaItem.add(item);
      
      // Start playing
      _player.play().catchError((e) => print('Player Error: $e'));
      
    } catch (e) {
      print('AudioHandler playSong error: $e');
    }
  }

  // =============================================
  // 🎵 Set Queue — resolve URLs before playing
  // =============================================
  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    
    try {
      // Step 1: Resolve the initial song's URL first (critical for playback start)
      final initialSong = songs[initialIndex];
      String initialUrl;
      
      if (_urlCache.containsKey(initialSong.id)) {
        initialUrl = _urlCache[initialSong.id]!;
      } else {
        String? directUrl = await ApiService().getAudioUrl(initialSong.id);
        if (directUrl != null) {
          initialUrl = directUrl;
          _urlCache[initialSong.id] = directUrl;
        } else {
          initialUrl = ApiConfig.streamUrl(initialSong.id);
        }
      }

      // Step 2: Build audio sources — use cached URLs where available, proxy otherwise
      final sources = <AudioSource>[];
      for (int i = 0; i < songs.length; i++) {
        final song = songs[i];
        final item = _songToMediaItem(song);
        
        String url;
        if (i == initialIndex) {
          url = initialUrl; // Already resolved
        } else if (_urlCache.containsKey(song.id)) {
          url = _urlCache[song.id]!;
        } else {
          // Use proxy URL — will be pre-resolved during playback
          url = ApiConfig.streamUrl(song.id);
        }
        
        sources.add(AudioSource.uri(Uri.parse(url), tag: item));
      }

      // Step 3: Clear and set new playlist
      await _playlist.clear();
      await _playlist.addAll(sources);
      
      // Update queue for audio service
      queue.add(songs.map(_songToMediaItem).toList());
      
      // Step 4: Start playing the initial song
      if (initialIndex < songs.length) {
        await _player.seek(Duration.zero, index: initialIndex);
        mediaItem.add(_songToMediaItem(initialSong));
        _player.play();
      }

      // Step 5: Pre-resolve next few songs in background (fire and forget)
      _preResolveQueueUrls(songs, initialIndex);
      
    } catch (e) {
      print('AudioHandler setQueue error: $e');
    }
  }

  // =============================================
  // 🔮 Background pre-resolve queue URLs
  // =============================================
  Future<void> _preResolveQueueUrls(List<Song> songs, int startFrom) async {
    // Resolve next 3 songs in background
    for (int i = startFrom + 1; i < songs.length && i <= startFrom + 3; i++) {
      final song = songs[i];
      if (_urlCache.containsKey(song.id)) continue;
      if (_resolving.contains(song.id)) continue;
      
      _resolving.add(song.id);
      try {
        String? directUrl = await ApiService().getAudioUrl(song.id);
        if (directUrl != null) {
          _urlCache[song.id] = directUrl;
          print('✅ Queue pre-cached: ${song.title}');
        }
      } catch (e) {
        // Silent fail — proxy URL will work as fallback
      }
      _resolving.remove(song.id);
    }
  }

  // =============================================
  // 🔍 Find song index in playlist
  // =============================================
  int _findSongIndex(String songId) {
    for (int i = 0; i < _playlist.length; i++) {
      final child = _playlist.children[i];
      if (child is UriAudioSource) {
        if ((child.tag as MediaItem).id == songId) {
          return i;
        }
      }
    }
    return -1;
  }

  AudioSource _createAudioSource(MediaItem item) {
    // Use cached URL if available, otherwise proxy
    final url = _urlCache[item.id] ?? ApiConfig.streamUrl(item.id);
    return AudioSource.uri(Uri.parse(url), tag: item);
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      album: 'YouTube Music',
      title: song.title,
      artist: song.artist,
      artUri: (song.thumbnail.isNotEmpty && song.thumbnail != "NA") 
          ? Uri.parse(song.thumbnail) 
          : null,
      duration: Duration(seconds: song.duration),
    );
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

  @override
  Future<void> skipToNext() async {
    final nextIndex = (_player.currentIndex ?? 0) + 1;
    
    // If we have a cached URL for the next song, update the source before seeking
    if (nextIndex < _playlist.length) {
      final child = _playlist.children[nextIndex];
      if (child is IndexedAudioSource) {
        final item = child.tag as MediaItem;
        if (_urlCache.containsKey(item.id)) {
          final cachedUrl = _urlCache[item.id]!;
          // Check if current source is using proxy URL
          if (child is UriAudioSource && child.uri.toString().contains('/api/stream/')) {
            // Upgrade to direct URL before playing
            final newSource = AudioSource.uri(Uri.parse(cachedUrl), tag: item);
            await _playlist.removeAt(nextIndex);
            await _playlist.insert(nextIndex, newSource);
            print('⚡ Upgraded next track to direct URL: ${item.title}');
          }
        }
      }
    }
    
    await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

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

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
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
      queueIndex: event.currentIndex,
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
      shuffleMode: (_player.shuffleModeEnabled) 
          ? AudioServiceShuffleMode.all 
          : AudioServiceShuffleMode.none,
    ));
  }
}
