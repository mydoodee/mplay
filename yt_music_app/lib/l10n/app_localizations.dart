import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @tabMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get tabMusic;

  /// No description provided for @tabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// No description provided for @tabLocalFiles.
  ///
  /// In en, this message translates to:
  /// **'Local Files'**
  String get tabLocalFiles;

  /// No description provided for @tabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, or paste YouTube link'**
  String get searchHint;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @searchSongsArtistsOrLink.
  ///
  /// In en, this message translates to:
  /// **'Type song name, artist, or paste YouTube link'**
  String get searchSongsArtistsOrLink;

  /// No description provided for @findSongsYouLike.
  ///
  /// In en, this message translates to:
  /// **'Find songs you like'**
  String get findSongsYouLike;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearHistory;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Play History'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to clear all play history?'**
  String get clearHistoryMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
  String get yourLibrary;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @favoriteSongs.
  ///
  /// In en, this message translates to:
  /// **'Favorite Songs'**
  String get favoriteSongs;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorite songs yet'**
  String get noFavorites;

  /// No description provided for @songCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songCount(int count);

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @shufflePlay.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shufflePlay;

  /// No description provided for @allSongs.
  ///
  /// In en, this message translates to:
  /// **'All Songs'**
  String get allSongs;

  /// No description provided for @noSongPlaying.
  ///
  /// In en, this message translates to:
  /// **'No song is currently playing'**
  String get noSongPlaying;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// No description provided for @currentQueue.
  ///
  /// In en, this message translates to:
  /// **'Current Queue'**
  String get currentQueue;

  /// No description provided for @noSongsInQueue.
  ///
  /// In en, this message translates to:
  /// **'No songs in queue'**
  String get noSongsInQueue;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @lyricsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Lyrics feature coming soon'**
  String get lyricsComingSoon;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @createNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create New Playlist'**
  String get createNewPlaylist;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistNameHint;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylists;

  /// No description provided for @addedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String addedToPlaylist(String name);

  /// No description provided for @createdAndAdded.
  ///
  /// In en, this message translates to:
  /// **'Created and added to \"{name}\"'**
  String createdAndAdded(String name);

  /// No description provided for @playlistSongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs in list • Created for you'**
  String playlistSongCount(int count);

  /// No description provided for @noSongsInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'No songs in this playlist yet'**
  String get noSongsInPlaylist;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this playlist? Songs in it will be removed from the playlist.'**
  String get deletePlaylistMessage;

  /// No description provided for @playSong.
  ///
  /// In en, this message translates to:
  /// **'Play this song'**
  String get playSong;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addFavorite;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareSong.
  ///
  /// In en, this message translates to:
  /// **'Share this song'**
  String get shareSong;

  /// No description provided for @songInfo.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfo;

  /// No description provided for @songTitle.
  ///
  /// In en, this message translates to:
  /// **'Song Title'**
  String get songTitle;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @eqTitle.
  ///
  /// In en, this message translates to:
  /// **'Sound Settings'**
  String get eqTitle;

  /// No description provided for @eqBassBoost.
  ///
  /// In en, this message translates to:
  /// **'Bass Boost'**
  String get eqBassBoost;

  /// No description provided for @eqPresetNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get eqPresetNormal;

  /// No description provided for @eqPresetPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get eqPresetPop;

  /// No description provided for @eqPresetClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get eqPresetClassic;

  /// No description provided for @eqPresetJazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get eqPresetJazz;

  /// No description provided for @eqPresetRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get eqPresetRock;

  /// No description provided for @eqPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get eqPresetCustom;

  /// No description provided for @eqBandSubBass.
  ///
  /// In en, this message translates to:
  /// **'Sub Bass'**
  String get eqBandSubBass;

  /// No description provided for @eqBandBass.
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get eqBandBass;

  /// No description provided for @eqBandLowMid.
  ///
  /// In en, this message translates to:
  /// **'Low Mid'**
  String get eqBandLowMid;

  /// No description provided for @eqBandMid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get eqBandMid;

  /// No description provided for @eqBandHighMid.
  ///
  /// In en, this message translates to:
  /// **'High Mid'**
  String get eqBandHighMid;

  /// No description provided for @eqBandTreble.
  ///
  /// In en, this message translates to:
  /// **'Treble'**
  String get eqBandTreble;

  /// No description provided for @eqBandBrilliance.
  ///
  /// In en, this message translates to:
  /// **'Brilliance'**
  String get eqBandBrilliance;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available!'**
  String get updateAvailable;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @updateDetails.
  ///
  /// In en, this message translates to:
  /// **'Update Details:'**
  String get updateDetails;

  /// No description provided for @defaultReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'• Performance improvements and bug fixes'**
  String get defaultReleaseNotes;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Download {received} MB / {total} MB'**
  String downloadProgress(String received, String total);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again'**
  String get downloadFailed;

  /// No description provided for @openingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Opening installer...'**
  String get openingInstaller;

  /// No description provided for @installPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please allow \"Install unknown apps\" in settings to continue'**
  String get installPermissionRequired;

  /// No description provided for @installFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open installer. Please check permissions for installing apps from unknown sources'**
  String get installFailed;

  /// No description provided for @voiceNoSound.
  ///
  /// In en, this message translates to:
  /// **'No sound detected: {error}'**
  String voiceNoSound(String error);

  /// No description provided for @voiceMicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Microphone is not available'**
  String get voiceMicUnavailable;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get voiceListening;

  /// No description provided for @voiceTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get voiceTapToStop;

  /// No description provided for @adminSystemUsers.
  ///
  /// In en, this message translates to:
  /// **'System Users'**
  String get adminSystemUsers;

  /// No description provided for @adminOnlineCount.
  ///
  /// In en, this message translates to:
  /// **'Online: {count} people'**
  String adminOnlineCount(int count);

  /// No description provided for @adminNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users at this time'**
  String get adminNoUsers;

  /// No description provided for @adminUsageTime.
  ///
  /// In en, this message translates to:
  /// **'Usage time'**
  String adminUsageTime(String time);

  /// No description provided for @adminHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} m'**
  String adminHoursMinutes(int hours, int minutes);

  /// No description provided for @adminMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} m'**
  String adminMinutes(int minutes);

  /// No description provided for @adminLoginInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get adminLoginInvalid;

  /// No description provided for @adminLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get adminLogin;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Every mood, listen anywhere'**
  String get splashTagline;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get splashLoading;

  /// No description provided for @cannotLoadChangelog.
  ///
  /// In en, this message translates to:
  /// **'Cannot load Changelog'**
  String get cannotLoadChangelog;

  /// No description provided for @localMusic.
  ///
  /// In en, this message translates to:
  /// **'Local Music'**
  String get localMusic;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add Files'**
  String get addFiles;

  /// No description provided for @scanningFiles.
  ///
  /// In en, this message translates to:
  /// **'Scanning music files...'**
  String get scanningFiles;

  /// No description provided for @localSongsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs from device'**
  String localSongsCount(int count);

  /// No description provided for @noLocalSongs.
  ///
  /// In en, this message translates to:
  /// **'No local songs added yet'**
  String get noLocalSongs;

  /// No description provided for @tapToAddLocalSongs.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Add Folder\' or \'Add Files\' to add songs'**
  String get tapToAddLocalSongs;

  /// No description provided for @removeSong.
  ///
  /// In en, this message translates to:
  /// **'Remove Song'**
  String get removeSong;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String appVersion(String version);

  /// No description provided for @localMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Music'**
  String get localMusicTitle;

  /// No description provided for @localMusicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add songs from your device or USB Drive'**
  String get localMusicSubtitle;

  /// No description provided for @noLocalSongsMessage.
  ///
  /// In en, this message translates to:
  /// **'No local songs yet'**
  String get noLocalSongsMessage;

  /// No description provided for @tapToAddLocalSongsMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap buttons above to add folders or files'**
  String get tapToAddLocalSongsMessage;

  /// No description provided for @exploreHot.
  ///
  /// In en, this message translates to:
  /// **'Hot Hits'**
  String get exploreHot;

  /// No description provided for @exploreHotSub.
  ///
  /// In en, this message translates to:
  /// **'Updated hottest hits for {year}'**
  String exploreHotSub(int year);

  /// No description provided for @exploreHotQuery.
  ///
  /// In en, this message translates to:
  /// **'hottest new songs {year}'**
  String exploreHotQuery(Object year);

  /// No description provided for @exploreRelax.
  ///
  /// In en, this message translates to:
  /// **'Relaxing Cafe'**
  String get exploreRelax;

  /// No description provided for @exploreRelaxSub.
  ///
  /// In en, this message translates to:
  /// **'Relaxing music for work'**
  String get exploreRelaxSub;

  /// No description provided for @exploreRelaxQuery.
  ///
  /// In en, this message translates to:
  /// **'relaxing cafe music {year}'**
  String exploreRelaxQuery(Object year);

  /// No description provided for @exploreIndie.
  ///
  /// In en, this message translates to:
  /// **'Indie Luk Thung'**
  String get exploreIndie;

  /// No description provided for @exploreIndieSub.
  ///
  /// In en, this message translates to:
  /// **'Indie Luk Thung hits 100M views'**
  String get exploreIndieSub;

  /// No description provided for @exploreIndieQuery.
  ///
  /// In en, this message translates to:
  /// **'latest luk thung hits'**
  String get exploreIndieQuery;

  /// No description provided for @explorePop.
  ///
  /// In en, this message translates to:
  /// **'Cool Pop'**
  String get explorePop;

  /// No description provided for @explorePopSub.
  ///
  /// In en, this message translates to:
  /// **'Relaxing international pop'**
  String get explorePopSub;

  /// No description provided for @explorePopQuery.
  ///
  /// In en, this message translates to:
  /// **'top hits international {year}'**
  String explorePopQuery(Object year);

  /// No description provided for @exploreRock.
  ///
  /// In en, this message translates to:
  /// **'Rock On'**
  String get exploreRock;

  /// No description provided for @exploreRockSub.
  ///
  /// In en, this message translates to:
  /// **'Every beat packed'**
  String get exploreRockSub;

  /// No description provided for @exploreRockQuery.
  ///
  /// In en, this message translates to:
  /// **'thai rock 90s to present'**
  String get exploreRockQuery;

  /// No description provided for @exploreSad.
  ///
  /// In en, this message translates to:
  /// **'Sad Vibes'**
  String get exploreSad;

  /// No description provided for @exploreSadSub.
  ///
  /// In en, this message translates to:
  /// **'Heart-touching slow songs'**
  String get exploreSadSub;

  /// No description provided for @exploreSadQuery.
  ///
  /// In en, this message translates to:
  /// **'sad heartbroken songs {year}'**
  String exploreSadQuery(Object year);

  /// No description provided for @exploreDance.
  ///
  /// In en, this message translates to:
  /// **'Dance & Party'**
  String get exploreDance;

  /// No description provided for @exploreDanceSub.
  ///
  /// In en, this message translates to:
  /// **'Wake up the fun'**
  String get exploreDanceSub;

  /// No description provided for @exploreDanceQuery.
  ///
  /// In en, this message translates to:
  /// **'dance songs {year} party'**
  String exploreDanceQuery(Object year);

  /// No description provided for @exploreConcert.
  ///
  /// In en, this message translates to:
  /// **'Hit Concerts'**
  String get exploreConcert;

  /// No description provided for @exploreConcertSub.
  ///
  /// In en, this message translates to:
  /// **'Ultimate live performances'**
  String get exploreConcertSub;

  /// No description provided for @exploreConcertQuery.
  ///
  /// In en, this message translates to:
  /// **'live concert performance'**
  String get exploreConcertQuery;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'User Statistics'**
  String get adminDashboardTitle;

  /// No description provided for @adminUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get adminUser;

  /// No description provided for @adminLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get adminLastSeen;

  /// No description provided for @adminLoadingUsers.
  ///
  /// In en, this message translates to:
  /// **'Loading user statistics...'**
  String get adminLoadingUsers;

  /// No description provided for @adminErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading users: {error}'**
  String adminErrorLoading(String error);

  /// No description provided for @adminLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'mPlay System Admin'**
  String get adminLoginTitle;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @adminUsedTimePrefix.
  ///
  /// In en, this message translates to:
  /// **'Used: {time}'**
  String adminUsedTimePrefix(String time);

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTitle;

  /// No description provided for @exploreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find the perfect music for your mood'**
  String get exploreSubtitle;

  /// No description provided for @downloadSong.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadSong;

  /// No description provided for @downloadingSong.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloadingSong;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete! Added to Local Files'**
  String get downloadComplete;

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again'**
  String get downloadError;

  /// No description provided for @alreadyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Already downloaded'**
  String get alreadyDownloaded;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
