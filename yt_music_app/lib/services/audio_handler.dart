import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(minutes: 5),   
        maxBufferDuration: const Duration(minutes: 10),    
        bufferForPlaybackDuration: const Duration(seconds: 2), 
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 3), 
        targetBufferBytes: 1024 * 1024 * 50, // 50 MB
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: const Duration(minutes: 5),
        automaticallyWaitsToMinimizeStalling: true,
      ),
    ),
  );

  final Map<String, String> _urlCache = {};
  int _currentIndex = -1;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  Timer? _positionTimer;
  bool _isTransitioning = false;

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    _player.playbackEventStream.listen(_broadcastState);

    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_player.playing) {
        playbackState.add(playbackState.value.copyWith(
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ));
      }
    });

    _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (!_isTransitioning) {
          await _handleSongComplete();
        }
      } else if (state.processingState == ProcessingState.idle && !_isTransitioning) {
        if (_player.playing == false && _currentIndex >= 0) {
           print('⚠️ Network idle or failure. Retrying stream...');
           _retryCurrentSong();
        }
      }
    });
  }

  Future<void> _handleSongComplete() async {
    _isTransitioning = true;
    try {
      if (_repeatMode == AudioServiceRepeatMode.one) {
        await _player.seek(Duration.zero);
        await _player.play();
      } else {
        await skipToNext();
      }
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _retryCurrentSong() async {
    _isTransitioning = true;
    try {
      if (_currentIndex >= 0 && _currentIndex < queue.value.length) {
        final item = queue.value[_currentIndex];
        _urlCache.remove(item.id);
        
        final duration = _player.position; 
        await _playCurrentQueueItem(seekPosition: duration);
      }
    } catch (e) {
      print("Retry failed: $e");
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> playSong(Song song) async {
    final item = _songToMediaItem(song);
    
    final existingIndex = queue.value.indexWhere((i) => i.id == song.id);
    if (existingIndex != -1) {
      _currentIndex = existingIndex;
    } else {
      queue.add([item]);
      _currentIndex = 0;
    }
    
    await _playCurrentQueueItem();
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    
    final items = songs.map(_songToMediaItem).toList();
    queue.add(items);
    _currentIndex = initialIndex >= 0 && initialIndex < items.length ? initialIndex : 0;
    
    await _playCurrentQueueItem();
  }

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    
    _isTransitioning = true;
    try {
      if (_currentIndex < queue.value.length - 1) {
        _currentIndex++;
        await _playCurrentQueueItem();
      } else if (_repeatMode == AudioServiceRepeatMode.all || _repeatMode == AudioServiceRepeatMode.group) {
        _currentIndex = 0;
        await _playCurrentQueueItem();
      } else {
        await _player.stop();
      }
    } finally {
      _isTransitioning = false;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    
    _isTransitioning = true;
    try {
      if (_player.position > const Duration(seconds: 3)) {
        await _player.seek(Duration.zero);
      } else if (_currentIndex > 0) {
        _currentIndex--;
        await _playCurrentQueueItem();
      } else if (_repeatMode == AudioServiceRepeatMode.all) {
        _currentIndex = queue.value.length - 1;
        await _playCurrentQueueItem();
      } else {
        await _player.seek(Duration.zero);
      }
    } finally {
      _isTransitioning = false;
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      _currentIndex = index;
      await _playCurrentQueueItem();
    }
  }
  
  Future<void> _playCurrentQueueItem({Duration seekPosition = Duration.zero}) async {
    if (_currentIndex < 0 || _currentIndex >= queue.value.length) return;
    
    final item = queue.value[_currentIndex];
    mediaItem.add(item);
    
    try {
      String url;
      if (_urlCache.containsKey(item.id)) {
        url = _urlCache[item.id]!;
      } else {
        String? directUrl = await ApiService().getAudioUrl(item.id);
        if (directUrl != null) {
          url = directUrl;
          _urlCache[item.id] = directUrl;
        } else {
          url = ApiConfig.streamUrl(item.id);
        }
      }

      final source = AudioSource.uri(
        Uri.parse(url), 
        tag: item,
      );

      await _player.setAudioSource(source, initialPosition: seekPosition);
      await _player.play();
      
      _preResolveNextTrack();

    } catch (e) {
      print('❌ Audio Load Error: $e');
      await Future.delayed(const Duration(seconds: 1));
      skipToNext();
    }
  }

  Future<void> _preResolveNextTrack() async {
    if (_currentIndex + 1 < queue.value.length) {
      final nextItem = queue.value[_currentIndex + 1];
      if (!_urlCache.containsKey(nextItem.id)) {
        try {
          String? directUrl = await ApiService().getAudioUrl(nextItem.id);
          if (directUrl != null) {
            _urlCache[nextItem.id] = directUrl;
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
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
      queueIndex: _currentIndex,
    ));
  }
}
