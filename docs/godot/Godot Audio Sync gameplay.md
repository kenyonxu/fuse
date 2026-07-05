# Sync the gameplay with audio and music

Work in progress

The content of this page was not yet updated for Godot `4.5` and may be **outdated**. If you know how to improve this page or you can confirm that it's up to date, feel free to [open a pull request](https://github.com/godotengine/godot-docs).

## Introduction[](#introduction "Link to this heading")

In any application or game, sound and music playback will have a slight delay. For games, this delay is often so small that it is negligible. Sound effects will come out a few milliseconds after any play() function is called. For music this does not matter as in most games it does not interact with the gameplay.

Still, for some games (mainly, rhythm games), it may be required to synchronize player actions with something happening in a song (usually in sync with the BPM). For this, having more precise timing information for an exact playback position is useful.

Achieving very low playback timing precision is difficult. This is because many factors are at play during audio playback:

*   Audio is mixed in chunks (not continuously), depending on the size of audio buffers used (check latency in project settings).
    
*   Mixed chunks of audio are not played immediately.
    
*   Graphics APIs display two or three frames late.
    
*   When playing on TVs, some delay may be added due to image processing.
    

The most common way to reduce latency is to shrink the audio buffers (again, by editing the latency setting in the project settings). The problem is that when latency is too small, sound mixing will require considerably more CPU. This increases the risk of skipping (a crack in sound because a mix callback was lost).

This is a common tradeoff, so Godot ships with sensible defaults that should not need to be altered.

The problem, in the end, is not this slight delay but synchronizing graphics and audio for games that require it. Some helpers are available to obtain more precise playback timing.

## Using the system clock to sync[](#using-the-system-clock-to-sync "Link to this heading")

As mentioned before, If you call [AudioStreamPlayer.play()](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html#class-audiostreamplayer-method-play), sound will not begin immediately, but when the audio thread processes the next chunk.

This delay can't be avoided but it can be estimated by calling [AudioServer.get\_time\_to\_next\_mix()](https://docs.godotengine.org/en/stable/classes/class_audioserver.html#class-audioserver-method-get-time-to-next-mix).

The output latency (what happens after the mix) can also be estimated by calling [AudioServer.get\_output\_latency()](https://docs.godotengine.org/en/stable/classes/class_audioserver.html#class-audioserver-method-get-output-latency).

Add these two and it's possible to guess almost exactly when sound or music will begin playing in the speakers during *\_process()*:

var time\_begin
var time\_delay

func \_ready():
	time\_begin \= Time.get\_ticks\_usec()
	time\_delay \= AudioServer.get\_time\_to\_next\_mix() + AudioServer.get\_output\_latency()
	$Player.play()

func \_process(delta):
	\# Obtain from ticks.
	var time \= (Time.get\_ticks\_usec() \- time\_begin) / 1000000.0
	\# Compensate for latency.
	time \-= time\_delay
	\# May be below 0 (did not begin yet).
	time \= max(0, time)
	print("Time is: ", time)

In the long run, though, as the sound hardware clock is never exactly in sync with the system clock, the timing information will slowly drift away.

For a rhythm game where a song begins and ends after a few minutes, this approach is fine (and it's the recommended approach). For a game where playback can last a much longer time, the game will eventually go out of sync and a different approach is needed.

## Using the sound hardware clock to sync[](#using-the-sound-hardware-clock-to-sync "Link to this heading")

Using [AudioStreamPlayer.get\_playback\_position()](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html#class-audiostreamplayer-method-get-playback-position) to obtain the current position for the song sounds ideal, but it's not that useful as-is. This value will increment in chunks (every time the audio callback mixed a block of sound), so many calls can return the same value. Added to this, the value will be out of sync with the speakers too because of the previously mentioned reasons.

To compensate for the "chunked" output, there is a function that can help: [AudioServer.get\_time\_since\_last\_mix()](https://docs.godotengine.org/en/stable/classes/class_audioserver.html#class-audioserver-method-get-time-since-last-mix).

Adding the return value from this function to *get\_playback\_position()* increases precision:

var time \= $Player.get\_playback\_position() + AudioServer.get\_time\_since\_last\_mix()

To increase precision, subtract the latency information (how much it takes for the audio to be heard after it was mixed):

var time \= $Player.get\_playback\_position() + AudioServer.get\_time\_since\_last\_mix() \- AudioServer.get\_output\_latency()

The result may be a bit jittery due how multiple threads work. Just check that the value is not less than in the previous frame (discard it if so). This is also a less precise approach than the one before, but it will work for songs of any length, or synchronizing anything (sound effects, as an example) to music.

Here is the same code as before using this approach:

func \_ready():
	$Player.play()

func \_process(delta):
	var time \= $Player.get\_playback\_position() + AudioServer.get\_time\_since\_last\_mix()
	\# Compensate for output latency.
	time \-= AudioServer.get\_output\_latency()
	print("Time is: ", time)
