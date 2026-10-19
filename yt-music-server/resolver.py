#!/usr/bin/env python3
"""
M-PLAY persistent yt-dlp worker (v82)
-------------------------------------
Keeps yt-dlp imported and warm in memory so each request does NOT pay
Python startup + module import + player-JS cache cost (~1-5s on QNAP).

Protocol: JSON Lines over stdin/stdout
  -> {"id": 1, "op": "resolve", "videoId": "xxxx"}
  <- {"id": 1, "ok": true, "url": "...", "isLive": false, "isHls": false, "duration": 213}

  -> {"id": 2, "op": "search", "query": "...", "offset": 0, "limit": 20}
  <- {"id": 2, "ok": true, "results": [ {id,title,artist,duration,thumbnail,isLive}, ... ]}

stdout is reserved for protocol messages; all yt-dlp output is silenced.
"""
import json
import sys
import os

os.environ.setdefault("PYTHONIOENCODING", "utf-8")

import yt_dlp  # noqa: E402  (import after env setup on purpose)

FORMAT = os.environ.get("YTDLP_FORMAT", "bestaudio/best")


class _NullLogger:
    def debug(self, msg):
        pass

    def info(self, msg):
        pass

    def warning(self, msg):
        pass

    def error(self, msg):
        pass


BASE_OPTS = {
    "quiet": True,
    "no_warnings": True,
    "noprogress": True,
    "skip_download": True,
    "noplaylist": True,
    "nocheckcertificate": True,
    "socket_timeout": 10,
    "logger": _NullLogger(),
    "extractor_args": {"youtube": {"player_client": ["android", "web", "mweb"]}},
    # NOTE: cache dir is left enabled on purpose — caching the YouTube
    # player JS is a big part of the speed-up.
}

_resolver = yt_dlp.YoutubeDL({**BASE_OPTS, "format": FORMAT})


def _resolve(video_id):
    info = _resolver.extract_info(
        f"https://www.youtube.com/watch?v={video_id}", download=False
    )
    live_status = info.get("live_status") or ""
    is_live = bool(info.get("is_live")) or live_status in ("is_live", "is_upcoming")
    url = info.get("url") or ""
    protocol = info.get("protocol") or ""
    if not url and info.get("requested_formats"):
        url = info["requested_formats"][0].get("url") or ""
    if not url:
        raise RuntimeError("no url")
    return {
        "url": url,
        "isLive": is_live,
        "isHls": bool(is_live and "m3u8" in protocol),
        "duration": int(info.get("duration") or 0),
    }


def _thumb(entry, vid):
    t = entry.get("thumbnail")
    if isinstance(t, str) and t.startswith("http"):
        return t
    thumbs = entry.get("thumbnails") or []
    for th in reversed(thumbs):
        u = th.get("url") if isinstance(th, dict) else None
        if isinstance(u, str) and u.startswith("http"):
            return u
    return f"https://i.ytimg.com/vi/{vid}/mqdefault.jpg"


def _search(query, offset, limit):
    is_url = "youtube.com/" in query or "youtu.be/" in query
    target = query if is_url else f"ytsearch{offset + limit}:{query}"
    opts = {
        **BASE_OPTS,
        "extract_flat": "in_playlist",
        "noplaylist": False,
        "playliststart": offset + 1,
        "playlistend": offset + limit,
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(target, download=False)

    entries = info.get("entries")
    if entries is None:
        entries = [info]  # single video URL
    results = []
    for e in entries:
        if not e:
            continue
        vid = (e.get("id") or "").strip()
        if not vid:
            continue
        duration = e.get("duration")
        results.append(
            {
                "id": vid,
                "title": e.get("title") or "ไม่ระบุชื่อเพลง",
                "artist": e.get("channel") or e.get("uploader") or "ไม่ระบุชื่อศิลปิน",
                "duration": int(duration or 0),
                "thumbnail": _thumb(e, vid),
                "isLive": not duration or e.get("live_status") == "is_live",
            }
        )
    return results


def _reply(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main():
    _reply({"id": 0, "ok": True, "ready": True, "version": yt_dlp.version.__version__})
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        req_id = None
        try:
            req = json.loads(line)
            req_id = req.get("id")
            op = req.get("op")
            if op == "resolve":
                _reply({"id": req_id, "ok": True, **_resolve(req["videoId"])})
            elif op == "search":
                results = _search(
                    req["query"],
                    max(int(req.get("offset", 0)), 0),
                    max(min(int(req.get("limit", 20)), 50), 1),
                )
                _reply({"id": req_id, "ok": True, "results": results})
            elif op == "ping":
                _reply({"id": req_id, "ok": True})
            else:
                _reply({"id": req_id, "ok": False, "error": f"unknown op {op}"})
        except Exception as e:  # never die on a single bad request
            _reply({"id": req_id, "ok": False, "error": str(e)[:300]})


if __name__ == "__main__":
    main()
