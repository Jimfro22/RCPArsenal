# User-provided Arsenal alert sounds

These six audio files were supplied by the user for transformation/integration. Provenance is **user-provided**; no authorship, public-domain or license claim is made here. Downloads originals remain untouched, and exact byte-for-byte copies are retained in sources/. Neutral labels Sound1–Sound6 preserve the supplied ordering until the owner names them.

Runtime exports are **Ogg Vorbis (not Opus), stereo, 44,100 Hz**, encoded with libvorbis VBR quality5. There is no gain adjustment, normalization, remix, intentional trim, fade, synthesis or sound redesign. Existing source-level differences are preserved. Original synthesized retro cues in the other output folder are evidence only and are superseded for runtime selection.

| Label | Original filename | Runtime file | Container duration | Decoded peak | Decoded RMS | RMS change |
| --- | --- | --- | --- | --- | --- | --- |
| Sound1 | Sound 1.mp3 | RCP_Sound01.ogg | 0.629569 s | -15.354 dBFS | -22.494 dBFS | 0.044 dB |
| Sound2 | Sound 2.mp3 | RCP_Sound02.ogg | 0.804331 s | -1.712 dBFS | -10.259 dBFS | 0.012 dB |
| Sound3 | Sound 3.mp3 | RCP_Sound03.ogg | 0.234807 s | -10.748 dBFS | -19.307 dBFS | 0.039 dB |
| Sound4 | Sound 04.mp3 | RCP_Sound04.ogg | 0.43102 s | -9.039 dBFS | -22.069 dBFS | 0.059 dB |
| Sound5 | Sound 05.mp3 | RCP_Sound05.ogg | 0.547392 s | -8.596 dBFS | -24.361 dBFS | -0.216 dB |
| Sound6 | Sound 06.mp3 | RCP_Sound06.ogg | 0.601519 s | -8.461 dBFS | -21.937 dBFS | 0.063 dB |

## Conversion and verification

The local Plex Transcoder supplies the verified FFmpeg/libvorbis encoder. Its build has no MP3 decoder, so native macOS /usr/bin/afconvert decoded each source copy into floating-point stereo PCM without a gain/filter operation. In this environment the macOS decoder needed approved execution outside the sandbox; the sandboxed attempt failed before conversion. No dependency installation was required. Decoded PCM files and their hashes are retained in decoded/.

prepare_user_audio.py records source/copy/PCM/export hashes, decoder/encoder versions and commands, Ogg Vorbis header verification, container granule duration, decoded duration/peak/RMS/out-of-range counts and repeat-encode verification in manifest.json. All source copies match Downloads originals. All six runtime files decode with zero out-of-range/full-scale-clipped float samples. Repeat encoding produces identical OGG bytes. Source and Ogg decoded durations can reflect codec priming/padding; container granule duration and decoded frame counts are recorded separately.

To reproduce exports from the retained PCM intermediates, run python3 prepare_user_audio.py in this folder. To regenerate the PCM intermediates from preserved MP3 copies, add --decode-again with native decoder execution available. An alternate verified FFmpeg/libvorbis executable can be supplied with --encoder. Encoder version/build output is preserved in encoder-version.txt. No original file is written by the script.

## Engineering handoff

Copy only RCP_Sound01.ogg through RCP_Sound06.ogg into the addon runtime media location, with exact filenames/case. asset-handoff.json supplies absolute source paths and suggested destinations. Preserve the source copies, script and manifest as provenance outside the shipped runtime audio folder. Do not describe these supplied recordings as newly authored synthetic audio.

Native WoW playback, output-channel/mute behavior and owner listening acceptance remain pending. File/codec/level checks establish export properties, not native audibility or perceived quality.

## Source checkout record

Only the six runtime Ogg files, this record, the exact conversion script, encoder build record and manifest are copied into this source checkout. MP3 copies and decoded PCM intermediates remain in the retained original handoff folder recorded by the manifest and are not included in the install ZIP. To reproduce, copy the script into a working directory with those sources/ and decoded/ folders, then follow the conversion instructions above. The absolute handoff paths in the unchanged manifest document the original transformation run.
