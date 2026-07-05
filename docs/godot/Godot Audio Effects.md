# Audio effects

Godot includes several audio effects that can be added to an audio bus to alter every sound file that goes through that bus.

![../../_images/audio_buses4.webp](https://docs.godotengine.org/en/stable/_images/audio_buses4.webp)

Try them all out to get a sense of how they alter sound. Here follows a short description of the available effects:

## Amplify[](#amplify "Link to this heading")

Amplify changes the volume of the signal. Some care needs to be taken, though: setting the level too high can make the sound digitally clip, which can produce unpleasant crackles and pops.

## BandLimit and BandPass[](#bandlimit-and-bandpass "Link to this heading")

These are resonant filters which block frequencies around the *Cutoff* point. BandPass can be used to simulate sound passing through an old telephone line or megaphone. Modulating the BandPass frequency can simulate the sound of a wah-wah guitar pedal, think of the guitar in Jimi Hendrix's *Voodoo Child (Slight Return)*.

## Capture[](#capture "Link to this heading")

The Capture effect copies the audio frames of the audio bus that it is on into an internal buffer. This can be used to capture data from the microphone or to transmit audio over the network in real-time.

## Chorus[](#chorus "Link to this heading")

As the name of the effect implies, the Chorus effect makes a single audio sample sound like an entire chorus. It does this by duplicating a signal and very slightly altering the timing and pitch of each duplicate, and varying that over time via an LFO (low frequency oscillator). The duplicate(s) are then mixed back together with the original signal, producing a lush, wide, and large sound. Although chorus is traditionally used for voices, it can be desirable with almost any type of sound.

## Compressor[](#compressor "Link to this heading")

A dynamic range compressor automatically attenuates (ducks) the level of the incoming signal when its amplitude exceeds a certain threshold. The level of attenuation applied is proportional to how far the incoming audio exceeds the threshold. The compressor's Ratio parameter controls the degree of attenuation. One of the main uses of a compressor is to reduce the dynamic range of signals with very loud and quiet parts. Reducing the dynamic range of a signal can make it fit more comfortably in a mix.

The compressor has many uses. For example:

*   It can be used in the Master bus to compress the whole output prior to being hit by a limiter, making the effect of the limiter much more subtle.
    
*   It can be used in voice channels to ensure they sound as even as possible.
    
*   It can be *sidechained* by another sound source. This means it can reduce the sound level of one signal using the level of another audio bus for threshold detection. This technique is very common in video game mixing to "duck" the level of music or sound effects when in-game or multiplayer voices need to be fully audible.
    
*   It can accentuate transients by using a slower attack. This can make sound effects more punchy.
    

Note

If your goal is to prevent a signal from exceeding a given amplitude altogether, rather than to reduce the dynamic range of the signal, a [limiter](#doc-audio-buses-limiter) is likely a better choice than a compressor for this purpose. However, applying compression before a limiter is still good practice.

## Delay[](#delay "Link to this heading")

Digital delay essentially duplicates a signal and repeats it at a specified speed with a volume level that decays for each repeat. Delay is great for simulating the acoustic space of a canyon or large room, where sound bounces have a lot of *delay* between their repeats. This is in contrast to reverb, which has a more natural and blurred sound to it. Using this in conjunction with reverb can create very natural sounding environments!

## Distortion[](#distortion "Link to this heading")

Makes the sound distorted. Godot offers several types of distortion:

*   *Overdrive* sounds like a guitar distortion pedal or megaphone. Sounds distorted with this sound like they're coming through a low-quality speaker or device.
    
*   *Tan* sounds like another interesting flavor of overdrive.
    
*   *Bit crushing* clamps the amplitude of the signal, making it sound flat and crunchy.
    

All three types of distortion can add higher frequency sounds to an original sound, making it stand out better in a mix.

## EQ[](#eq "Link to this heading")

EQ is what all other equalizers inherit from. It can be extended with Custom scripts to create an equalizer with a custom number of bands.

## EQ6, EQ10, EQ21[](#eq6-eq10-eq21 "Link to this heading")

Godot provides three equalizers with different numbers of bands, which are represented in the title (6, 10, and 21 bands, respectively). An equalizer on the Master bus can be useful for cutting low and high frequencies that the device's speakers can't reproduce well. For example, phone or tablet speakers usually don't reproduce low frequency sounds well, and could make a limiter or compressor attenuate sounds that aren't even audible to the user anyway.

Note: The equalizer effect can be disabled when headphones are plugged in, giving the user the best of both worlds.

## Filter[](#filter "Link to this heading")

Filter is what all other filters inherit from and should not be used directly.

## HardLimiter[](#hardlimiter "Link to this heading")

A limiter is similar to a compressor, but it's less flexible and designed to prevent a signal's amplitude exceeding a given dB threshold. Adding a limiter to the final point of the Master bus is good practice, as it offers an easy safeguard against clipping.

## HighPassFilter[](#highpassfilter "Link to this heading")

Cuts frequencies below a specific *Cutoff* frequency. HighPassFilter is used to reduce the bass content of a signal.

## HighShelfFilter[](#highshelffilter "Link to this heading")

Reduces all frequencies above a specific *Cutoff* frequency.

## Limiter[](#limiter "Link to this heading")

This is the old limiter effect, and it is recommended to use the new HardLimiter effect instead.

Here is an example of how this effect works, if the ceiling is set to -12 dB, and the threshold is 0 dB, all samples going through get reduced by 12dB. This changes the waveform of the sound and introduces distortion.

This effect is being kept to preserve compatibility, however it should be considered deprecated.

## LowPassFilter[](#lowpassfilter "Link to this heading")

Cuts frequencies above a specific *Cutoff* frequency and can also resonate (boost frequencies close to the *Cutoff* frequency). Low pass filters can be used to simulate "muffled" sound. For instance, underwater sounds, sounds blocked by walls, or distant sounds.

## LowShelfFilter[](#lowshelffilter "Link to this heading")

Reduces all frequencies below a specific *Cutoff* frequency.

## NotchFilter[](#notchfilter "Link to this heading")

The opposite of the BandPassFilter, it removes a band of sound from the frequency spectrum at a given *Cutoff* frequency.

## Panner[](#panner "Link to this heading")

The Panner allows the stereo balance of a signal to be adjusted between the left and right channels. Headphones are recommended when configuring in this effect.

## Phaser[](#phaser "Link to this heading")

This effect is formed by de-phasing two duplicates of the same sound so they cancel each other out in an interesting way. Phaser produces a pleasant whooshing sound that moves back and forth through the audio spectrum, and can be a great way to create sci-fi effects or Darth Vader-like voices.

## PitchShift[](#pitchshift "Link to this heading")

This effect allows the adjustment of the signal's pitch independently of its speed. All frequencies can be increased/decreased with minimal effect on transients. PitchShift can be useful to create unusually high or deep voices. Do note that altering pitch can sound unnatural when pushed outside of a narrow window.

## Record[](#record "Link to this heading")

The Record effect allows the user to record sound from a microphone.

## Reverb[](#reverb "Link to this heading")

Reverb simulates rooms of different sizes. It has adjustable parameters that can be tweaked to obtain the sound of a specific room. Reverb is commonly outputted from [Area3Ds](https://docs.godotengine.org/en/stable/classes/class_area3d.html#class-area3d) (see [Reverb buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html#doc-audio-streams-reverb-buses)), or to apply a "chamber" feel to all sounds.

## SpectrumAnalyzer[](#spectrumanalyzer "Link to this heading")

This effect doesn't alter audio, instead, you add this effect to buses you want a spectrum analysis of. This would typically be used for audio visualization. Visualizing voices can be a great way to draw attention to them without just increasing their volume. A demo project using this can be found [here](https://github.com/godotengine/godot-demo-projects/tree/master/audio/spectrum).

## StereoEnhance[](#stereoenhance "Link to this heading")

This effect uses a few algorithms to enhance a signal's stereo width.