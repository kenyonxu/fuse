This section covers the various ways FEEL lets you shake your screen.

*   [Introduction](#introduction)[](#introduction)
*   [The many types of screenshakes](#the-many-types-of-screenshakes)[](#the-many-types-of-screenshakes)
*   [Toaster demo!](#toaster-demo)[](#toaster-demo)
*   [Camera Shake Recipes](#camera-shake-recipes)[](#camera-shake-recipes)
    *   [How to setup a Cinemachine camera shake (the recommended way to do camera shake)](#how-to-setup-a-cinemachine-camera-shake-the-recommended-way-to-d)[](#how-to-setup-a-cinemachine-camera-shake-the-recommended-way-to-d)
    *   [How to setup a Cinemachine Impulse Source feedback](#how-to-setup-a-cinemachine-impulse-source-feedback)[](#how-to-setup-a-cinemachine-impulse-source-feedback)
    *   [How to setup a regular, non-Cinemachine camera shake](#how-to-setup-a-regular-non-cinemachine-camera-shake)[](#how-to-setup-a-regular-non-cinemachine-camera-shake)
    *   [How to setup a regular camera shake but still target virtual cameras](#how-to-setup-a-regular-camera-shake-but-still-target-virtual-cam)[](#how-to-setup-a-regular-camera-shake-but-still-target-virtual-cam)
    *   [How to setup a UI screen shake?](#how-to-setup-a-ui-screen-shake)[](#how-to-setup-a-ui-screen-shake)
*   [Other camera recipes](#other-camera-recipes)[](#other-camera-recipes)
    *   [How to setup a camera zoom feedback?](#how-to-setup-a-camera-zoom-feedback)[](#how-to-setup-a-camera-zoom-feedback)
    *   [How to setup a MMFader and fade feedback?](#how-to-setup-a-mmfader-and-fade-feedback)[](#how-to-setup-a-mmfader-and-fade-feedback)
*   [Disabling screen shakes](#disabling-screen-shakes)[](#disabling-screen-shakes)
    *   [How to disable a certain type of feedback?](#how-to-disable-a-certain-type-of-feedback)[](#how-to-disable-a-certain-type-of-feedback)

Screen or camera shakes may be the first thing that comes to mind when you think of **game feel**, and you’ll find that FEEL offers plenty of ways to trigger shakes, as well as other camera effects. You can trigger them via events or via feedbacks, and can of course customize all their settings.

What is usually designated as “*screen shake*” can be done in a lot of **different ways**. When designing the screenshakes in my games, I like to determine a **language** for them. I define an **intensity scale** and decide on a **meaning** for the different **types of screenshakes** I plan to use. Of course, that’s how I like to work, but feel free to do things entirely differently, it’s not an absolute rule.

*   **Intensity scale** : There may be a lot of things happening in your game that will cause the screen to shake in one manner or the other. Usually, you’ll want to map the intensity of these shakes on a scale, where events of great significance to the player will have a stronger intensity than the ones that don’t matter much. Typically, the player getting hurt should probably shake the screen more than the player dropping an item on the ground. What the “intensity” is will vary depending on the type of screenshake you use. It can be its movement range, its duration, its frequency, or combinations of these and other settings.
    
*   **Meaning** : with a vast variety of shakes available, I usually try to associate them to specific types of events in a game. Most shakes don’t have a universal meaning, and it’ll be up to you to define what each of them means in the context of your game. For example, in a PacMan-like game, maybe eating ghosts would trigger a camera shake, while getting killed would trigger a view shake. Sticking to that defined feedback language will help players identify causes and consequences.
    

Here’s a list of some of the most common types of screen shakes that Feel will let you implement :

*   **Camera Position Shake** : one of the most common ways to create a visible shake of what’s rendered on screen will be to simply move the camera. Feel lets you do so with many of its feedbacks, for example the regular Camera Shake, Cinemachine Impulses, MMWiggle, Cinemachine Noise, Position Shake, and more.
*   **Camera Rotation Shake** : slightly less common, but also moving the camera, here’s the rotation shake. This time the camera stays in place, but we rotate it on one or more axis.
*   **Camera Field of View / Zoom Shake** : zooming in and out quickly can also be a nice way to shake the screen. Usually you’ll do that by acting on your camera’s field of view (or orthographic size in 2D), but this can also obtained by moving the camera on its local z axis.
*   **View Shake** : my personal favorite, the view shake doesn’t move the camera, it moves the entire view, and feels like the entire screen you’re playing on is shaking. Such a shake usually requires rendering to a render texture, which most games do anyway to be able to upscale resolution. Note that you can also obtain a similar effect by implementing a custom post processing shader, but it’s one extra pass, so there’s no real benefit over the render texture option.
*   **Post Processing Shake** : shaking the intensity of, for instance, a lens distortion or chromatic aberration post processing effect is a great way to convey emotion and “shake” the screen. Other good candidates for this would be vignette, color grading and bloom intensity.
*   **UI Shake** : instead of shaking the whole screen, it can be a good idea to shake only the UI (or parts of it). You can see an example of that in the Toaster demo of course, but also in the Duck demo scene.

Feel comes with an entire demo dedicated to the various ways you can shake your screen, and you can [play with its toaster over there](https://feel.moremountains.com/assets/resources/feel/builds/Toaster/). From its **sidebar menu**, you’ll be able to turn the toaster feedback on and off if you want to, and trigger all sorts of screen shake feedbacks. You’ll quickly notice that many of them are **exaggerated** to be noticeable, you’ll likely want to tweak their intensity to match the feel of your game.

Don’t hesitate to **open the demo in your Unity editor** (it’s in the *FeelDemos/Toaster* folder). In it you’ll be able to see how each and every feedback is setup, and you can also play with them directly, even at runtime, tweaking their values to explore how they work and discover new and interesting ways to shake your screen.

To be able to execute all these different types of screen shakes in a single demo, you’ll notice its setup verges on the complex side. Of course in your game you may not want to have that many types of shakes, in which case looking at the **recipes** below will give you a good starting point, with minimal setup.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  from the Package Manager, import Cinemachine
3.  create a new empty scene
4.  add a cube, position it at 0,0,0

**Option 1 : automatic shaker setup**

1.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it, position it at 0,0,0
2.  add a new **Cinemachine Impulse feedback** to it, via its “Add new feedback” dropdown
3.  unfold its Automatic Setup foldout, press the **Automatic Shaker Setup** button. If needed, select your MainCamera and ensure it’s got a CinemachineBrain. If it doesn’t, add one.
4.  press play in the editor, select the MyTestFeedbacks object, and in its MMF Player inspector, press the green Play button
5.  CAMERA SHAKE!

**Option 2 : manual setup**

1.  via the Cinemachine menu in the top menu, create a new **virtual camera**
2.  select your virtual camera, and via its **AddExtensions dropdown**, add an impulse listener
3.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it, position it at 0,0,0
4.  add a new **Cinemachine Impulse feedback** to it, via its “Add new feedback” dropdown
5.  from its inspector, click the little cog at the end of the RawSignal field and select Presets > 6D Shake (if the cog icon doesn’t work - it’s a known Cinemachine bug, you’ll find the same presets in Packages/Cinemachine/Presets/Noise/, and can just drag them into your impulse feedback inspector)
6.  set its Velocity (at the bottom of the inspector) to 5,5,5
7.  press play in the editor, select the MyTestFeedbacks object, and in its MMF Player inspector, press the green Play button
8.  CAMERA SHAKE!

9.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
10.  from the Package Manager, import Cinemachine
11.  create a new empty scene
12.  add a cube, position it at 0,0,0
13.  via the Cinemachine menu in the top menu, create a new **virtual camera**
14.  select your virtual camera, and via its **AddExtensions dropdown**, add an impulse listener
15.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it, position it at 0,0,0
16.  add a **CinemachineImpulseSource feedback** to it
17.  via the AddComponent button, add a Cinemachine Impulse Source, drag that component into the ImpulseSource field on your feedback
18.  press play, then Play on your MyTestFeedbacks inspector, camera will shake

19.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
20.  create a new empty scene
21.  add a cube, position it at 0,0,0

**Option 1 : automatic shaker setup**

1.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it, add a new feedback > camera > camera shake to it
2.  unfold its Automatic Setup foldout, press the **Automatic Shaker Setup** button
3.  press play, then Play on your MyTestFeedbacks inspector, camera will shake

**Option 2 : manual setup**

1.  create an empty game object at the camera’s position, call it CameraRig
2.  create an empty game object at the camera’s position, call it CameraShaker, nest it under CameraRig
3.  nest your Camera under CameraShaker (you should have CameraRig > CameraShaker > MainCamera)
4.  on your CameraShaker node, add a **MMCameraShaker component**
5.  on its **MMWiggle**, check Position, select Noise as wiggle type, uncheck wiggle permitted
6.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it
7.  add new feedback > camera > camera shake
8.  press play, then Play on your MyTestFeedbacks inspector, camera will shake

9.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
10.  from the Package Manager, import Cinemachine
11.  create a new, empty scene, add a Cube to it, position it at 0,0,0
12.  create a new **Cinemachine virtual camera**, position it so that it “sees” the cube
13.  on the virtual camera, set Noise to BasicMultiChannelPerlin, set NoiseProfile to 6D Shake, AmplitudeGain:0 and FrequencyGain:0
14.  add a **MMCinemachineCameraShaker** to it
15.  create a new empty game object, add a **MMF Player** to it, add a Camera > Camera Shake feedback to it, unfold its CameraShakeProperties and set all Duration:0.3, Amplitude:2, Frequency:40
16.  press play in the editor, then play on the MMF Player

17.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
18.  add a UI > Canvas, add an empty child to it, name it UIContainer, add a MMWiggle to it, check Position, uncheck WigglePermitted for it, add a MMCameraShaker
19.  add a UI Image at 0,0,0, parent it to the UIContainer, duplicate it at -300,0, and another time at 300,0 (you should now have a row of 3 white squares)
20.  create an empty, add a MMF Player to it, add a CameraShake feedback to it, Duration:0.5, Amplitude: 20, Frequency: 0.03
21.  press play in the editor, press play on the MMF Player, notice your entire UI panel now shakes for 0.5s

22.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
23.  create a new empty scene
24.  add a cube, position it at 0,0,0
25.  select your **MainCamera**, add a **MMCameraZoom** component to it
26.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it
27.  add a Camera > **Camera Zoom feedback** to it, via its “Add new feedback” dropdown
28.  press play in the editor, select the MyTestFeedbacks object, and in its MMF Player inspector, press the green Play button

### How to setup a MMFader and fade feedback?[](#how-to-setup-a-mmfader-and-fade-feedback)

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene

**Option 1 : automatic shaker setup**

1.  in the scene, create a new empty object, add a **MMF Player** to it, add a Camera > Fade feedback to it
2.  unfold its Automatic Setup foldout, press the **Automatic Shaker Setup** button
3.  press play in the editor, then the green Play button on your MMF Player

**Option 2 : manual setup**

1.  add a **UI Image** to your scene, set its **RectTransform** so that it covers the entire screen (usually full stretch and 0 on all left/right/top/bottom, set its **Image** color to black
2.  add a **MMFader component** to it, this will add a **CanvasGroup**, set its Alpha to 0
3.  in the scene, create a new empty object, add a **MMF Player** to it, add a Camera > Fade feedback to it
4.  press play, play the Feedback, it will “fade in” the fader (fading the screen to black), change its FadeType to Fade Out, it will fade it out back to normal. The Fade feedback’s inspector will let you tweak settings to your liking (duration, curve, etc). If you have more than one fader, make sure the Channel ID on both your fader and feedbacks match.

Sometimes you want to give players control over what type of feedbacks they’ll get to experience. For instance, it’s common to offer an option to turn down screen shakes, as it can be a problem for people with disabilities, for example. With Feel, doing so is very easy!

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  open the Toaster demo scene
3.  create a new class in your project, name it ImpulseDisabler, and replace its contents with this :

```
using MoreMountains.FeedbacksForThirdParty;
using UnityEngine;

public class ImpulseDisabler : MonoBehaviour
{
	public void DisableAllImpulses()
	{
		MMF_CinemachineImpulse.FeedbackTypeAuthorized = false;
	}

	public void EnableAllImpulses()
	{
		MMF_CinemachineImpulse.FeedbackTypeAuthorized = true;
	}
}
```

1.  in your scene, create a new button (GameObject > UI > Button), and position it at 0,0,0 (yes it’s ugly and in the middle of the screen, feel free to put it elsewhere)
2.  add your newly created ImpulseDisabler component to this button
3.  in the button inspector, under OnClick, add a new entry, drag the ImpulseDisabler component into the slot that appears, and select its ImpulseDisabler.DisableAllImpulses function
4.  press play in the editor, then press the CM Impulse button in the sidebar of the scene, the screen will shake, now press the button you created, then the CM Impulse button again, the screen won’t shake anymore
5.  that’s it, you now know how to disable (or enable) a feedback of any type with a single line. You can do so for all feedbacks, simply target their specific type!