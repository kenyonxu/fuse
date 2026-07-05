This page covers all there is to know about the MMAudioAnalyzer, a great tool to sync things to audio in your game

*   [What’s MMAudioAnalyzer?](#whats-mmaudioanalyzer)[](#whats-mmaudioanalyzer)
*   [Computing Normalized Values](#computing-normalized-values)[](#computing-normalized-values)
*   [Levels](#levels)[](#levels)
*   [Beats](#beats)[](#beats)
*   [Using these values](#using-these-values)[](#using-these-values)
*   [WebGL Limitations](#webgl-limitations)[](#webgl-limitations)

If you’ve ever wanted to **synchronize** movement, scale, events, or anything else to your game’s **soundtrack**, chances are you’ll find **MMAudioAnalyzer** interesting. It’s a component that you can put on an object in your scene, and that you can bind to an audio source, your entire scene’s soundtrack, or even the microphone, and it’ll analyze the sound for you and will give you hooks to use that data. In the video above you can see it in action, it even comes with fully customizable **visualization tools**.

From its inspector you’ll be able to define what audio source (AudioSource, Global or Microphone) to listen to, the sampling interval, samples and window (smaller interval is more costly, more samples is more costly). Unless you have **very specific needs**, it’s probably best to leave these three to their default values. Then you can define the number of bands, which defines in how many pieces the spectrum will be cut. Each band can then be analyzed separately. The more bands you have, the easier it’ll be to isolate specific information, but the more costly it’ll be. For most purposes, somewhere between 1 and 8 should be enough.

At runtime, if your sound is playing, you’ll be able to see the raw visualization of these bands, and a normalized version of them. To use normalized values on audio sources, there’s a little process to do first, as the system has to parse your entire source at runtime. Press play, and when your sound is playing, press the **Find Peaks** button at the bottom of the inspector. Your track will play at high speed. Once it’s done, exit play mode, and press the Paste Peaks button. That’s it, you can now enjoy normalized values too.

![Jekyll](https://feel-docs.moremountains.com/images/mmaudioanalyzer-1.png)

The MMAudioAnalyzer's levels at runtime

From the **MMAudioAnalyzer’s inspector**, at runtime, you can unfold the **Levels** panel. This will give you the exact values for global audio values, and for each band you’ve defined. Each of these is a float we can use from other classes to drive the movement of an object, trigger events, and more. This panel lets you see how each of these floats evolve and what their exact values are.

*   **Amplitude** : the current level (basically its volume) of the sound at this specific frame
*   **Normalized** : that same level, but normalized between 0 and 1, 0 being no sound at all, and 1 being the maximum amplitude of the sound over its whole duration
*   **Buffered Amplitude** : an interpolated value moving towards the current level of the sound. It basically “moves” slower than the real value, giving smoother movement when binding something to it. The speed at which buffered values move is defined by the **Buffer Speed** setting.
*   **Normalized Buffered Amplitude** : the normalized value, but buffered like the one above

You’ll find these 4 values for the global sound, and for each of the bands.

Let’s say you’ve got a song playing in the background, and want to trigger a flash every time the drum crash cymbal plays (which is the use case of the Brass demo scene). If you have separate tracks playing for each elements of your drums, that’s fairly easy. If you have a single .wav file for your whole track, that’s a bit trickier. You could hardcode the times at which the crash cymbal plays, but what if you change your track? That’s where Beats come in handy.

The MMAudioAnalyzer lets you define an array of **Beats**. Each Beat is made of a name and color (purely for organization purposes), a mode (the ones above, plus raw values). Then you’ll need to define a threshold. This is the most important value, as that’s what triggers the Beat. In our use case above, we can look at our 8 bands visualization in the inspector, and try to find patterns that happen every time the sound we’re after plays. In the case of the Brass demo, we can see that Band#2 gets significantly higher every time the crash cymbal plays. We can then set our Band ID to 2, and adjust our threshold so that every time the band’s value goes over it, an event will fire. A bit of trial and error usually helps adjust it. The Beats Visualization will “turn on lights” to show you how and when the values fire. These Beats can be used to fire events (when the value goes over the threshold, going up), or can also be looked at like individual floats (that’s what the Beats Visualization reflects). You can choose to have these values remapped, and define a minimum time between beats as a safety measure.

For each beat, the inspector will let you bind **Unity Events**. This can be a good way to trigger Feedbacks every time a certain sound plays.

**MMAudioAnalyzer values** can be accessed in multiple ways. The most common would be via script. Using a reference to your MMAudioAnalyzer, you can do things like :

```
TargetLight.intensity = TargetAnalyzer.NormalizedBufferedAmplitude * 5f;
```

which will set the intensity of a light to match the current amplitude of the soundtrack. You can see that same line in action in the Brass demo, in the FeelBrass component. You can access all the values of the MMAudioAnalyzer in that same way. For example :

```
TargetAnalyzer.Beats[0].CurrentValue
```

will give you the current value of the first beat you’ve declared. Likewise you can access buffered amplitude, regular amplitude, and all other values for each band and beat.

Other classes in Feel will occasionally have built-in hooks for the MMAudioAnalyzer. For example, both the **Float Controller** and the **Shader Controller** have MMAudioAnalyzer modes, that will let you define what band or beat you want to listen to to drive your values. You’ll find an example of the Float Controller used in such a way in the Brass demo scene, on the *VisualizerBlocks*. The ShaderController is used on the *RightBlock* in that same scene. You can also use the [MMRadio system](https://feel-docs.moremountains.com/mmradio.html) with the MMAudioAnalyzer, that’s how the *GroundBlocks* in the Brass demo move, with a single emitter, and a receiver on each block. And finally, there’s always the option to directly bind events to each Beat from the **MMAudioAnalyzer**’s inspector itself.

**All of these should give you plenty of different ways to read sound and synchronize your game to it.**

The MMAudioAnalyzer uses the FMOD API, including the GetSpectrumData method to get audio data at runtime. Unfortunately, [Unity doesn’t support these APIs on WebGL](https://docs.unity3d.com/Manual/webgl-audio.html), so you won’t be able to use the analyzer on WebGL builds. You’ll be fine on all other platforms Unity supports.