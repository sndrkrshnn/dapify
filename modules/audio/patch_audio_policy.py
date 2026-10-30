#!/usr/bin/env python3
"""Patch a stock Android audio_policy_configuration.xml for hi-res / native-rate
wired playback.

This is the general form of the verified kenzo patch. Stock QCOM audio policy
files advertise only 48 kHz on the primary / raw / deep-buffer mix ports and a
single 16-bit / 48 kHz profile on the wired output device ports, so even 44.1 kHz
FLAC is resampled by AudioFlinger and a 24-bit / 192 kHz track is downsampled to
16 / 48. The codec on these SoCs (WCD93xx on 845 and older, WSA88xx on 845)
supports the full hi-res range natively; advertising it lets AudioFlinger open
the mixer and the direct PCM path at the source rate.

What it does (idempotent, safe to re-run):

  * mix ports "primary output", "raw", "deep_buffer" (and the Speaker / Earpiece
    device ports) advertise 44100 in addition to 48000.
  * the wired output device ports ("Wired Headset", "Wired Headphones", "Line")
    advertise 16-bit and 24-bit PCM at 44.1, 48, 88.2, 96, 176.4 and 192 kHz,
    matching the existing direct_pcm mix port. This is what lets a direct-output
    player (Poweramp / Neutron / UAPP / just_audio in raw mode) use the codec at
    its native rate instead of 16 / 48.

Usage:
  patch_audio_policy.py <stock.xml> <out.xml>

The script only edits the sampling-rate lists and the wired device-port profiles
above; everything else (routes, volumes, A2DP/USB includes) is left untouched.
If a block it needs is missing (a stock file that already differs), it exits
non-zero rather than writing a half-patched file.
"""
import re
import sys

RATES_441 = "44100,48000"
HIRES_RATES = "44100,48000,88200,96000,176400,192000"

HIRES_PROFILES = (
    '<profile name="" format="AUDIO_FORMAT_PCM_16_BIT"\n'
    '                             samplingRates="{rates}" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>\n'
    '                    <profile name="" format="AUDIO_FORMAT_PCM_24_BIT_PACKED"\n'
    '                             samplingRates="{rates}" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>\n'
    '                    <profile name="" format="AUDIO_FORMAT_PCM_8_24_BIT"\n'
    '                             samplingRates="{rates}" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>'
).format(rates=HIRES_RATES)


def add_rate(text, block_name, old, new, required=True):
    """Replace a sampling-rate list in one named mixPort/devicePort.

    The block name must appear exactly once. If its first profile already
    advertises the target rate (i.e. the file was patched before), the call is a
    no-op and returns the text unchanged, so the whole script is idempotent. If
    the block is absent and required=False, it is skipped.
    """
    if not _has_block(text, block_name):
        if required:
            raise SystemExit(f"missing block {block_name}")
        return text
    if _port_or_mix_rate(text, block_name) == new:
        return text
    pattern = re.compile(
        r'(<(?:mixPort|devicePort)[^>]*(?:name|tagName)="' + re.escape(block_name) +
        r'"[^>]*>.*?samplingRates=")' + re.escape(old) + r'(")',
        re.S,
    )
    out, n = pattern.subn(lambda m: m.group(1) + new + m.group(2), text, count=1)
    if n != 1:
        raise SystemExit(f"could not patch {block_name} ({old} -> {new})")
    return out


def _first_rate(block):
    m = re.search(r'samplingRates="([^"]*)"', block)
    return m.group(1) if m else ""


def _port_or_mix_rate(text, name):
    m = re.search(
        r'<(?:mixPort|devicePort)[^>]*(?:name|tagName)="' + re.escape(name) +
        r'"[^>]*>(.*?)(?:</(?:mixPort|devicePort)>)',
        text, re.S,
    )
    return _first_rate(m.group(1)) if m else ""


def set_wired_profiles(text, tag):
    """Replace the single 16-bit/48k profile of a wired device port with the
    16/24-bit hi-res profile set. Idempotent: if the port already advertises the
    192 kHz hi-res set (already patched), it is left untouched."""
    if f'samplingRates="{HIRES_RATES}"' in _port_block(text, tag):
        return text
    pattern = re.compile(
        r'(<devicePort tagName="' + re.escape(tag) + r'"[^>]*>\s*)'
        r'<profile[^>]*/>(\s*</devicePort>)',
        re.S,
    )
    new, n = pattern.subn(lambda m: m.group(1) + HIRES_PROFILES + m.group(2), text, count=1)
    if n != 1:
        raise SystemExit(f"could not patch devicePort {tag}")
    return new


def _port_block(text, tag):
    pattern = re.compile(
        r'<devicePort tagName="' + re.escape(tag) + r'"[^>]*>(.*?)</devicePort>',
        re.S,
    )
    m = pattern.search(text)
    return m.group(1) if m else ""


def _has_block(text, name):
    return re.search(
        r'<(?:mixPort|devicePort)[^>]*(?:name|tagName)="' + re.escape(name) + r'"',
        text,
    ) is not None


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <stock.xml> <out.xml>")
    src, dst = sys.argv[1], sys.argv[2]
    text = open(src, encoding="utf-8").read()

    for name in ["primary output", "raw", "deep_buffer", "Speaker", "Earpiece"]:
        text = add_rate(text, name, "48000", RATES_441)
    # The multichannel mix port (present on some QCOM builds) is stereo/dynamic;
    # advertising 44.1 as well as 48 keeps a 44.1 source from being resampled on
    # the multichannel route. Newer sdm845 builds replace it with mmap_no_irq /
    # hifi_playback, so only patch it if it exists and advertises 48000.
    text = add_rate(text, "multichannel", "48000", RATES_441, required=False)
    for tag in ["Wired Headset", "Wired Headphones", "Line"]:
        text = set_wired_profiles(text, tag)

    with open(dst, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"wrote {dst}")


if __name__ == "__main__":
    main()
