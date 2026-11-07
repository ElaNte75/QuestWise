"""Turns a folder of sound files into the addon's sounds. The sounds themselves are NOT edited
(no cutting, no trimming, no fades, same channels and sample rate): only the volume changes.

Usage:  python -I process_sounds.py <folder with source sounds> <addon folder>

For every source file it writes Sounds/<Key>_<volume>.ogg for each volume step (10..100), where
50 = the same loudness for all sounds (as far as the sound's own peaks allow without clipping)
and 100 = twice as loud (peaks are gently limited so it never clips).
Also writes Sounds/SoundList.lua (the list the addon shows). Needs numpy + soundfile.
This script is a helper and is not loaded by the game.
"""
import hashlib
import io
import os
import sys

import numpy as np
import soundfile as sf

src_dir, addon_dir = sys.argv[1], sys.argv[2]
out_dir = os.path.join(addon_dir, "Sounds")
os.makedirs(out_dir, exist_ok=True)

TARGET_DB = -17.0           # loudness of every sound at 100%
CEILING = 0.85              # never louder than this peak (leaves room for the ogg encoder's overshoot)
LEVELS = list(range(10, 101, 10))

# source file name -> (key used in file names, label shown in the options)
NAMES = {
    "AlarmClockWarning1.ogg": ("AlarmClock", "Alarm Clock"),
    "AuctionWindowOpen.ogg": ("AuctionOpen", "Auction Open"),
    "DwarfMaleLaugh01.ogg": ("DwarfLaugh", "Dwarf Laugh"),
    "FriendJoin.ogg": ("FriendJoin", "Friend Join"),
    "iPlayerInviteA.ogg": ("PlayerInvite", "Player Invite"),
    "iQuestActivate.ogg": ("QuestActivate", "Quest Activate"),
    "iQuestComplete.ogg": ("QuestComplete", "Quest Complete"),
    "iTellMessage.ogg": ("Whisper", "Whisper"),
    "Jobs Done.FLAC": ("JobsDone", "Jobs Done"),
    "levelup2.ogg": ("LevelUp", "Level Up"),
    "LFG_RoleCheck.ogg": ("RoleCheck", "Role Check"),
    "LootCoinSmall.ogg": ("LootCoin", "Loot Coin"),
    "PVPThroughQueue.ogg": ("PvpQueue", "PvP Queue"),
    "RaidWarning.ogg": ("RaidWarning", "Raid Warning"),
    "VO_735_PC_-_Lightforged_Draenei_Male_188_M.ogg": ("DraeneiVoice", "Draenei Voice"),
}


def limit(data, sr, ceiling=CEILING, ms=15):
    """Keeps peaks under the ceiling by turning the volume down smoothly around them
    (only touches the moments that would be too loud; everything else stays as it is)."""
    w = max(int(sr * ms / 1000), 1)
    env = np.max(np.abs(data), axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(env, 1e-9))
    if need.min() >= 1.0:
        return data
    pad = np.pad(need, (w, w), mode="edge")
    mins = np.lib.stride_tricks.sliding_window_view(pad, 2 * w + 1).min(axis=1)
    kernel = np.ones(2 * w + 1) / (2 * w + 1)
    smooth = np.convolve(np.pad(mins, (w, w), mode="edge"), kernel, mode="valid")
    return data * smooth[: len(data), None]


def gated_rms(y, sr):
    """Loudness of the part that actually has sound (quiet gaps are ignored)."""
    n = int(sr * 0.05)
    frames = [y[i:i + n] for i in range(0, len(y) - n, n)] or [y]
    levels = np.array([np.sqrt(np.mean(f ** 2)) for f in frames])
    keep = levels >= 0.1 * levels.max()
    sq = np.concatenate([f ** 2 for f, k in zip(frames, keep) if k])
    return float(np.sqrt(np.mean(sq)))


seen = {}
entries = []
rows = []
for fname in sorted(os.listdir(src_dir)):
    path = os.path.join(src_dir, fname)
    if fname not in NAMES:
        print("skipped (no name given): %s" % fname)
        continue
    digest = hashlib.md5(open(path, "rb").read()).hexdigest()
    if digest in seen:
        print("skipped (identical to %s): %s" % (seen[digest], fname))
        continue
    seen[digest] = fname

    data, sr = sf.read(path, always_2d=True)       # every channel kept as it is
    peak = float(np.max(np.abs(data)))
    want = (10 ** (TARGET_DB / 20)) / gated_rms(data.mean(axis=1), sr)
    gain = min(want, CEILING / peak)               # only volume; never distorts
    key, label = NAMES[fname]
    for lvl in LEVELS:
        # 50 = the "same loudness" level; above 50 it gets louder (100 = twice as loud)
        louder = limit(data * gain * lvl / 50.0, sr)
        # the ogg encoder can overshoot a little: encode, measure, and turn down if it ends up above 1
        scale = 1.0
        for _ in range(6):
            buf = io.BytesIO()
            sf.write(buf, (louder * scale).astype(np.float32), sr, format="OGG", subtype="VORBIS")
            buf.seek(0)
            back, _sr = sf.read(buf)
            peak_after = float(np.max(np.abs(back)))
            if peak_after <= 0.98:
                break
            scale *= 0.96 / peak_after
        with open(os.path.join(out_dir, "%s_%d.ogg" % (key, lvl)), "wb") as fh:
            fh.write(buf.getvalue())
    entries.append((label, key))
    rows.append("%-14s %.2fs ch=%d  gain %+.1f dB%s" % (
        key, len(data) / sr, data.shape[1], 20 * np.log10(gain),
        "" if gain >= want * 0.999 else "  (its peaks keep it %.1f dB quieter than the target)" % (20 * np.log10(want / gain))))

entries.sort()
with open(os.path.join(out_dir, "SoundList.lua"), "w", encoding="utf-8") as f:
    f.write("-- GENERATED by _tools/process_sounds.py - do not edit by hand.\n")
    f.write("-- Sounds/<key>_<volume>.ogg exists for every volume in NA.SoundVolumes.\n")
    f.write("local ADDON, NA = ...\n\n")
    f.write("NA.SoundVolumes = { %s }\n" % ", ".join(str(v) for v in LEVELS))
    f.write("NA.SoundList = {\n")
    for label, key in entries:
        f.write('    { key = "%s", label = "%s" },\n' % (key, label))
    f.write("}\n")

print("\n".join(rows))
total = sum(os.path.getsize(os.path.join(out_dir, x)) for x in os.listdir(out_dir) if x.endswith(".ogg"))
print("sounds: %d, ogg files: %d, total: %.1f MB" % (len(entries), len(entries) * len(LEVELS), total / 1048576))
