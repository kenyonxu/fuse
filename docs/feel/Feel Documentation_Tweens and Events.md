This page explains how to use events and tweens to control objects, without necessarily using a MMF Player

*   [Why use tweens and events?](#why-use-tweens-and-events)[](#why-use-tweens-and-events)
*   [Events in Feel](#events-in-feel)[](#events-in-feel)
*   [Tweens](#tweens)[](#tweens)

## Why use tweens and events?[](#why-use-tweens-and-events)

While Feel lets you do a lot from the editor only, via the MMF Player and its 150+ feedbacks, you can also do pretty much everything from code directly.

For example, you can [create a MMF Player from code directly](https://feel-docs.moremountains.com/mmf-player.html#adding-and-removing-feedbacks-at-runtime), and add any feedback you want to it, then play your MMF Player. You can also, very easily, [modify any value on a player](https://feel-docs.moremountains.com/mmf-player.html#modifying-feedback-values-at-runtime).

But sometimes you don’t want to setup complex micro interactions, and you just want to add a bit of juice with a single line. When what you’re after is simple, using a MMF Player can be overkill, or something you’d like to avoid. That’s fine, Feel lets you benefit from its extremely decoupled architecture and do pretty much everything via events and tweens.

Many feedbacks and systems in Feel use events to communicate with other classes and components. A good example of that would be the [MMSoundManager](https://feel-docs.moremountains.com/mmsoundmanager.html#scripting), an advanced yet super simple sound manager, that you can control through feedbacks or just via code, using one liner events.

For example, here’s how you’d pause the UI sound track using an event :

```
MMSoundManagerTrackEvent.Trigger(MMSoundManagerTrackEventTypes.PauseTrack,MMSoundManager.MMSoundManagerTracks.UI);    
```

You’ll find that most shakers can also be controlled via events. To learn more about them, you can simply open the shaker class, which usually also defines its associated event, or you can look at the corresponding feedback class, which usually will also call the same event.

Here are some examples :

```
// triggering a simple camera shake, this event will be processed by a MMCameraShaker or MMCinemachineCameraShaker
MMCameraShakeEvent.Trigger(duration: 1f, amplitude: 5f, frequency: 20f, amplitudeX: 5f, amplitudeY: 5f, amplitudeZ: 5f, infinite: false, channelData: new MMChannelData(MMChannelModes.Int, 0, null), false) ;

// triggers a fade out over 0.5s and an ease-in overhead curve, this event will be processed by a MMFader
MMFadeEvent.Trigger(0.5f, 0f, MMTween.MMTweenCurve.EaseInOverhead, 0, false, Vector3.zero);

// triggers a reverb shake event, shaking the value of the reverb from 0 to 1 over half a second, along a specified animation curve
MMAudioFilterReverbShakeEvent.Trigger(someAnimationCurve, 0.5f, 0f, 1f);
```

Don’t hesitate to check the shakers you’re interested in to see how you too can target them via events from anywhere in your code.

When all you need to do is move an object, or interpolate a value from an origin to a destination, if you don’t want to use a MMF Player, you can simply use the MMTween library.

For example, the line below would move a target object up, over 1s, on an ease-in elastic curve :

```
MMTween.MoveTransform(this, TargetTransform, new Vector3(0, 0, 0), new Vector3(0, 5, 0), null, 0f, 1f, MMTween.MMTweenCurve.EaseInElastic);
```

Note that MoveTransform is a Coroutine, so you could also yield it to do something once it’s complete.

You may also be interested in other Tween methods, such as MMTween.MoveRectTransform or MMTween.RotateTransformAround.

You can also use that same tween library to simply interpolate values over time, like you would with a Lerp, but here with more control. With support of most common types, it’s a nice tool to add to your toolbox!

For example, here’s how you’d tween a float value halfway between 0 and 5 along an ease out bounce curve :

```
float someValue = MMTween.Tween(currentTime: 0.5f, initialTime: 0f, endTime: 1f, startValue:0f, endValue:5f, MMTween.MMTweenCurve.EaseOutBounce);
```

The same MMTween.Tween method also supports Vector2, Vector3 and Quaternions. Don’t hesitate to check the MMTween class for more on this.