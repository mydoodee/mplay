// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabMusic => 'Music';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabLocalFiles => 'Local Files';

  @override
  String get tabLibrary => 'Library';

  @override
  String get searchHint => 'Search songs, artists, or paste YouTube link';

  @override
  String get searching => 'Searching...';

  @override
  String get searchSongsArtistsOrLink =>
      'Type song name, artist, or paste YouTube link';

  @override
  String get findSongsYouLike => 'Find songs you like';

  @override
  String get recentlyPlayed => 'Recently Played';

  @override
  String get clearHistory => 'Clear';

  @override
  String get clearHistoryTitle => 'Clear Play History';

  @override
  String get clearHistoryMessage => 'Do you want to clear all play history?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String get create => 'Create';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get favorites => 'Favorites';

  @override
  String get favoriteSongs => 'Favorite Songs';

  @override
  String get noFavorites => 'No favorite songs yet';

  @override
  String songCount(int count) {
    return '$count songs';
  }

  @override
  String get playAll => 'Play All';

  @override
  String get shufflePlay => 'Shuffle';

  @override
  String get allSongs => 'All Songs';

  @override
  String get noSongPlaying => 'No song is currently playing';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get upNext => 'Up Next';

  @override
  String get currentQueue => 'Current Queue';

  @override
  String get noSongsInQueue => 'No songs in queue';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get lyricsComingSoon => 'Lyrics feature coming soon';

  @override
  String get addToPlaylist => 'Add to Playlist';

  @override
  String get createNewPlaylist => 'Create New Playlist';

  @override
  String get playlistNameHint => 'Playlist name';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String addedToPlaylist(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String createdAndAdded(String name) {
    return 'Created and added to \"$name\"';
  }

  @override
  String playlistSongCount(int count) {
    return '$count songs in list • Created for you';
  }

  @override
  String get noSongsInPlaylist => 'No songs in this playlist yet';

  @override
  String get deletePlaylist => 'Delete Playlist';

  @override
  String get deletePlaylistMessage =>
      'Are you sure you want to delete this playlist? Songs in it will be removed from the playlist.';

  @override
  String get playSong => 'Play this song';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get share => 'Share';

  @override
  String get shareSong => 'Share this song';

  @override
  String get songInfo => 'Song Info';

  @override
  String get songTitle => 'Song Title';

  @override
  String get artist => 'Artist';

  @override
  String get duration => 'Duration';

  @override
  String get eqTitle => 'Sound Settings';

  @override
  String get eqBassBoost => 'Bass Boost';

  @override
  String get eqPresetNormal => 'Normal';

  @override
  String get eqPresetPop => 'Pop';

  @override
  String get eqPresetClassic => 'Classic';

  @override
  String get eqPresetJazz => 'Jazz';

  @override
  String get eqPresetRock => 'Rock';

  @override
  String get eqPresetCustom => 'Custom';

  @override
  String get eqBandSubBass => 'Sub Bass';

  @override
  String get eqBandBass => 'Bass';

  @override
  String get eqBandLowMid => 'Low Mid';

  @override
  String get eqBandMid => 'Mid';

  @override
  String get eqBandHighMid => 'High Mid';

  @override
  String get eqBandTreble => 'Treble';

  @override
  String get eqBandBrilliance => 'Brilliance';

  @override
  String get updateAvailable => 'Update Available!';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get updateDetails => 'Update Details:';

  @override
  String get defaultReleaseNotes => '• Performance improvements and bug fixes';

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Downloading...';

  @override
  String downloadProgress(String received, String total) {
    return 'Download $received MB / $total MB';
  }

  @override
  String get downloadFailed => 'Download failed. Please try again';

  @override
  String get openingInstaller => 'Opening installer...';

  @override
  String get installPermissionRequired =>
      'Please allow \"Install unknown apps\" in settings to continue';

  @override
  String get installFailed =>
      'Cannot open installer. Please check permissions for installing apps from unknown sources';

  @override
  String voiceNoSound(String error) {
    return 'No sound detected: $error';
  }

  @override
  String get voiceMicUnavailable => 'Microphone is not available';

  @override
  String get voiceListening => 'Listening...';

  @override
  String get voiceTapToStop => 'Tap to stop';

  @override
  String get adminSystemUsers => 'System Users';

  @override
  String adminOnlineCount(int count) {
    return 'Online: $count people';
  }

  @override
  String get adminNoUsers => 'No users at this time';

  @override
  String adminUsageTime(String time) {
    return 'Usage time';
  }

  @override
  String adminHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes m';
  }

  @override
  String adminMinutes(int minutes) {
    return '$minutes m';
  }

  @override
  String get adminLoginInvalid => 'Invalid username or password';

  @override
  String get adminLogin => 'Login';

  @override
  String get splashTagline => 'Every mood, listen anywhere';

  @override
  String get splashLoading => 'Loading...';

  @override
  String get cannotLoadChangelog => 'Cannot load Changelog';

  @override
  String get localMusic => 'Local Music';

  @override
  String get addFolder => 'Add Folder';

  @override
  String get addFiles => 'Add Files';

  @override
  String get scanningFiles => 'Scanning music files...';

  @override
  String localSongsCount(int count) {
    return '$count songs from device';
  }

  @override
  String get noLocalSongs => 'No local songs added yet';

  @override
  String get tapToAddLocalSongs =>
      'Tap \'Add Folder\' or \'Add Files\' to add songs';

  @override
  String get removeSong => 'Remove Song';

  @override
  String get clearAll => 'Clear All';

  @override
  String get changelog => 'Changelog';

  @override
  String appVersion(String version) {
    return 'v$version';
  }

  @override
  String get localMusicTitle => 'Local Music';

  @override
  String get localMusicSubtitle => 'Add songs from your device or USB Drive';

  @override
  String get noLocalSongsMessage => 'No local songs yet';

  @override
  String get tapToAddLocalSongsMessage =>
      'Tap buttons above to add folders or files';

  @override
  String get exploreHot => 'Hot Hits';

  @override
  String exploreHotSub(int year) {
    return 'Updated hottest hits for $year';
  }

  @override
  String exploreHotQuery(Object year) {
    return 'hottest new songs $year';
  }

  @override
  String get exploreRelax => 'Relaxing Cafe';

  @override
  String get exploreRelaxSub => 'Relaxing music for work';

  @override
  String exploreRelaxQuery(Object year) {
    return 'relaxing cafe music $year';
  }

  @override
  String get exploreIndie => 'Indie Luk Thung';

  @override
  String get exploreIndieSub => 'Indie Luk Thung hits 100M views';

  @override
  String get exploreIndieQuery => 'latest luk thung hits';

  @override
  String get explorePop => 'Cool Pop';

  @override
  String get explorePopSub => 'Relaxing international pop';

  @override
  String explorePopQuery(Object year) {
    return 'top hits international $year';
  }

  @override
  String get exploreRock => 'Rock On';

  @override
  String get exploreRockSub => 'Every beat packed';

  @override
  String get exploreRockQuery => 'thai rock 90s to present';

  @override
  String get exploreSad => 'Sad Vibes';

  @override
  String get exploreSadSub => 'Heart-touching slow songs';

  @override
  String exploreSadQuery(Object year) {
    return 'sad heartbroken songs $year';
  }

  @override
  String get exploreDance => 'Dance & Party';

  @override
  String get exploreDanceSub => 'Wake up the fun';

  @override
  String exploreDanceQuery(Object year) {
    return 'dance songs $year party';
  }

  @override
  String get exploreConcert => 'Hit Concerts';

  @override
  String get exploreConcertSub => 'Ultimate live performances';

  @override
  String get exploreConcertQuery => 'live concert performance';

  @override
  String get adminDashboardTitle => 'User Statistics';

  @override
  String get adminUser => 'User';

  @override
  String get adminLastSeen => 'Last seen';

  @override
  String get adminLoadingUsers => 'Loading user statistics...';

  @override
  String adminErrorLoading(String error) {
    return 'Error loading users: $error';
  }

  @override
  String get adminLoginTitle => 'mPlay System Admin';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String adminUsedTimePrefix(String time) {
    return 'Used: $time';
  }

  @override
  String get exploreTitle => 'Explore';

  @override
  String get exploreSubtitle => 'Find the perfect music for your mood';

  @override
  String get downloadSong => 'Download';

  @override
  String get downloadingSong => 'Downloading...';

  @override
  String get downloadComplete => 'Download complete! Added to Local Files';

  @override
  String get downloadError => 'Download failed. Please try again';

  @override
  String get alreadyDownloaded => 'Already downloaded';
}
