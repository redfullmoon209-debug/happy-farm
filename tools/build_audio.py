#!/usr/bin/env python3
"""Happy Farm original score and activity effects. Public-domain-equivalent
original synthesis with Python standard library only; no third-party music."""
from __future__ import annotations
import math
import os
import random
import struct
import wave
from pathlib import Path

RATE = 16000
OUT = Path("assets/audio")
OUT.mkdir(parents=True, exist_ok=True)
TAU = 2.0 * math.pi
rand = random.Random(42066)

def hz(midi):
    return 440.0 * 2 ** ((midi - 69.0) / 12.0)

def write(name, duration, fn):
    frames = int(duration * RATE)
    pcm = bytearray(frames * 2)
    for i in range(frames):
        sample = float(fn(i / RATE))
        sample = math.tanh(sample * 0.94)
        if i < 190:
            sample *= i / 190.0
        if i > frames - 360:
            sample *= max(0.0, (frames - i) / 360.0)
        struct.pack_into("<h", pcm, i * 2, int(max(-1.0, min(1.0, sample)) * 32000))
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm)
    print(f"CREATED {name}: {len(pcm)//1024} KiB")

# A gentle 8-bar original farm theme, 96 bpm, C major / Fmaj7 / Am7 / G7.
BEAT = 60.0 / 96.0
BARS = 8
CHORDS = [
    [60, 64, 67, 71], [53, 57, 60, 64],
    [57, 60, 64, 67], [55, 59, 62, 65],
] * 2
BASS = [36, 29, 33, 31] * 2
MELODY = [
    76, 79, 81, 79, 76, 72, 74, 76,
    77, 76, 72, 69, 72, 74, 76, 72,
    76, 79, 81, 84, 81, 79, 76, 74,
    74, 71, 74, 79, 77, 74, 72, None,
]

def e(p, decay):
    return max(0.0, 1.0 - math.exp(-p * 170.0)) * math.exp(-decay * max(0, p))

def music(t):
    bar = min(BARS - 1, int(t // (BEAT * 4.0)))
    bar_phase = t % (4.0 * BEAT)
    chord = CHORDS[bar]
    beat_idx = int(bar_phase / BEAT)
    beat_phase = bar_phase % BEAT
    half_idx = int(bar_phase / (BEAT / 2))
    half_phase = bar_phase % (BEAT / 2)
    eighth = int(t / (BEAT / 2)) % len(MELODY)
    note = MELODY[eighth]
    # A warm background electric-piano pad.
    pad = 0.0
    for key in chord:
        freq = hz(key - 12)
        pad += (math.sin(TAU * freq * t) + 0.14 * math.sin(TAU * 2 * freq * t)) / 4
    pad *= 0.15
    # Soft plucked chords, different chord tone each eighth beat.
    arp_note = chord[[0,2,1,3,2,1,0,2][half_idx]]
    arp_frequency = hz(arp_note)
    arp = 0.12 * e(half_phase, 8.0) * (
        math.sin(TAU * arp_frequency * half_phase) +
        0.18 * math.sin(TAU * arp_frequency * 2 * half_phase)
    )
    # Playful bell melody with alternating short notes and rests.
    lead = 0.0
    if note is not None and eighth % 4 != 3:
        note_freq = hz(note)
        lead = 0.16 * e(half_phase, 6.7) * (
            math.sin(TAU * note_freq * half_phase) +
            0.27 * math.sin(TAU * note_freq * 2.002 * half_phase)
        )
    bass_phase = beat_phase
    bass = 0.20 * e(bass_phase, 3.9) * (
        math.sin(TAU * hz(BASS[bar]) * bass_phase)
        + 0.18 * math.sin(TAU * hz(BASS[bar]) * bass_phase * 2.0)
    ) if beat_idx in [0,2] else 0.0
    # Gentle tick/shaker; deterministic noise makes the loop replay identically.
    hiss = 0.018 * math.exp(-half_phase * 34.0) * (rand.random() * 2 - 1)
    # A distant pair of birds at fixed moments.
    birds = 0.0
    for start in [4.5, 15.1]:
        p = t - start
        if 0 <= p < 0.58:
            f = 900 + 500 * p + 80 * math.sin(TAU * 8 * p)
            birds += 0.045 * math.sin(TAU * f * p) * math.sin(math.pi * p / 0.58) ** 2
    return pad + arp + lead + bass + hiss + birds

write("farm_theme.wav", BARS * 4.0 * BEAT, music)

def till(t):
    hits = 0.0
    for onset in [0.03, 0.20, 0.40]:
        p = t - onset
        if 0 <= p <= 0.16:
            hits += (0.18 * (rand.random() * 2 - 1) +
                     0.14 * math.sin(TAU * (120 - p * 160) * p)) * math.exp(-p * 20.0)
    return hits

def plant(t):
    value = 0.0
    for onset in [0.02, 0.14, 0.25]:
        p = t - onset
        if 0 <= p <= 0.20:
            frequency = 540 - p * 1100
            value += 0.30 * math.sin(TAU * frequency * p) * math.exp(-p * 22.0)
    return value

def water(t):
    p = t
    stream = (rand.random() * 2 - 1) * 0.12 * math.sin(math.pi * min(1, p/0.72)) ** 2
    drips = 0.0
    for onset in [0.07,0.20,0.31,0.48,0.61,0.79]:
        d = p-onset
        if 0 <= d < 0.10:
            drips += 0.13 * math.sin(TAU * (790 - 520 * d) * d) * math.exp(-d * 30)
    return stream + drips

def harvest(t):
    value = 0.0
    for k, (onset, midi) in enumerate(zip([0,.13,.26,.42],[72,76,79,84])):
        p = t - onset
        if 0 <= p < 0.54:
            value += 0.22 * math.sin(TAU * hz(midi) * p) * e(p, 5.8)
            value += 0.045 * math.sin(TAU * hz(midi+12) * p) * e(p, 12.0)
    return value

def coins(t):
    value = 0.0
    for onset, freq in [(0, 1046),(0.18, 1318)]:
        p=t-onset
        if 0 <= p <= 0.36:
            value += 0.25 * (math.sin(TAU*freq*p)+0.35*math.sin(TAU*2.02*freq*p)) * e(p,9.0)
    return value

def pig(t):
    # A funny nasal double-oink, not a sampled animal recording.
    value=0.0
    for onset in [0.02,0.27]:
        p=t-onset
        if 0 <= p < 0.25:
            hz0=170+58*math.sin(p*20)
            value += 0.23 * math.sin(TAU*hz0*p) * (1+0.38*math.sin(TAU*230*p)) * math.sin(math.pi*p/0.25)
    return value

def jump(t):
    freq=170+330*min(1,t/0.23)
    return 0.23*math.sin(TAU*freq*t) * math.exp(-t*8)

def footstep(t):
    return (rand.random()*2-1)*0.13*math.exp(-t*35)+0.06*math.sin(TAU*87*t)*math.exp(-t*21)

for name, duration, func in [
    ("fx_till.wav",0.62,till),
    ("fx_plant.wav",0.48,plant),
    ("fx_water.wav",0.98,water),
    ("fx_harvest.wav",1.15,harvest),
    ("fx_coin.wav",0.68,coins),
    ("fx_pig.wav",0.64,pig),
    ("fx_jump.wav",0.32,jump),
    ("fx_step.wav",0.21,footstep),
]:
    write(name, duration, func)
