#!/usr/bin/env python3
"""Preserve six user-provided MP3s and export unchanged-level Ogg Vorbis audio."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import platform
import shlex
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
ENCODER = '/Applications/Plex Media Server.app/Contents/MacOS/Plex Transcoder'
INPUTS = [
    ('Sound 1.mp3', 'a3d0024ef612002ffa0959d773c5f735ad291c69b4f54e13c9b1b9f2cacd89cb'),
    ('Sound 2.mp3', '42fcf6ae262d15795d58a5a1a46db64b9ff2c8bc51fe832ead2e0f72e90a3a9b'),
    ('Sound 3.mp3', 'c21b4bcab67b8f896a8af47c236386fbd09f8fd3f50b4994b9569934ad0dca72'),
    ('Sound 04.mp3', 'af04bd385b45e380eedc8f2013ac10e5853877914d42aa017f9f52d4c5c3f466'),
    ('Sound 05.mp3', 'e57f3206366985ae16d72588b96a68d2c4783b8e3201ea7cd569b6f39eb067e4'),
    ('Sound 06.mp3', '37d521e53d9df09e2d59b62f75b00f40e74a0fdbc536260cfa36197bef7bcc43'),
]


def run(command):
    result = subprocess.run(command, capture_output=True)
    if result.returncode:
        raise RuntimeError(str(result.returncode)+': '+result.stderr.decode(errors='replace'))
    return result.stdout


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def wav_float(path):
    raw = path.read_bytes()
    assert raw[:4] == b'RIFF' and raw[8:12] == b'WAVE'
    position, fmt, data = 12, None, None
    while position+8 <= len(raw):
        tag, size = struct.unpack_from('<4sI', raw, position)
        if tag == b'fmt ': fmt = struct.unpack_from('<HHIIHH', raw, position+8)
        if tag == b'data': data = raw[position+8:position+8+size]
        position += 8+size+(size % 2)
    assert fmt and fmt[0] == 3 and fmt[5] == 32 and data
    return fmt[1], fmt[2], struct.unpack('<'+'f'*(len(data)//4), data)


def levels(samples, channels, rate):
    assert samples and all(math.isfinite(v) for v in samples)
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v*v for v in samples)/len(samples))
    return {'frames': len(samples)//channels, 'duration_seconds': round(len(samples)/channels/rate, 6),
            'peak_dbfs': round(20*math.log10(peak), 3), 'rms_dbfs': round(20*math.log10(rms), 3),
            'out_of_range_float_samples': sum(abs(v) >= 1 for v in samples)}


def ogg_headers(path):
    raw = path.read_bytes()
    position, partial, packets, final = 0, bytearray(), [], 0
    while position < len(raw):
        assert raw[position:position+4] == b'OggS' and raw[position+4] == 0
        count = raw[position+26]; sizes = raw[position+27:position+27+count]
        body = position+27+count
        granule = struct.unpack_from('<Q', raw, position+6)[0]
        if granule != 0xffffffffffffffff: final = granule
        offset = body
        for size in sizes:
            partial.extend(raw[offset:offset+size]); offset += size
            if size < 255:
                if len(packets) < 3: packets.append(bytes(partial))
                partial.clear()
        position = body+sum(sizes)
    assert len(packets) == 3 and packets[0][:7] == b'\x01vorbis'
    assert packets[1][:7] == b'\x03vorbis' and packets[2][:7] == b'\x05vorbis'
    rate = struct.unpack_from('<I', packets[0], 12)[0]
    return {'container': 'Ogg', 'codec': 'Vorbis (not Opus)', 'channels': packets[0][11],
            'sample_rate_hz': rate, 'final_granule_frames': final,
            'container_duration_seconds': round(final/rate, 6)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--encoder', default=ENCODER)
    parser.add_argument('--source-dir', default='/Users/jimfro/Downloads')
    parser.add_argument('--decode-again', action='store_true')
    args = parser.parse_args()
    encoder = str(Path(args.encoder).resolve())
    for folder in ['sources', 'decoded']: (ROOT/folder).mkdir(exist_ok=True)
    version = run([encoder, '-version']).decode()
    assert 'libvorbis' in run([encoder, '-hide_banner', '-encoders']).decode()
    (ROOT/'encoder-version.txt').write_text(version)
    entries = []
    for index, (name, expected_sha) in enumerate(INPUTS, 1):
        original = Path(args.source_dir)/name
        source = ROOT/'sources'/name
        if not source.exists(): shutil.copy2(original, source)
        assert sha(source) == expected_sha, 'Source copy changed'
        if original.exists(): assert sha(original) == expected_sha, 'Original changed'
        stem = 'RCP_Sound'+str(index).zfill(2)
        decoded = ROOT/'decoded'/(stem+'.wav')
        decode_command = ['/usr/bin/afconvert', '-f', 'WAVE', '-d', 'LEF32', str(source), str(decoded)]
        if args.decode_again or not decoded.exists(): run(decode_command)
        channels, rate, input_pcm = wav_float(decoded)
        assert (channels, rate) == (2, 44100), 'Unexpected source audio format'
        source_levels = levels(input_pcm, channels, rate)
        target = ROOT/(stem+'.ogg')
        prefix = [encoder, '-hide_banner', '-nostdin', '-loglevel', 'error', '-y',
                  '-i', str(decoded), '-map', '0:a:0', '-map_metadata', '-1',
                  '-c:a', 'libvorbis', '-q:a', '5', '-threads', '1',
                  '-fflags', '+bitexact', '-flags:a', '+bitexact', '-f', 'ogg']
        command = prefix+[str(target)]; run(command)
        header = ogg_headers(target)
        assert (header['channels'], header['sample_rate_hz']) == (channels, rate)
        assert header['final_granule_frames'] == source_levels['frames']
        raw = run([encoder, '-hide_banner', '-nostdin', '-loglevel', 'error', '-i', str(target),
                   '-map', '0:a:0', '-c:a', 'pcm_f32le', '-f', 'f32le', '-'])
        output_levels = levels(struct.unpack('<'+'f'*(len(raw)//4), raw), channels, rate)
        assert output_levels['out_of_range_float_samples'] == 0, 'Output exceeds PCM full scale; do not silently boost/clip'
        with tempfile.TemporaryDirectory(prefix='repro-', dir=ROOT) as temporary:
            repeated = Path(temporary)/target.name; run(prefix+[str(repeated)])
            identical = sha(repeated) == sha(target)
        assert identical and sha(source) == expected_sha
        if original.exists(): assert sha(original) == expected_sha
        entry = {'id': 'sound'+str(index), 'label': 'Sound'+str(index), 'original': str(original),
                 'source_copy': str(source), 'source_sha256': expected_sha,
                 'source_copy_matches_original': True, 'provenance': 'User-provided audio; authorship/license not asserted',
                 'decoded_pcm': str(decoded), 'decoded_pcm_sha256': sha(decoded),
                 'decode_command': decode_command, 'source_decoded_levels': source_levels,
                 'export': str(target), 'suggested_destination': 'RCPArsenal/Media/Audio/'+target.name,
                 'bytes': target.stat().st_size, 'sha256': sha(target), 'format': header,
                 'vorbis_quality': 5, 'gain_db_applied': 0, 'no_filters_trim_or_remix': True,
                 'encode_command': command, 'shell_command': shlex.join(command),
                 'export_decoded_levels': output_levels,
                 'rms_delta_db': round(output_levels['rms_dbfs']-source_levels['rms_dbfs'], 3),
                 'repeat_encode_byte_identical': identical}
        entries.append(entry)
        print(json.dumps({k:entry[k] for k in ['label','export','sha256','bytes','rms_delta_db']}))
    manifest = {'status':'Six user-provided Ogg Vorbis exports ready; native playback pending',
                'provenance':'User-provided. No authorship, public-domain or license claim is made.',
                'encoder_path':encoder, 'encoder_version':version.splitlines()[0], 'encoder_sha256':sha(Path(encoder)),
                'decoder':'macOS /usr/bin/afconvert to floating-point PCM; '+platform.platform(),
                'decoder_sha256':sha(Path('/usr/bin/afconvert')),
                'decoder_note':'Plex build lacks MP3 decoding. Native afconvert used; sandbox required approved native-decoder execution.',
                'script':str(Path(__file__).resolve()), 'script_sha256':sha(Path(__file__)),
                'originals_untouched':True, 'gain_or_sound_design_changes':False,
                'note':'Source levels differ and are preserved. MP3 framing/priming estimates may differ from gapless decoded duration. Vorbis decode may omit its initial 128-frame priming window; container granule duration is recorded.',
                'files':entries}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__ == '__main__': main()
