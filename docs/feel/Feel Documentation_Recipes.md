# Recipes | Feel Documentation

This page lists a few 'recipes' that will teach you in a few steps how to do common tasks using Feel

*   [Introduction](#introduction)[](#introduction)
    *   [How to install Feel in your project?](#how-to-install-feel-in-your-project)[](#how-to-install-feel-in-your-project)
    *   [How to use MMF Player to trigger a particle system?](#how-to-use-mmf-player-to-trigger-a-particle-system)[](#how-to-use-mmf-player-to-trigger-a-particle-system)
    *   [How to setup a Cinemachine camera shake (the recommended way to do camera shake)](#how-to-setup-a-cinemachine-camera-shake-the-recommended-way-to-d)[](#how-to-setup-a-cinemachine-camera-shake-the-recommended-way-to-d)
    *   [How to setup a regular, non-Cinemachine camera shake](#how-to-setup-a-regular-non-cinemachine-camera-shake)[](#how-to-setup-a-regular-non-cinemachine-camera-shake)
    *   [How to setup a Cinemachine Impulse Source feedback](#how-to-setup-a-cinemachine-impulse-source-feedback)[](#how-to-setup-a-cinemachine-impulse-source-feedback)
    *   [How to setup a regular camera shake but still target virtual cameras](#how-to-setup-a-regular-camera-shake-but-still-target-virtual-cam)[](#how-to-setup-a-regular-camera-shake-but-still-target-virtual-cam)
    *   [How to setup a simple post processing feedback?](#how-to-setup-a-simple-post-processing-feedback)[](#how-to-setup-a-simple-post-processing-feedback)
    *   [How to use Feel with URP?](#how-to-use-feel-with-urp)[](#how-to-use-feel-with-urp)
    *   [Ok and how to use MMF Player with URP volumes then?](#ok-and-how-to-use-mmf-player-with-urp-volumes-then)[](#ok-and-how-to-use-mmf-player-with-urp-volumes-then)
    *   [How to change a feedback's property via script at runtime?](#how-to-change-a-feedbacks-property-via-script-at-runtime)[](#how-to-change-a-feedbacks-property-via-script-at-runtime)
    *   [How to play a feedback in reverse?](#how-to-play-a-feedback-in-reverse)[](#how-to-play-a-feedback-in-reverse)
    *   [How to revert a feedback as it's playing?](#how-to-revert-a-feedback-as-its-playing)[](#how-to-revert-a-feedback-as-its-playing)
    *   [How to trigger a MMF Player with Playmaker?](#how-to-trigger-a-mmf-player-with-playmaker)[](#how-to-trigger-a-mmf-player-with-playmaker)
    *   [How to setup a camera zoom feedback?](#how-to-setup-a-camera-zoom-feedback)[](#how-to-setup-a-camera-zoom-feedback)
    *   [How to setup a camera zoom feedback using Cinemachine?](#how-to-setup-a-camera-zoom-feedback-using-cinemachine)[](#how-to-setup-a-camera-zoom-feedback-using-cinemachine)
    *   [How to trigger MMF Player via the Timeline](#how-to-trigger-mmf-player-via-the-timeline)[](#how-to-trigger-mmf-player-via-the-timeline)
    *   [How to setup a MMFader and fade feedback?](#how-to-setup-a-mmfader-and-fade-feedback)[](#how-to-setup-a-mmfader-and-fade-feedback)
    *   [How to setup a MMFaderRound and fade feedback?](#how-to-setup-a-mmfaderround-and-fade-feedback)[](#how-to-setup-a-mmfaderround-and-fade-feedback)
    *   [How to setup a simple Position feedback?](#how-to-setup-a-simple-position-feedback)[](#how-to-setup-a-simple-position-feedback)
    *   [How to setup a Scale To Destination feedback?](#how-to-setup-a-scale-to-destination-feedback)[](#how-to-setup-a-scale-to-destination-feedback)
    *   [How to use the MMHealthBar component to automatically draw health bars?](#how-to-use-the-mmhealthbar-component-to-automatically-draw-healt)[](#how-to-use-the-mmhealthbar-component-to-automatically-draw-healt)
    *   [How to setup floating texts to play them via feedbacks?](#how-to-setup-floating-texts-to-play-them-via-feedbacks)[](#how-to-setup-floating-texts-to-play-them-via-feedbacks)
    *   [How to setup floating images?](#how-to-setup-floating-images)[](#how-to-setup-floating-images)
    *   [How to make an object wiggle in your scene?](#how-to-make-an-object-wiggle-in-your-scene)[](#how-to-make-an-object-wiggle-in-your-scene)
    *   [Setting up a MMBlink component](#setting-up-a-mmblink-component)[](#setting-up-a-mmblink-component)
    *   [How to use a spring to control a post processing effect?](#how-to-use-a-spring-to-control-a-post-processing-effect)[](#how-to-use-a-spring-to-control-a-post-processing-effect)
    *   [How to pilot a spring component using a feedback?](#how-to-pilot-a-spring-component-using-a-feedback)[](#how-to-pilot-a-spring-component-using-a-feedback)
    *   [How to play a random sound with randomized volume?](#how-to-play-a-random-sound-with-randomized-volume)[](#how-to-play-a-random-sound-with-randomized-volume)
    *   [How to setup a flicker feedback?](#how-to-setup-a-flicker-feedback)[](#how-to-setup-a-flicker-feedback)
    *   [How to setup a shader controller and pilot it with a feedback?](#how-to-setup-a-shader-controller-and-pilot-it-with-a-feedback)[](#how-to-setup-a-shader-controller-and-pilot-it-with-a-feedback)
    *   [How to setup a simple spring component?](#how-to-setup-a-simple-spring-component)[](#how-to-setup-a-simple-spring-component)
    *   [How to setup a channel asset on a feedback and shaker?](#how-to-setup-a-channel-asset-on-a-feedback-and-shaker)[](#how-to-setup-a-channel-asset-on-a-feedback-and-shaker)
    *   [How to add a button to mute all sounds?](#how-to-add-a-button-to-mute-all-sounds)[](#how-to-add-a-button-to-mute-all-sounds)
    *   [How to use a property feedback to control anything in your game?](#how-to-use-a-property-feedback-to-control-anything-in-your-game)[](#how-to-use-a-property-feedback-to-control-anything-in-your-game)
    *   [How to play a 3D sound?](#how-to-play-a-3d-sound)[](#how-to-play-a-3d-sound)
    *   [How to setup a signal broadcaster and receiver?](#how-to-setup-a-signal-broadcaster-and-receiver)[](#how-to-setup-a-signal-broadcaster-and-receiver)
    *   [How to trigger a flash feedback?](#how-to-trigger-a-flash-feedback)[](#how-to-trigger-a-flash-feedback)
    *   [How to setup a script driven pause?](#how-to-setup-a-script-driven-pause)[](#how-to-setup-a-script-driven-pause)
    *   [How to play a MMF Player from an animation using Animation Events?](#how-to-play-a-mmf-player-from-an-animation-using-animation-event)[](#how-to-play-a-mmf-player-from-an-animation-using-animation-event)
    *   [How to setup a Post Processing Moving Filter](#how-to-setup-a-post-processing-moving-filter)[](#how-to-setup-a-post-processing-moving-filter)
    *   [How to use a reference holder feedback?](#how-to-use-a-reference-holder-feedback)[](#how-to-use-a-reference-holder-feedback)
    *   [How to control the timescale using a feedback?](#how-to-control-the-timescale-using-a-feedback)[](#how-to-control-the-timescale-using-a-feedback)
    *   [How to setup billboarding and a ghost camera?](#how-to-setup-billboarding-and-a-ghost-camera)[](#how-to-setup-billboarding-and-a-ghost-camera)
    *   [How to setup a position shaker](#how-to-setup-a-position-shaker)[](#how-to-setup-a-position-shaker)
    *   [How to setup a MM Progress Bar?](#how-to-setup-a-mm-progress-bar)[](#how-to-setup-a-mm-progress-bar)
    *   [How to add a squash and stretch behavior to an object?](#how-to-add-a-squash-and-stretch-behavior-to-an-object)[](#how-to-add-a-squash-and-stretch-behavior-to-an-object)
    *   [How to setup a UI element hover effect?](#how-to-setup-a-ui-element-hover-effect)[](#how-to-setup-a-ui-element-hover-effect)
    *   [How to wait for a MMF Player to finish before executing the rest of a coroutine?](#how-to-wait-for-a-mmf-player-to-finish-before-executing-the-rest)[](#how-to-wait-for-a-mmf-player-to-finish-before-executing-the-rest)
    *   [How to disable a certain type of feedback?](#how-to-disable-a-certain-type-of-feedback)[](#how-to-disable-a-certain-type-of-feedback)
    *   [How to load a scene additively using a feedback?](#how-to-load-a-scene-additively-using-a-feedback)[](#how-to-load-a-scene-additively-using-a-feedback)
    *   [How to setup a squash and stretch feedback?](#how-to-setup-a-squash-and-stretch-feedback)[](#how-to-setup-a-squash-and-stretch-feedback)
    *   [How to setup a TextMeshPro (TMP) text reveal feedback?](#how-to-setup-a-textmeshpro-tmp-text-reveal-feedback)[](#how-to-setup-a-textmeshpro-tmp-text-reveal-feedback)
    *   [How to setup a UI screen shake?](#how-to-setup-a-ui-screen-shake)[](#how-to-setup-a-ui-screen-shake)
    *   [How to setup a MMFollowTarget component to have it follow a target?](#how-to-setup-a-mmfollowtarget-component-to-have-it-follow-a-targ)[](#how-to-setup-a-mmfollowtarget-component-to-have-it-follow-a-targ)
    *   [How to use the range options on a MMF Player](#how-to-use-the-range-options-on-a-mmf-player)[](#how-to-use-the-range-options-on-a-mmf-player)
    *   [How to use the range options on a MMF Player](#how-to-use-the-range-options-on-a-mmf-player-1)[](#how-to-use-the-range-options-on-a-mmf-player-1)

**Want to get started quickly with Feel?** This page contains simple steps you can follow for a number of basic situations, no explanations, just quick steps. Don’t hesitate to check the rest of the documentation to learn more about how the engine works. And if you’re wondering how to achieve something, or would like to see a particular recipe on this page, [don’t hesitate to make suggestions](https://feel.moremountains.com/feel-contact)!

Note that most of these will provide Feel / Unity versions, that’s just to provide the **context** they were first written in. But it’s safe to assume that they should work on any higher versions of both Unity and Feel.

To add **Feel** to your project, simply follow the simple steps below :

1.  using Unity 6000.0.23f1 or higher (see the [release notes](https://feel.moremountains.com/feel-releases) to see which minimum version of Unity each version of Feel requires), create a new project, pick the “3D (Built-in Render Pipeline)” template
2.  via the Package Manager, go to the **Feel** page, click the download button, then the import button
3.  wait until a “*import Unity package*” popup appears, make sure everything is checked (it should be by default), click “import”
4.  open Unity’s Package Manager, install the latest version of the **Post Processing** package
5.  in the package manager, install the latest version of the **Cinemachine** package
6.  in the package manager, install the latest version of the **TextMesh Pro** package
7.  in the package manager, install the latest version of the **Animation 2D** package (this is only useful for the Letters demo)
8.  open the **MMFPlayerDemo** scene (or any other demo), press play, enjoy

### How to use MMF Player to trigger a particle system?[](#how-to-use-mmf-player-to-trigger-a-particle-system)

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new scene
3.  create a new empty object in it, add a **particle system** component to it
4.  let’s make it a bit prettier, under its **Renderer** panel, click on the Material dot on the right of the field, and pick the FeelSnakeEatParticlesMaterial
5.  under its **Emission** foldout, set RateOverTime to 0, and add a Burst instead by pressing the little “+” under Bursts (default settings will do)
6.  towards the top of the inspector, set the StartLifetime to 0.5
7.  then check SizeOverLifetime down in the list of foldouts, and set its size curve to any of the default downward curves
8.  if you were to play your particle system, you should see a bunch of bubbles shrinking down rapidly
9.  now create a new empty object, call it MyTestFeedbacks, add a **MMF Player** component to it
10.  add a **ParticlesPlay feedback** to it, and drag the particle system you’ve created into its BoundParticleSystem slot
11.  press play in your editor, then select your MyTestFeedbacks object, and in its MMF Player’s inspector, press the green Play button
12.  now you know how to trigger particle systems via MMF Player. Note that there are other ways to do it, for example you could decide to make a prefab out of your particle system, and instead use the ParticleInstantiation feedback

13.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
14.  from the Package Manager, import Cinemachine
15.  create a new empty scene
16.  add a cube, position it at 0,0,0

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
10.  create a new empty scene
11.  add a cube, position it at 0,0,0

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
11.  create a new empty scene
12.  add a cube, position it at 0,0,0
13.  via the Cinemachine menu in the top menu, create a new **virtual camera**
14.  select your virtual camera, and via its **AddExtensions dropdown**, add an impulse listener
15.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it, position it at 0,0,0
16.  add a **CinemachineImpulseSource feedback** to it
17.  via the AddComponent button, add a Cinemachine Impulse Source, drag that component into the ImpulseSource field on your feedback
18.  press play, then Play on your MyTestFeedbacks inspector, camera will shake

19.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
20.  from the Package Manager, import Cinemachine
21.  create a new, empty scene, add a Cube to it, position it at 0,0,0
22.  create a new **Cinemachine virtual camera**, position it so that it “sees” the cube
23.  on the virtual camera, set Noise to BasicMultiChannelPerlin, set NoiseProfile to 6D Shake, AmplitudeGain:0 and FrequencyGain:0
24.  add a **MMCinemachineCameraShaker** to it
25.  create a new empty game object, add a **MMF Player** to it, add a Camera > Camera Shake feedback to it, unfold its CameraShakeProperties and set all Duration:0.3, Amplitude:2, Frequency:40
26.  press play in the editor, then play on the MMF Player

**The automated way**

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in a new empty scene
2.  create a new empty object, add a MMF Player to it, add a **PostProcess>LensDistortion feedback** to it via the “Add new feedback” menu
3.  unfold its “Automatic Setup” dropdown, press the **Automatic Shaker Setup** button
4.  press play in the editor, press the green Play button on your MMF Player, notice the lens distortion effect’s intensity shakes over time

**The manual way**

A - Setting up our post processing volume

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in a new empty scene
2.  Create a new empty object, call it **PostProcessingVolume**, and add a PostProcess Volume component to it. Create a new profile for it by pressing the New button. Check its IsGlobal checkbox. Then select your Main Camera, and add a **PostProcess Layer** component to it. Set its Layer to Default.
3.  Now, back on our PostProcessingVolume object, add a **Lens Distortion effect**, leave its values to the default
4.  Add a **MMLensDistortionShaker** component to your PostProcessingVolume game object

B - Setting up our lens distortion feedback

1.  create a new empty object, add a MMF Player to it, add a PostProcess>LensDistortion feedback to it via the “Add new feedback” menu
2.  press play in the editor, press the green Play button on your MMF Player, notice the lens distortion effect’s intensity shakes over time

3.  in Unity, create a new project using the **URP template**
4.  from the Package Manager, import the latest version of **Feel**
5.  (optional, only required for the demos) go to the Feel/FeelDemosURP folder, double click on the FeelDemosURP.unitypackage file you’ll find there, click the import button in the bottom right on the Import popup, this will setup all demos to work with URP
6.  **that’s it**, you can now use Feel with your URP project

### Ok and how to use MMF Player with URP volumes then?[](#ok-and-how-to-use-mmf-player-with-urp-volumes-then)

1.  after the steps described above :
2.  create a new scene
3.  in it, add a cube, position it at 0,0,0

**Option 1 : automatic shaker setup**

1.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player** component to it, press the “add new feedback” dropdown and select PostProcess > Vignette URP
2.  unfold its Automatic Setup foldout, press the **Automatic Shaker Setup** button
3.  press play in the editor, then the green Play button on your MMF Player, the vignette’s intensity will interpolate

**Option 2 : manual setup**

1.  create a new **Global Volume** (right click, volume > global volume in your Hierarchy panel)
2.  press the New button next to Profile in its inspector
3.  add an override to it, pick **Vignette**, set the Vignette’s intensity to 0.5
4.  add a new component to the global volume, in the add component menu type **MMVignetteShaker\_URP**
5.  select the MainCamera, in its inspector under Rendering, check PostProcessing
6.  you should now see the Vignette in your Game view
7.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player** component to it
8.  press the “add new feedback” dropdown and select PostProcess > Vignette URP
9.  in its inspector, set Remap Intensity Zero to 0.5
10.  press play in the editor, select the MyTestFeedbacks object, and in its MMF Player’s inspector, press the green Play button
11.  now you know how to trigger volume feedbacks. To target other post processing filters, make sure you add the corresponding Shaker on the Volume

For plenty of reasons, you may want to change a property or more on a feedback at runtime. It’s of course possible, and in this example we’ll see how we can change the intensity of a Chromatic Aberration feedback in the Duck demo. It’d be the exact same logic for any other property, on any other feedback.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  open the FeelDuck demo scene
3.  create a new, empty gameobject, call it RuntimeTest
4.  **outside of the Feel folder**, create a new C# script, call it RuntimeTest, and paste the following in it :

```
using MoreMountains.Feedbacks;
using MoreMountains.FeedbacksForThirdParty;
using MoreMountains.Tools;
using UnityEngine;

public class RuntimeTest : MonoBehaviour
{
    public MMF_Player TargetFeedback;
    [Range(-100f, 100f)]
    public float Intensity = 0f;
    [MMInspectorButton("TestFeedback")]
    public bool PlayFeedbackBtn;

    private MMF_LensDistortion _lensDistortion;

    private void Start()
    {
        // on start we store our lens distortion feedback component, so that we can target it later on
        _lensDistortion = TargetFeedback.GetFeedbackOfType<MMF_LensDistortion>();
    }

    public void TestFeedback()
    {
        // we modify our RemapIntensityOne value before playing our feedback.
        // This is done like for any other public attribute on any component in Unity
        if (_lensDistortion != null)
        {
            _lensDistortion.RemapIntensityOne = Intensity;
        }
        // we then play our MMF_Player
        TargetFeedback?.PlayFeedbacks();
    }
}
```

1.  then add that script to your RuntimeTest game object
2.  select your RuntimeTest object, and drag the FeelDuckLandingFeedback object from your Hierarchy panel into the RuntimeTest’s TargetFeedback slot in its inspector
3.  press play in the editor, then select your RuntimeTest object, change the intensity value in your inspector, and press the TestFeedback button, every time you’ll play, the value you’ve changed in the inspector will be sent to the feedback before it plays

One important thing to keep in mind when changing values at runtime is that some of them will get cached for performance reason. So always double check that the value you’re interacting with doesn’t get cached at some point, and that you’re targeting the correct property, or resetting the cache if needed.

1.  select your **MMF\_Player**, and in its Settings foldout, set **Direction** to BottomToTop
2.  you can also force that via code :
    
    ```
    MyPlayer.Direction = MMFeedbacks.Directions.BottomToTop;
    MyPlayer.PlayFeedbacks();
    ```
    
3.  you can learn more about direction options in [the dedicated section of the documentation](http://feel-docs.moremountains.com/core-concepts.html#timing)

4.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
5.  in a new empty scene, add a cube, position it at 0,0,0
6.  add a new empty, add a **MMF Player** to it, add a **Position feedback**, target:Cube, duration:5, destination position:0,5,0
7.  press play in the editor, then the green play button, then the Revert button after 2s
8.  you can of course do that via code as well, simply by calling the Revert() method on your MMF Player

Note : there are plenty of other ways to do it, and this will also (most of the time) be the same general logic for Bolt and other visual scripting tools.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  install Playmaker
3.  in a new scene, create an empty object, call it MyFeedbacks, add a **MMF Player** component to it
4.  add a **Debug Log feedback** to it, set its Debug Message to “Hello!”
5.  open the **Playmaker editor**, right click in it to add a FSM
6.  rename that first state to “GettingInput”, and using the Action Browser, add a GetKeyDown action, set its key to F2
7.  in the Send Event dropdown, select New Event, name it “F2Pressed”, and press the CreateEvent button, then click on the red label to add transition to state
8.  right click in the FSM to add a new state, call it “PlayingFeedbacks”
9.  right click on the first state’s F2Pressed event, set its transition target to PlayingFeedbacks
10.  right click on the PlayingFeedbacks state, add transition > Finished, then right click on Finished and set its transition target to GettingInput
11.  in the PlayingFeedbacks state, using the Action Browser, add a CallMethod action, drag MyFeedbacks’ MMF Player monobehaviour into its Behaviour slot, and in the Method dropdown, select “void PlayFeedbacks()”
12.  press play in your Unity editor, now every time you’ll press F2, the feedback will play, and “Hello!” will appear in the console. Any other feedbacks you’d add to your MyFeedbacks MMF Player will of course also play

![Jekyll](https://feel-docs.moremountains.com/images/recipe-playmaker.png)

The PlayingFeedbacks state

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new empty scene
3.  add a cube, position it at 0,0,0
4.  select your **MainCamera**, add a **MMCameraZoom** component to it
5.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it
6.  add a Camera > **Camera Zoom feedback** to it, via its “Add new feedback” dropdown
7.  press play in the editor, select the MyTestFeedbacks object, and in its MMF Player inspector, press the green Play button

8.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
9.  from the Package Manager, import Cinemachine
10.  create a new empty scene
11.  add a cube, position it at 0,0,0
12.  via the GameObject menu, add a Cinemachine > Virtual Camera
13.  select your newly created **Virtual Camera**, position it at 0,0,-10, add a **MMCinemachineZoom** component to it
14.  create an empty game object, call it MyTestFeedbacks, add a **MMF Player component** to it
15.  add a Camera > **Camera Zoom feedback** to it, via its “Add new feedback” dropdown
16.  press play in the editor, select the MyTestFeedbacks object, and in its MMF Player inspector, press the green Play button

17.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
18.  for this example we’ll open the **FeelDuck demo scene**
19.  create a new empty object, call it Director
20.  open the **Timeline panel** (Window > Sequencing > Timeline)
21.  in the Timeline panel, press the Create (a director) button, call the new asset TimelineDirector, save it in your project
22.  drag the FeelDuckBackground into the Timeline, and pick “Add activation track”
23.  copy the Active block, move the new one to the right, you should now have two Active blocks, maybe with a bit of a gap between them, that’s our Timeline animation (it’ll activate/disable/activate the background, of course you may want to do more fancy stuff in your own Timeline, that just gives us a track to play)
24.  press the little pin icon under the frame count to reveal our markers track
25.  around frame 120, right click in the marker track and select “Add signal emitter”
26.  in the inspector, click on Create Signal, name the new asset “TestMMFPlayer.signal”, save it in your project
27.  in the inspector, click on “Add signal receiver”
28.  select your Director object, and in its inspector, drag the **FeelDuckJumpStartFeedback** into the SignalReceiver’s event reaction slot, select its MMF Player > PlayFeedbacks() method as its reaction
29.  press play in the editor, then press play in your timeline, your feedback will play everytime the play head passes the marker
30.  don’t hesitate to check https://blog.unity.com/technology/how-to-use-timeline-signals to learn more about how Timeline and Signals work

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

### How to setup a MMFaderRound and fade feedback?[](#how-to-setup-a-mmfaderround-and-fade-feedback)

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  in a new empty scene, add a Cube at 0,0,0
3.  create a new UI Canvas
4.  add a child object to the Canvas, add a CanvasGroup to it, add a **MMFaderRound** to it, name it Fader, set its RectTransform to stretch on both x and y, set Left/Right/Top/Bottom to 0
5.  add a child to the Fader, name it Mask, add an Image component to it, set its material to MMFaderRoundMaterialMask, set its SourceImage to FeedbacksDemoFaderMask
6.  add a child to the Fader, name it Background, stretch it like its parent, add an Image component to it, set its Color to black, set its Material to MMFaderRoundMaterialMasked
7.  on the Fader object, add a MMFaderRound component, bind Background to the FaderBackground field, bind Mask to the FaderMask field, set its MaskScale to 0,15, set its CanvasGroup alpha to 0
8.  create a new empty at 0,0,0, name it Test, add a **MMF Player** to it, add a Camera>Fade feedback to it
9.  press play in the editor, then the green play button on Test’s MMF Player component, the fader fades in on the target position (in this case, the MMF Player’s position)
10.  exit play mode, move Test at 10,0,0, enter play mode again, press the green play button, notice the fade now centers on a different position than before

11.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
12.  create a new, empty scene, add a cube to it, position it at 0,0,0
13.  add a new, empty game object, add a **MMF Player component** to it
14.  add a Transform > **Position feedback** to it
15.  drag the Cube in its AnimatePositionTarget slot
16.  set Transition Mode to Along Curve, AnimatePositionDuration: 1, AnimateX:true
17.  press play, play the feedback

18.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
19.  create a new, empty scene, add a Cube to it
20.  create a new empty object, add a **MMF Player** to it
21.  add a Transform > **Scale feedback**, set the Cube as its AnimateScaleTarget
22.  set Mode:ToDestination, RemapCurveZero:0, RemapCurveOne:1, check all AnimateXYZ checkboxes, set all curves to an ascending curve (0,0 to 1,1)
23.  press play in the editor, set DestinationScale to 0.5,0.5,0.5, press Play on that feedback, your cube will shrink
24.  set DestinationScale to 0,0,0, press Play on that feedback, your cube will shrink even more
25.  set DestinationScale to 1,1,1, press Play on that feedback, your cube will go back to its initial scale

26.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
27.  create a new, empty scene
28.  create a cube, position it at 0,0,0
29.  add a **MMHealthBar component** to it
30.  press play, you’ll notice the healthbar gets drawn above your cube
31.  if you now want to interact with your **MMHealthBar** and update it, you’ll need to pass it data to update it. We’ll use a script to do so.
32.  create a new C# class, call it **TestMMHealthBar**, and paste the following in it :

```
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MoreMountains.Tools;

/// <summary>
/// A simple class used to interact with a MMHealthBar component and test it
/// To use it, add it to an object with a MMHealthBar, and at runtime, move its CurrentHealth slider, and press the Test button to update the bar
/// </summary>
public class TestMMHealthBar : MonoBehaviour
{
    [Range(0f, 100f)]
    public float CurrentHealth = 50f;

    protected float _minimumHealth = 0f;
    protected float _maximumHealth = 100f;
    protected MMHealthBar _targetHealthBar;

    [MMInspectorButton("Test")] public bool TestButton;

    protected virtual void Awake()
    {
        _targetHealthBar = this.gameObject.GetComponent<MMHealthBar>();
    }

    public virtual void Test()
    {
        if (_targetHealthBar != null)
        {
            _targetHealthBar.UpdateBar(CurrentHealth, _minimumHealth, _maximumHealth, true);    
        }
    }
}
```

1.  add this component to your Cube, press play, and at runtime, move its CurrentHealth slider in its inspector. Every time you press the Test button, the health bar will update.

2.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
3.  in an empty scene (or your scene), create a new empty gameobject, name it “FloatingTextSpawner”, add a **MMFloatingTextSpawner component** to it.
4.  in your project panel, search for the MMFloatingText prefab, and drag it into the newly created spawner, under its Pooler settings, in the PooledSimpleMMFloatingText slot
5.  create a new empty object, call it “TestPlayer”, position it at 0,0,0, then add a **MMF Player** component to it
6.  add a new UI > **Floating Text** feedback to it
7.  press play in the editor, then the green Play button on your MMF Player, you’ll see a “100” text spawn every time

**Going further : adding intensity control**

*   to go further, you can check the “use intensity as value” to have it apply your MMF Player’s intensity to the feedback, like in the following class. To test it, create a new class in your project with the following code, then after the steps above, add the TestIntensityAsValue component to your MMF Player. Press play in the editor, then its TriggerFeedback button, a random value will pop every time. Of course you’ll likely want to pass it some damage value instead of a random one! You’ll notice the value isn’t rounded, if you’d like to change that, you can select a rounding method on your Floating Text feedback.

```
using MoreMountains.Feedbacks;
using UnityEngine;

public class TestIntensityAsValue : MonoBehaviour
{
	[MMFInspectorButton("TriggerFeedback")]
	public bool TriggerFeedbackButton;
	private MMF_Player _myPlayer;

	private void Start()
	{
		// on start we grab our MMF Player component
		_myPlayer = this.gameObject.GetComponent<MMF_Player>();
	}

	private void TriggerFeedback()
	{
		float randomIntensity = Random.Range(0f, 100f);
		_myPlayer.PlayFeedbacks(this.transform.position, randomIntensity);
	}
}
```

**Going even further : changing values at runtime**

*   you can also dynamically change the Value attribute of that MMF\_FloatingText to anything you want, as well as all its other properties. In the example below, we set the value to a random float, and the color to some fancy gradient.

```
using MoreMountains.Feedbacks;
using UnityEngine;

public class TestModifyAtRuntime : MonoBehaviour
{
	[MMFInspectorButton("TriggerFeedback")]
	public bool TriggerFeedbackButton;

	private MMF_Player _myPlayer;
	private Gradient gradient;
	private GradientColorKey[] colorKey;
	private GradientAlphaKey[] alphaKey;

	private void Start()
	{
		// on start we grab our MMF Player component
		_myPlayer = this.gameObject.GetComponent<MMF_Player>();
	}

	private void TriggerFeedback()
	{
		float randomValue = Mathf.Round(Random.Range(0f, 100f));
		MMF_FloatingText floatingText = _myPlayer.GetFeedbackOfType<MMF_FloatingText>(); // note that this assumes you only have one floating text feedback in your player, see docs for more advanced ways of grabbing it

		// we apply a random value as our display value
		floatingText.Value = randomValue.ToString();

		// we setup some fancy colors
		gradient = new Gradient();
		// Populate the color keys at the relative time 0 and 1 (0 and 100%)
		colorKey = new GradientColorKey[2];
		colorKey[0].color = Color.red;
		colorKey[0].time = 0.0f;
		colorKey[1].color = Color.blue;
		colorKey[1].time = 1.0f;
		// Populate the alpha  keys at relative time 0 and 1  (0 and 100%)
		alphaKey = new GradientAlphaKey[2];
		alphaKey[0].alpha = 1.0f;
		alphaKey[0].time = 0.0f;
		alphaKey[1].alpha = 0.0f;
		alphaKey[1].time = 1.0f;
		gradient.SetKeys(colorKey, alphaKey);

		floatingText.ForceColor = true;
		floatingText.AnimateColorGradient = gradient;

		_myPlayer.PlayFeedbacks(this.transform.position);
	}
}
```

TextMeshPro lets us add sprites into our text. Using that feature, it becomes very easy to use the FloatingText feedback to spawn not just text, but **images** too! It takes a bit of setup on TMP’s side though, so here are detailed steps to do so. Note that these steps focus only on how to setup the image, for more on how to setup floating texts, see [the dedicated recipe](https://feel-docs.moremountains.com/recipes.html#how-to-setup-floating-texts-to-play-them-via-feedbacks).

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  locate the **FeelDuck spritesheet** using the search bar of your project panel, select it, then go Assets > Create > TextMeshPro > Sprite Asset. This will create a sprite asset named FeelDuck.
3.  create a **Resources** folder in your project, and inside it put a “Sprite Assets” folder, move the sprite asset we just created into that folder, this will let TMP access it
4.  open the **FeelTactical** demo scene, unfold the “TacticalUnit - TMP Floating Text - Channel 1” object and find its child **ShootFeedback** object. Select it, and in its MMF Player, locate its **Floating Text feedback**. Uncheck UseIntensityAsValue, and in the Value field, type `<sprite="FeelDuck" index=0>`
5.  press play in the editor, then space to shoot, notice the left most cube now emits little ducks when shot

To learn more about how to setup sprites in TextMeshPro, and the various ways to access them, check out [TextMeshPro’s documentation](https://docs.unity3d.com/Packages/com.unity.textmeshpro@4.0/manual/RichTextSprite.html).

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  in a new scene, create a cube
3.  add a **MMWiggle component** to it
4.  check the **Position checkbox**, set its **Wiggle Type** to Noise, press play, you now have a wiggling cube
5.  you can now increase the frequency, amplitude, or add a shift (useful if you have more than one of these), and play with all the other options

The MMBlink component will let you define blinking sequences on objects, and you can then use a MMBlink feedback to trigger it. Here’s one way to set it up :

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  in a new scene, create a new sprite renderer, set its sprite to “button-A” (or any sprite of your choice)
3.  add a **MMBlink** component to it, set its Method to Material Alpha, and drag the Sprite Renderer into the MMBlink’s TargetRenderer slot
4.  then we’ll want to define our blink sequence, set the Phases array’s size to 2
5.  under the array’s Element 0, set PhaseDuration to 1, OffDuration to 0.3, OnDuration to 0.7
6.  under the array’s Element 1, set PhaseDuration to 0.5, OffDuration to 0.2, OnDuration to 0.3
7.  set the Repeat Count to -1 (which will have it repeat forever)
8.  press play, the sprite will now blink in repeating patterns

Now to have a **MMF Player** trigger it :

1.  uncheck Blinking on the MMBlink, and set the RepeatCount to 5
2.  create a new empty game object, call it MyTestFeedbacks, add a **MMF Player** to it
3.  add a new **MMBlink** feedback (renderer > MMBlink), and drag the MMBlink object into its TargetBlink slot
4.  press play in your editor, then press Play on the MyTestFeedbacks’ inspector’s test button, the sprite will blink for 5 sequences

The **MMBlink** component offers quite a few options, letting you blink objects by enabling/disabling objects, playing on their alpha, emission, or simply any float on their material’s shader. You can also have it lerp these values (change the Element0 and Element1’s On/Off Lerp Durations to 0.5 to test that)

Note : these steps use BiRP’s PostProcessing stack, if you’re using URP or HDRP, adapt these to use Volumes instead.

**Setting up post processing in our scene**

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene, add a Cube to it, position it at 0,0,0
3.  create a new empty object, name it Volume, add a PostProcessVolume to it, set IsGlobal:true, add a new profile to it (press the little “new” button in its inspector, or assign one), and add a LensDistortion effect override via the “add effect” dropdown, check the intensity checkbox
4.  on your scene’s main camera, add a PostProcessLayer, Layer:Everything

**Adding a spring to pilot it**

1.  select the PostProcessVolume, add a **MMSpringLensDistortionIntensity** component to it
2.  press play in the editor, then at the bottom of the MMSpringLensDistortionIntensity inspector, under the Test foldout, set tge TestBumpAmount to 5000, then press the green Bump button

From there, you can have any script call that method, or you can use a feedback to pilot this spring, like so :

1.  create a new empty object, add a MMF Player to it, add a Springs > SpringFloat feedback to it (our lens distortion intensity is a float value), drag the PostProcessVolume into its TargetSpring slot, set its BumpAmount to 5000
2.  press play in the editor, then the green Play button on your MMF Player

3.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
4.  in a new scene, add a Cube at 0,0,0
5.  select your MainCamera and add a MMSpringCameraFieldOfView component to it
6.  create a new empty object, add a MMF Player to it, add a Springs > SpringFloat feedback to it (field of view is a float value), drag the MainCamera into its TargetSpring slot, set its BumpAmount to 1000
7.  press play in the editor, then the green Play button on your MMF Player

### How to play a random sound with randomized volume?[](#how-to-play-a-random-sound-with-randomized-volume)

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new scene, open it
3.  create an empty object, add a **MMSoundManager** to it
4.  create another empty, add a **MMF Player** to it
5.  add a **MMSoundManager Sound feedback** to it
6.  set its random sfx array size to 2, set the first element to FeelBlobNote1, the second to FeelBlobNote2
7.  set the min volume to 0.2, max volume to 0.5
8.  press play in the editor, then press the green Play button at the bottom of your MMF Player, everytime you’ll play a new volume will be randomized

9.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
10.  create a new empty scene, add a Cube to it
11.  create a new empty object, name it Player, add a **MMF Player** to it
12.  add a **Flicker** feedback to it, drag the Cube into the BoundRenderer slot
13.  press Play in the editor, then the green Play button in the MMF Player’s inspector, your cube will flicker and return to its original color after 0.2s

### How to setup a shader controller and pilot it with a feedback?[](#how-to-setup-a-shader-controller-and-pilot-it-with-a-feedback)

Note : these steps use BiRP’s PostProcessing stack, if you’re using URP or HDRP, adapt these to use Volumes instead.

**Setting up our scene so that emission is visible**

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene, add a Cube to it, position it at 0,0,0
3.  create a new empty object, name it Volume, add a **PostProcessVolume** to it, set IsGlobal:true, add a new profile to it, and add a Bloom effect override, set its Intensity to 1
4.  on your scene’s main camera, add a **PostProcessLayer**, Layer:Everything
5.  set the Cube’s MeshRenderer to FeedbacksDemoBurger. Notice that this material’s shader exposes an \_EmissionForce float property, that controls (you guessed it) the strength of its emission

**Adding a shader controller**

1.  add a **ShaderController** component on the Cube, drag the MeshRenderer into its TargetRenderer slot, TargetPropertyName:\_EmissionForce
2.  press play in the editor, notice that the cube’s emission is now pulsating, as the shader controller is in PingPong mode by default

**Controlling the shader controller via a feedback**

1.  exit play mode, set the ShaderController’s ControlMode to OneTime
2.  create a new empty object, add a **MMF Player** to it, then add a Renderer > **ShaderController** feedback to it, drag the Cube into its TargetShaderController slot, OneTimeRemapMax:10
3.  press play in the editor, then press the green Play button on your MMF Player, the cube will glow and get back to its normal emission over 1s

4.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
5.  in a new scene, add a Cube at 0,0,0, and a UI>Button at 0,0,0
6.  in the Cube’s inspector, press the AddComponent button, and add a MMSpringSquashAndStretch component
7.  in the button’s inspector, add an item to the OnClick event, drag the Cube into it, and select MMSpringSquashAndStretch>BumpRandom
8.  press play in the editor, press the button (repeatedly!)
9.  while still at runtime, select the cube, and in its inspector, play with the Damping, Frequency, and BumpAmountRandomValue settings to see how they impact your object when you press the button

### How to setup a channel asset on a feedback and shaker?[](#how-to-setup-a-channel-asset-on-a-feedback-and-shaker)

In this example, we’ll setup a **scale shaker** and use a **scale shake feedback** to trigger it. The same logic applies to all shakers and feedbacks targeting them.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, create a new empty scene
2.  create a new Cube in the scene, position it at 0,0,0, add a **MMScaleShaker** to it
3.  press play, in its inspector, under the Test foldout, press the StartShaking button, notice our cube shakes its scale over half a second, exit play mode

We want to trigger that shaker from a feedback, so let’s establish our channel of communication, and let’s use a MMChannel asset for that, instead of a simple int.

1.  let’s first create a channel asset to have our feedback communicate with our shaker (of course if you already have some, you can skip this step), right ick in a folder in your project, and do Create > More Mountains > MMChannel. This will create a new **MMChannel asset**, which you can then rename. Let’s rename that one to MyFirstChannel.
2.  select your Cube, and on its **MMScaleShaker**, set ChannelMode to MMChannel, and drag MyFirstChannel into its MMChannelDefinition slot

We will now setup a feedback to trigger this same shake from a different object.

1.  create a new empty object, add a **MMF Player** component to it
2.  add a Transform > Scale Shake feedback to it
3.  unfold its Feedback Settings foldout, set Channel Mode to MMChannel, set MMChannelDefinition to MyFirstChannel
4.  press play in the editor, then press the green Play button on your **MMF Player**, the cube’s scale shakes

5.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
6.  in a scene containing a **MMSoundManager**
7.  create a UI button, press “+” on its OnClick action, drag your **MMSoundManager** in that slot, and select the **MuteMaster** method
8.  press play, pressing the UI button will mute all sounds playing through the MMSoundManager
9.  note that you can also do that via a feedback (MMSoundManager Track Control, or MMSoundManager All Sounds Control), and you can also decide to save this setting via a feedback, see http://feel-docs.moremountains.com/mmsoundmanager.html for more info on that!

The property feedback is extremely powerful as it lets you control the value of any property, on any component. In this example we’ll target a very simple component’s bool and float properties.

**Initial Setup**

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, create a new empty scene, add a Cube to it, add the following Test component to it

```
using UnityEngine;

public class Test : MonoBehaviour
{
  public bool Rotating = true;
  public float RotationSpeed = 100f;
  public Vector3 RotationAxis = Vector3.up;

  void Update()
  {
    if (Rotating)
    {
      this.transform.Rotate(Time.deltaTime * RotationSpeed * RotationAxis);
    }
  }
}
```

1.  press play, notice your cube rotates, exit play mode

**Controlling a bool property**

*   create a new empty object, name it MMF1, add a MMF Player component to it
*   add a GameObject>Property feedback to it, drag the Cube in its TargetObject field, Component:Test, Property:Rotating, Duration:2, RemapLevelZero:1, RemapLevelOne:0
*   press play in the editor, then the green Play button on MMF1, notice that when the curve’s value goes below 0.5 (the true/false threshold we’ve set), the target bool field becomes false (preventing the cube’s rotation), and then back to true again

**Controlling a float property**

*   create a new empty object, name it MMF2, add a MMF Player component to it
*   add a GameObject>Property feedback to it, drag the Cube in its TargetObject field, Component:Test, Property:RotationSpeed, Duration:2, RemapLevelZero:0, RemapLevelOne:500
*   press play in the editor, then the green Play button on MMF2, notice that the cube rotation speed change as our feedback increases then decreases its RotationSpeed field value

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene
3.  create a new, empty game object, add a **MMSoundManager** component to it
4.  create a new, empty game object, add a **MMF Player** to it, position it at 0,0,0
5.  add a **MMSoundManager Sound** feedback to it
6.  set its Sound/SFx to Beep1, SpatialBlend:1
7.  press play in the editor, then play your MMF Player, you’ll hear a beep
8.  move the MMF Player to 1000,0,0, play your MMF Player, you won’t hear it
9.  move the MMF Player to 25,0,0, play your MMF Player, you’ll hear it at reduced volume

### How to setup a signal broadcaster and receiver?[](#how-to-setup-a-signal-broadcaster-and-receiver)

Feel gives you access to a powerful signal emitter/receiver system, which lets you pilot one value by another. Let’s see an example where we drive the alpha of an Image with a randomly changing value.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
2.  add a UI Image at 0,0,0, add a CanvasGroup to it
3.  add an empty, call it Signal, add a **MMRadioSignalGenerator** to it, change the SignalType on the Signal List’s first element to Perlin Noise
4.  add an empty, add a **MMRadioBroadcaster** to it, in its TargetObject field, drag the Signal, Component:MMRadioSignalGenerator, Property:CurrentLevel
5.  on the Image, add a **MMRadioReceiver**, TargetObject: the Image, Component: CanvasGroup, Property: alpha, RelativeValue: false
6.  press play, notice how the alpha of the Image now flickers

From there, you can play with the signal definition on your MMRadioSignalGenerator to get interesting patterns!

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene, add a Canvas to it

**Option 1 : automatic shaker setup**

1.  create a new empty object, add a **MMF Player** to it, add a Camera > **Flash** feedback to it
2.  unfold its Automatic Setup foldout, press the **Automatic Shaker Setup** button
3.  press play in the editor, then the green Play button on your MMF Player, the screen will flash white

**Option 2 : manual setup**

1.  add an empty child to it, name it MyFlash, add a **MMFlash** component to it, stretch it so it covers your screen (one way to do that is to set your anchors to stretch, and set Left/Top/Right/Bottom to 0 on your RectTransform - but eventually how you do it is up to you, and depends on your Canvas and how your UI is setup), set the CanvasGroup component’s Alpha to 0
2.  create a new empty object, add a **MMF Player** to it, add a Camera > **Flash** feedback to it
3.  press play in the editor, then the green Play button on your MMF Player, tweak settings to your liking

4.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, create an empty scene, add a cube
5.  create an empty, add a MMF Player to it, add a Position feedback, set its target to the Cube, duplicate the feedback
6.  add a Pause feedback in between the 2 position ones, ScriptDriven:true, AutoResumeAfter:3, PauseDuration:0
7.  press play in the editor, press the green play button, the first position plays, then after 3s, the pause unlocks itself, and the second position plays
8.  press the green play button again, then instantly press the Resume button, notice the pause instantly stops and the 2nd position feedback plays

9.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
10.  create a new scene
11.  create a new cube, position it at 0,0,0
12.  add a **MMF Player** component to the cube, add a **Sound feedback** to it, set any audio clip in its Sfx slot, like FeelDuckQuack for example
13.  add a new **Animator** component to the cube
14.  create a new animator controller, call it CubeAnimatorController, drag it on the Animator component in its Controller slot
15.  open the Animation panel, create a new animation, call it BouncyCube
16.  add a new property to the animation, Transform:Position, press Record
17.  add a key at frame:0, with position to 0,0,0
18.  add a key at frame 20, with position 0,1,0
19.  copy frame 0, paste it at frame 60, you now have a cube that goes up and down
20.  put the cursor at frame 25, and press the **AddEvent** icon (right below the frame counter), in the inspector, in the Function dropdown, select PlayFeedbacks()
21.  press Play in the editor, your cube will bounce, and play a sound every time its animation passes frame 25. From there you can of course add and customize more feedbacks

Maybe you’re familiar with the concept of camera filters, moving filters you can move in front of an actual, physical camera to add effects, diffusion, etc. Feel comes with tools to setup something similar if you want to. It’s a bit of work, but can offer a lot of features once done, as it’ll let you move a post processing volume (or more than one) over your camera. This is an easy way to transition smoothly between post processing effects. Like for all other feedbacks, you’ll find an example of that in the MMF\_PlayerDemo scene, or you can follow the steps below (these use BiRP’s post processing stack v2, if you’re using another render pipeline, adapt the layer/volume accordingly, the filter will work on all pipelines):

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  in an empty scene, add a **PostProcessLayer** component to the MainCamera, VolumeBlending.Layer:Everything
3.  add an empty child object to the Camera at 0,0,0, name it MovingFilter
4.  add a BoxCollider to it, IsTrigger:true, then add a **PostProcessVolume** component to it, set its BlendDistance to 0.2 and pick the FeelBarbariansPostProcessingProfile as its Profile (it’s got a red vignette, you should see notice the difference as you pick it), then move that object to 0,3,0 so that it’s not covering the camera anymore.
5.  duplicate MovingFilter, name it BaseFilter, keep it a child of the MainCamera, and move it to 0,0,0 (so that it’s on top of the camera) and pick the FeelBlobPostProcessingProfile as its Profile (it’s got a purple vignette)
6.  now select your **MovingFilter** again, and add a **MMPostProcessingMovingFilter** to it, set its FilterOffset to 0,3, AddToInitialPosition:false, and on its PostProcessVolume component, set its Priority to 1
7.  create a new empty object in your scene, add a MMF Player to it, add a PPMovingFilter feedback
8.  press play in the editor, then press the green Play button on your MMF Player. You’ll notice a transition between the base post processing to the moving one. If you observe your scene in Scene view, you’ll notice as you play that feedback that the moving filter moves down to overlap the camera, taking priority

9.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
10.  create a new empty scene, add a Cube to it at 0,0,0
11.  create a new empty, name it MyPlayer, add a **MMF Player** to it
12.  add a Transform > **Position** feedback to it, leave its AnimatePositionTarget empty, and instead set AutomatedTargetAcquisition.Mode:ClosestReferenceHolder
13.  add a Feedbacks > **MMF Reference Holder feedback** to it, set GameObjectReference:Cube
14.  press play in the editor, then the green play button on MyPlayer’s inspector, the Position feedback automatically grabs its target from the closest reference holder (we only have one so it’s an easy choice) and makes the Cube move

15.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
16.  Create a new empty object, name it MMTimeManager, add a **MMTimeManager** component to it
17.  Create a new empty object, name it Test, add a **MMF\_Player** component to it
18.  Add a Time > Timescale Modifier feedback to your MMF Player
19.  Press play in the editor, then the green Play button on your MMF Player, time scale will slow down to half speed for 1 second, then come back to normal

### How to setup billboarding and a ghost camera?[](#how-to-setup-billboarding-and-a-ghost-camera)

Billboarding lets an object always face the camera. In these steps we set that up in a simple click, and also setup an easy to move ghost camera to try it out.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene
3.  add a sprite renderer to it, position it at 0,0,0, set its Sprite to button-A
4.  add a **MMBillboard** component to it
5.  on your scene’s MainCamera, add a **MMGhostCamera** component
6.  press play, use WASD, space and C to move around, notice the A circle keeps facing your camera

7.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, create a new, empty scene
8.  create a cube, position it at 0,0,0, add a **MMPositionShaker** component to it
9.  in its inspector, under ShakerSettings, set PlayOnAwake:true and PermanentShake:true
10.  press play, your cube will now shake at runtime. You can of course customize shake range and direction (and more) from its inspector
11.  now exit play mode, and set PlayOnAwake:false and PermanentShake:false, and we’ll create a feedback to trigger that movement on demand instead of having it always on
12.  create a new empty game object, name it “Player” and add a **MMF Player** component to it, then add a Transform > PositionShake feedback to it, via the “Add new feedback” dropdown
13.  under Feedback settings, you can define a **Channel** to target. Our shaker is already on Channel:0 so we’ll leave it like that
14.  press play in the editor, then press the green Play button on your MMF Player, the cube will shake
15.  still in play mode, let’s set ShakeSpeed:40, ShakeRange:1, Duration:0.75, ShakeMainDirection:1,0,0, DirectionalNoiseStrengthMax:1,1,1
16.  press the green play button again, your cube will now shake mostly horizontally, with some randomness on the direction, randomized every time you play it
17.  this component lets you customize things however you want, so feel free to explore it! You can also use the MMPositionShaker on rect transforms (make sure to set the appropriate Mode), and you’ll also find shakers for rotation and scale should you need them.

18.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
19.  create a new empty scene, add a UI > **Canvas** to it
20.  create an empty child object under that Canvas at 0,0, name it MyBar
21.  add a UI > **Image** under MyBar at 0,0, name it BackgroundBar, set its color to black, set its width to 300, and its Pivot.x to 0
22.  duplicate MyBar, name it DelayedBarDecreasing, color:orange
23.  duplicate DelayedBarDecreasing, name it DelayedBarIncreasing, color:yellow
24.  duplicate DelayedBarIncreasing, name it ForegroundBar, color:green
25.  now that you have your four bars on top of each other (with the green one showing first), add a **MMProgressBar** component to MyBar (careful, there are two MMProgressBar components in Feel, one is used for NV demos only, you want the one with the colored inspector. Go with Add Component > More Mountains > Tools > GUI > MM Progress Bar)
26.  unfold the top inspector group (Bindings) and drag your ForegroundBar and DelayedBars into their corresponding slots there
27.  under the FillSettings foldout, set SetInitialFillValueOnStart to true, and set InitialFillValue to 1, BarFillMode:FixedDuration
28.  press play in the editor, then at the bottom of the inspector, under the Debug foldout, press the Minus10 / Plus10Percent buttons, congratulations, you’ve got a working progress bar!

**Controlling our bar values via script**

Debug controls are fine and all, but you’ll probably want some script of yours to drive the values of the bar. Thanks to the progress bar API methods, that’s made very easy, all you’ll need will be a reference to the bar, and call one-liner methods. Let’s add the following class to your project (create a new class, name it TestBar, paste the following in it)

```
using UnityEngine;
using MoreMountains.Tools;

public class TestBar : MonoBehaviour
{
	// we'll want to drag and drop a progress bar into that slot to get a reference to our bar
	public MMProgressBar TargetProgressBar;
	// a value between 0 and 100, maybe in our game that'd be our main character's health value
	[Range(0f, 100f)] public float Value;
	// a test button to display in our inspector and let us call the ChangeBarValue method
	[MMInspectorButton("ChangeBarValue")] public bool ChangeBarValueBtn;

	void ChangeBarValue()
	{
		TargetProgressBar.UpdateBar(Value, 0f, 100f);
	}
}
```

1.  then, create a new empty object in the scene, add the TestBar component to it, drag MyBar into its TargetProgressBar slot
2.  press play in the editor, then set some Value using the slider in the TestBar inspector, and press the ChangeBarValue button

Of course in your own game, you probably would have that UpdateBar call in a method you call when your character takes damage, or uses its mana, whenever you want to update your bar’s value.

### How to add a squash and stretch behavior to an object?[](#how-to-add-a-squash-and-stretch-behavior-to-an-object)

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene
3.  create a new, empty object, name it TopLevel, position it at 0,0,0
4.  then, under it, create an empty child object, also at 0,0,0, name it SquashAndStretch, add a **MMSquashAndStetch** component to it
5.  finally create a cube, parent it under SquashAndStretch (you should now have 3 levels of hierarchy) at 0,0,0 too
6.  press play in your editor, select the TopLevel object and move it around, it will automatically squash & stretch

Let’s say you want to have a UI element grow bigger when the mouse cursor passes over it, and have it shrink back to its normal size when the mouse exits it. That’s easy to setup using feedbacks :

1.  create a new class, name it TestPointer, paste the following code into it :

```
using MoreMountains.Feedbacks;
using UnityEngine;
using UnityEngine.EventSystems;

public class TestPointer : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler
{
	public MMF_Player MyPlayer;

	public void OnPointerEnter(PointerEventData eventData)
	{
		MyPlayer.Direction = MMFeedbacks.Directions.TopToBottom;
		MyPlayer.PlayFeedbacks();
	}

	public void OnPointerExit(PointerEventData eventData)
	{
		MyPlayer.Direction = MMFeedbacks.Directions.BottomToTop;
		MyPlayer.PlayFeedbacks();
	}
}
```

1.  in a new, empty scene, add a UI Button, name it MyButton, position it at 0,0,0, add a TestPointer component to it
2.  add an empty child to the button, name it HoverFeedback, add a MMF Player to it
3.  add a Transform > Scale feedback to it, AnimateScaleTarget:MyButton, set all Tweens (X,Y,Z) to MMTween>EaseInCubic, AnimateScaleDuration:3
4.  select MyButton again, drag the HoverFeedback into its TestPointer’s inspector’s MyPlayer slot
5.  press play in the editor, put your cursor above the button, it’ll grow over 3s, move it out, it’ll shrink back

6.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
7.  in a new scene, add a Cube
8.  on a new empty object, add a **MMF Player**, add a **Position** feedback to it, set the Cube as its AnimatePositionTarget, set AnimatePositionDuration:4
9.  on a new object, add the TestCoroutine component (see below), drag the MMF Player into its MyPlayer slot
10.  press play, press the TestCoPlay button on it, the cube will start moving and a first debug log will be displayed in the console. After 4 seconds, as the MMF Player finishes playing, the end of the coroutine will run, displaying a new entry in the console.

```
using System.Collections;
using MoreMountains.Feedbacks;
using MoreMountains.Tools;
using UnityEngine;

public class TestCoroutine : MonoBehaviour
{
	public MMF_Player MyPlayer;

	[MMFInspectorButton("TestCoPlay")]
	public bool TestCoPlayBtn;

	private void TestCoPlay()
	{
		StartCoroutine(TestCoPlayCo());
	}

	private IEnumerator TestCoPlayCo()
	{
		MMDebug.DebugLogTime("start");
		yield return MyPlayer.PlayFeedbacksCoroutine(this.transform.position);
		MMDebug.DebugLogTime("end");
	}
}
```

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

6.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
7.  create a new, empty scene
8.  create a new empty object, name it Feedback, add a **MMF Player** component to it, then via its “Add new feedback” dropdown, add a Scene > **Load Scene feedback**
9.  set its SceneLoading/**DestinationSceneName** to FeelDuck (one of the Feel demos)
10.  open your **build settings** (File > Build Settings), then drag the **FeelDuck** scene from your Project view into the BuildSettings’ ScenesInBuild panel, then close the window
11.  do the same with the **MMAdditiveLoadingScreen** scene
12.  enter **play mode** in your editor, then press the **green Play button** on your MMF Player. The loading screen will appear, and transition to the new scene after it loads

### How to setup a squash and stretch feedback?[](#how-to-setup-a-squash-and-stretch-feedback)

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new empty, name it Container, reset its transform
3.  create a new Cube, name it Model, parent it under Container, position it at 0,0,0
4.  create a new empty, name it Player, add a **MMF Player** to it
5.  add a Transform > **Squash & Stretch** feedback to it, and drag Container into its SquashAndStretchTarget slot
6.  press play in the editor, then the green Play button on your MMF Player

7.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, create a new, empty scene
8.  create a new UI > Text (TMP) object, position it at 0,-200,0, set its FontAsset to Lato SDF, name it MyText
9.  create a new empty object, add a MMF Player to it, name it MyTextRevealFeedback
10.  using the Add new feedback dropdown, add a TMP Text Reveal feedback to it, set MyText as its TargetTMPText
11.  press play in the editor, then press MyTextRevealFeedback’s green Play button
12.  for a variant of it, exit play mode, check ReplaceText:true, NewText: This is fine, DurationMode:TotalDuration
13.  press play in the editor, then press MyTextRevealFeedback’s green Play button

14.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
15.  add a UI > Canvas, add an empty child to it, name it UIContainer, add a MMWiggle to it, check Position, uncheck WigglePermitted for it, add a MMCameraShaker
16.  add a UI Image at 0,0,0, parent it to the UIContainer, duplicate it at -300,0, and another time at 300,0 (you should now have a row of 3 white squares)
17.  create an empty, add a MMF Player to it, add a CameraShake feedback to it, Duration:0.5, Amplitude: 20, Frequency: 0.03
18.  press play in the editor, press play on the MMF Player, notice your entire UI panel now shakes for 0.5s

19.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
20.  open FeelSquashAndStretch demo scene
21.  add a Cube at 0,0,-2
22.  add a MMFollowTarget component to it, set its Target to PlayerCar, FollowPositionSpeed:0.05
23.  press play, use the keyboard arrows to drive around

24.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
25.  to have some visual to observe, create a cube at 0,0,0, add a MMAutoRotate to it
26.  add an empty, add a MMF Player to it, add a Freeze Frame feedback to it, set its duration to 0.1, press its automatic shaker setup button to automatically add a MMTimeManager to your scene
27.  press play in the editor, the cube will start spinning, play the MMF Player, notice how the cube tops spinning shortly

28.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
29.  add a Cube at 0,0,0
30.  add a Sphere at 3,0,0, we’ll use it as our PlayerCharacter for this example
31.  under the Cube, add an empty child, add a MMF Player to it, add a Position feedback, AnimatePositionTarget:Cube, DestinationPosition:0,1,0
32.  at the top of the MMF Player, unfold the MMF Player Settings foldout, unfold Range, set OnlyPlayIfWithinRange:true, RangeCenter:Sphere
33.  press play in the editor, press the green Play button on the MMF Player, notice the cube moves up
34.  select the sphere, move it to 8,0,0. The distance between the cube and the sphere is now 8, out of our range of 5), press the green Play button on the MMF Player, notice the cube doesn’t move anymore