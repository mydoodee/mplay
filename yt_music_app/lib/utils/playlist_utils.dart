import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/song_provider.dart';
import '../l10n/app_localizations.dart';

class PlaylistUtils {
  static void showAddToPlaylistSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer<SongProvider>(
          builder: (ctx, provider, child) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF444444),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.addToPlaylist,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFFF15A24),
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.createNewPlaylist,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showCreatePlaylistDialog(context, provider, song: song);
                    },
                  ),

                  const Divider(color: Color(0xFF2A2A2A)),

                  Flexible(
                    child: provider.playlists.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.noPlaylists,
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = provider.playlists[index];
                              return ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252525),
                                    borderRadius: BorderRadius.circular(8),
                                    image:
                                        playlist.songs.isNotEmpty &&
                                            playlist.songs[0].thumbnail !=
                                                "NA" &&
                                            playlist
                                                .songs[0]
                                                .thumbnail
                                                .isNotEmpty
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(
                                              playlist.songs[0].thumbnail,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      (playlist.songs.isEmpty ||
                                          playlist.songs[0].thumbnail == "NA" ||
                                          playlist.songs[0].thumbnail.isEmpty)
                                      ? const Center(
                                          child: Icon(
                                            Icons.queue_music_rounded,
                                            color: Color(0xFF777777),
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  playlist.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  AppLocalizations.of(context)!.songCount(playlist.songs.length),
                                  style: const TextStyle(
                                    color: Color(0xFFAAAAAA),
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await provider.addSongToPlaylist(
                                    playlist.id,
                                    song,
                                  );
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.addedToPlaylist(playlist.name),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: const Color(0xFFF15A24),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static void showCreatePlaylistDialog(
    BuildContext context,
    SongProvider provider, {
    Song? song,
  }) {
    final TextEditingController controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.createNewPlaylist,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.playlistNameHint,
            hintStyle: const TextStyle(color: Color(0xFF666666)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF15A24)),
            ),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) =>
              _handleCreateSubmit(ctx, context, provider, controller, song),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Color(0xFF777777)),
            ),
          ),
          TextButton(
            onPressed: () =>
                _handleCreateSubmit(ctx, context, provider, controller, song),
            child: Text(
              l10n.create,
              style: const TextStyle(color: Color(0xFFF15A24)),
            ),
          ),
        ],
      ),
    );
  }

  static void _handleCreateSubmit(
    BuildContext dialogContext,
    BuildContext screenContext,
    SongProvider provider,
    TextEditingController controller,
    Song? song,
  ) async {
    final name = controller.text.trim();
    if (name.isNotEmpty) {
      // Close dialog immediately to prevent lag or white screen redraws
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      
      // 1. Create playlist
      await provider.createNewPlaylist(name);

      // 2. If song is provided, add it to the newly created playlist
      if (song != null) {
        // Find the new playlist (it will be the first one as they are sorted by created_at DESC)
        if (provider.playlists.isNotEmpty) {
          final newPlaylistId = provider.playlists.first.id;
          await provider.addSongToPlaylist(newPlaylistId, song);

          if (screenContext.mounted) {
            ScaffoldMessenger.of(screenContext).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(screenContext)!.createdAndAdded(name),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: const Color(0xFFF15A24),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    }
  }
}
