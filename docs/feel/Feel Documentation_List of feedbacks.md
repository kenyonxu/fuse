This section lists all the Feedbacks included in the asset.

*   [Complete list of Feedbacks](#complete-list-of-feedbacks)[](#complete-list-of-feedbacks)
    *   [Animation](#animation)[](#animation)
    *   [Audio](#audio)[](#audio)
    *   [Camera](#camera)[](#camera)
    *   [Events](#events)[](#events)
    *   [GameObject](#gameobject)[](#gameobject)
    *   [Feedbacks](#feedbacks)[](#feedbacks)
    *   [HDRP Volume](#hdrp-volume)[](#hdrp-volume)
    *   [Loop](#loop)[](#loop)
    *   [Nice Vibrations](#nice-vibrations)[](#nice-vibrations)
    *   [Particles](#particles)[](#particles)
    *   [Pause](#pause)[](#pause)
    *   [Post Processing](#post-processing)[](#post-processing)
    *   [Renderer](#renderer)[](#renderer)
    *   [Scene](#scene)[](#scene)
    *   [Springs](#springs)[](#springs)
    *   [TextMesh Pro](#textmesh-pro)[](#textmesh-pro)
    *   [Time](#time)[](#time)
    *   [Transform](#transform)[](#transform)
    *   [UI](#ui)[](#ui)
    *   [UI Toolkit](#ui-toolkit)[](#ui-toolkit)
    *   [URP Volume](#urp-volume)[](#urp-volume)
    *   [Various](#various)[](#various)
    *   [Debug](#debug)[](#debug)
    *   [Want more?](#want-more)[](#want-more)

Feel comes loaded with **different types of feedbacks**. Some will focus or interact with a GameObject, some with the camera (or parts of it), some with third parties, and some just don’t fit in any specific category. Note that some of them are autonomous, and some will require the presence of another object, usually called **Shaker** (because it’s responsible for shaking stuff), put in your scene. This list explains it all, and if you want to know more, you can always look at the classes themselves, they’re all commented.

This page simply lists all feedbacks. If you want to know all the details about each of them, check out the API documentation.

*   **Animation Parameter** : lets you play any animation on an animator. Bind an animator to the feedback’s inspector, and it’ll let you update trigger and/or bool animation parameters.
*   **Animation Play State** : lets you play a state by its name, either in fixed or normalized time, and an example of it in action in the MMF\_PlayerDemo scene.
*   **Animator Speed** : lets you tweak the speed of your target animator at runtime
*   **Animator Cross Fade** : lets you cross fade your Animator to a specified state, over regular or normalized time
*   **Animation Sprite Sheet** : lets you animate target Sprite Renderers and/or Images with a simple list of sprites, without the need for an Animator component.

*   **AudioSource** : lets you play, pause, unpause or stop a preexisting audiousource on demand. You’ll also be able to play/pause/stop/resume it at a random pitch and volume, and through an optional audio mixer group.
*   **Sound** : another way to trigger a sound. You specify an audio clip, and then you can decide to have it instantiated on demand, cached, have it create an object pool of ready to use sounds, or even trigger a sound event. This feedback also lets you preview your sound from the editor. Note that by default it’s set to Event mode, which requires a MMSoundManager be present in the scene to catch it (or any other class of yours you’d like to catch such events). If you don’t plan on using a sound manager, Cached mode is probably what you’ll want to go with.
*   **AudioSource Pitch** : tweak an AudioSource’s pitch over time. You will need a MMAudioSourcePitchShaker on your target audiosource(s).
*   **AudioSource Stereo Pan** : alter the stereo pan value of an AudioSource over time. You will need a MMAudioSourceStereoPanShaker on your target audiosource(s).
*   **AudioSource Volume** : lets you tween the volume of an audio source over time. You will need a MMAudioSourceVolumeShaker on your target audiosource(s).
*   **Distortion Filter** : tween the distortion level of a distortion filter over time. You will need a MMAudioSourceDistortionShaker on your target audiosource(s), as well as a distortion filter.
*   **Echo Filter** : tween echo over time. You will need a MMAudioSourceEchoShaker on your target audiosource(s), as well as a echo filter.
*   **High Pass Filter** : tween the cutoff of a high pass over time. You will need a MMAudioSourceHighPassShaker on your target audiosource(s), as well as a high pass filter.
*   **Low Pass Filter** : tween the cutoff of a low pass over time. You will need a MMAudioSourceLowPassShaker on your target audiosource(s), as well as a low pass filter.
*   **Reverb Filter** : tween reverb levels over time. You will need a MMAudioSourceReverbShaker on your target audiosource(s), as well as a Reverb filter.
*   **AudioMixer Snapshot Transition** : lets you transition to a target snapshot over a specified duration
*   **MMPlaylist** : lets you remote control (play/pause/stop/previous/next/etc) a MMPlaylist from a feedback.
*   **MMSoundManager All Sounds Control** : control all sounds playing on a MMSoundManager
*   **MMSoundManager Save and Load** : save and load MMSoundManager settings (track volume, etc)
*   **MMSoundManager Sound** : lets you play a sound on the MMSoundManager
*   **MMSoundManager Sound Control** : lets you play/pause/resume/setVolume/more on a sound playing on the MMSoundManager
*   **MMSoundManager Sound Fade** : lets you fade sounds in/out on the MMSoundManager
*   **MMSoundManager Track Control** : lets you control entire tracks (music, UI, sfx, master) on a MMSoundManager
*   **MMSoundManager Track Fade** : lets you fade the tracks of the MMSoundManager

*   **Camera Shake** : simply shakes the camera over time, lets you specify a duration (in seconds), an amplitude and a frequency. For more advanced shakes, look at the Cinemachine Impulse feedback. This feedback requires a MMCameraShaker component on your camera. If you’re using Cinemachine, and want to use this feedback over the Cinemachine Impulse one, you’ll need a MMCinemachineCameraShaker on your virtual camera, and a noise setup on your virtual camera. To add a noise, select your virtual camera, in its Noise panel, select Basic Multichannel Perlin and pick a noise profile. When using the MMCameraShaker with a “regular” camera, or maybe your own camera controller, it’s best to use what is usually called a “camera rig”, a certain hierarchy in your camera setup that will guarantee good behaviour. You can find an example of it in the MMF\_PlayerDemo, under the “Camera & Lights” node. Basically the idea is to have a top level object with your camera controller, then nest another object under it, with the MMCameraShaker, and then under it nest your camera. You can of course have more nesting levels if needed.
*   **Camera Zoom** : lets you zoom in or out when the feedback plays, either for a specified duration, or until further notice. If you’re using a regular camera, you will need a MMCameraZoom component on it. If you’re using a Cinemachine virtual camera, you’ll need a MMCinemachineZoom component on it. This feedback also lets you work with relative values, adding to whatever the current zoom is at the moment the feedback plays.
*   **Flash** : flash an image on screen, or simply a color for a short duration. You’ll need an element (or more) with a MMFlash component on it in your scene for this feedback to interact with. Lets you specify color, alpha, and Flash ID for complete control over your flashes.
*   **Fade** : fades an image in or out, useful for transitions. This feedback requires an object with an MMFader component on it in your scene. From the feedback’s inspector you’ll be able to pick a transition curve, a target alpha, and a position. Can also be used to pilot MMFaderRounds.
*   **Field of View** : control a camera’s field of view over time. Will require a MMCameraFieldOfViewShaker on your camera, or a MMCinemachineFieldOfViewShaker on your virtual camera.
*   **Clipping Planes** : lets you tween the near and far clipping planes distances of a camera over time. This requires a MMCameraClippingPlanesShaker on your camera, or a MMCinemachineClippingPlanesShaker on your virtual camera if you’re using Cinemachine.
*   **Orthographic Size** : for orthographic/2D cameras only, lets you tween the camera’s size over time, basically zooming in or out. Will require a MMCameraOrthographicSizeShaker on your camera, or a MMCinemachineOrthographicSizeShaker on your virtual camera.
*   **Cinemachine Transition** : lets you transition to another virtual camera, using the blend of your choice, and auto managing other camera’s priorities. You’ll need a MMCinemachinePriorityListener on each of your virtual cameras for this to work. If you want more control, you can also add a MMCinemachinePriorityBrainListener on your Cinemachine brain. This will let you specify the transition to use to override the default one straight from the feedback.
*   **Cinemachine Impulse** : triggers a Cinemachine Impulse to shake your virtual cameras. You’ll need an impulse listener on your virtual camera for this to work. To add one, select your virtual camera, and at the bottom of its inspector there’s an “add extension” dropdown. Pick Cinemachine Impulse Listener from it. On the feedback’s inspector you’ll be able to tweak all sorts of things. To get started with it, pick a raw signal (click on the tiny cog icon next to the Raw Signal field, Presets > 6D Shake), and set the velocity at the bottom of the inspector to 1, 1, 1 for example. Then tweak to your liking! With control over attack, sustain, decay, scale, impact radius and more, it’s a very powerful tool. You can learn more about Impulses [in the Cinemachine documentation](https://docs.unity3d.com/Packages/com.unity.cinemachine@2.3/manual/CinemachineImpulseSourceOverview.html). And keep in mind that impulses are distance based, so make sure your virtual camera is in range of your emitter (in this case, the MMF\_Player’s transform), otherwise nothing will happen.
*   **Cinemachine Impulse Source** : lets you generate an impulse on a target Cinemachine Impulse source. Setup is done like for the Cinemachine Impulse feedback, except you’ll need a Cinemachine Impulse Source component, and you’ll still need a Cinemachine Impulse Listener on your virtual camera.
*   **Cinemachine Impulse Clear** : to cancel any Cinemachine Impulse that may be playing

*   **Unity Events** : lets you associate any sort of Unity event to a feedback, and lets you trigger them on play, stop, initialization or reset.
*   **MMGameEvent** : will trigger a MMGameEvent of the specified name when played.

*   **Destroy** : lets you destroy, destroy immediate or disable a specific game object
*   **Enable Behaviour** : enables or disables a monobehaviour when the feedback plays, inits, stops or resets.
*   **Float Controller** : possibly the most powerful of all the feedbacks, this one lets you control a float value on any monobehaviour. You’ll need a FloatController component on your target mono.
*   **Instantiate Object** : spawns objects when the feedback plays, at the specified position.
*   **Rigidbody** : adds force or torque to a Rigidbody
*   **Rigidbody2D** : adds force or torque to a Rigidbody2D
*   **Collider** : enable/disable/toggle a target collider, or change its trigger status
*   **Collider2D** : enable/disable/toggle a target collider 2D, or change its trigger status
*   **Property** : lets you target and control any property or field (floats, vectors, ints, strings, colors, etc), on any object (including ScriptableObjects), and control it over time. Drag a game object or scriptable object into its TargetObject slot, then select a component, and finally a property you want to affect. From there you can define remap options, and tweak your curve.
*   **Set Active** : sets an object active or inactive
*   **MMRadioSignal** : this feedback lets you control a MMRadioSignal, that can then be broadcasted to control receivers, to pilot any value you want on any component, on any object. Don’t hesitate to [read more about the MMRadio system](https://feel-docs.moremountains.com/mmradio.html), it can prove quite useful!
*   **MMRadio Broadcast** : similar to the MMRadioSignal one, but directly broadcasts the signal to any receivers, instead of going through an emitter

*   **Feedbacks Player** : lets you trigger other MMF\_Players within the specified range, or lets you specify a target MMF\_Player, in which case this feedback will match its target’s total duration
*   **MMF Player Chain** : lets you sequence multiple MMF Players together, playing them one after the other, with optional delays before and after them
*   **Player Control** : lets you trigger methods on one or more target MMF Players

*   **Bloom HDRP** : control bloom intensity over time
*   **Chromatic Aberration HDRP** : control the force of a chromatic aberration over time
*   **Channel Mixer HDRP** : control red, green and blue channels independently over time
*   **Color Adjustments HDRP** : lets you play with many color adjustments options : post exposure, saturation, hue shift, contrast…
*   **Depth of Field HDRP** : control HDRP Depth of Field focus distance or near/far ranges over time
*   **Film Grain HDRP** : lets you control the grain intensity over time
*   **Lens Distortion HDRP** : lens distortion on demand
*   **Motion Blur HDRP** : motion blur level over time
*   **Panini Projection HDRP** : tweak a panini projection’s distance and crop to fit over time
*   **Vignette HDRP** : control vignette parameters over time
*   **White Balance HDRP** : control white balance parameters over time

*   **Looper** : moves the current “head” of an MMF\_Player’s sequence back to another feedback above in the list. You can then have that sequence repeat any number of times of your choice, or indefinitely.
*   **Looper Start** : can act as a pause but also as a start point for your loops.

*   **Nice Vibrations Preset** : play a preset haptic, limited but super simple predifined haptic patterns.
*   **Nice Vibrations Emphasis** : play an Emphasis haptics, short haptic bursts whose amplitude and frequency can be controlled in real time, also called Transients in CoreHaptics/iOS.
*   **Nice Vibrations Clip** : use this feedback to play a .haptic clip, optionally randomizing its level and frequency.
*   **Nice Vibrations Continuous** : lets you play a continuous haptic of the specified amplitude and frequency over a certain duration. This feedback will also let you randomize these, and modulate them over time.
*   **Nice Vibrations Control** : interact with haptics at a global level, stopping them all, enabling or disabling them, adjusting their global level or initializing/release the haptic engine.

### Particles[](#particles)

*   **Particles Instantiation** : instantiate particles and play them. You can instantiate them on demand or cache them, and you can specify the position you want them at.
*   **Particles Play** : control (play, pause, stop, resume) an existing particle system. The feedback also lets you move it to the feedback’s position on demand.
*   **Visual Effect** : gives you control over a target visual effect and lets you play/pause/stop/etc.
*   **Visual Effect Set Property** : lets you set the value of a Property ID of any type on a target Visual Effect.

*   **Pause** : causes a pause in the feedbacks sequence when met, preventing any other feedback lower in the sequence to run until the pause is complete.
*   **Holding Pause** : holds until all previous feedbacks in the sequence, as well as this feedback’s pause have been executed.

All of these require their respective shaker on a PostProcessing Volume to function.

*   **Bloom** : control bloom intensity and threshold over time. You’ll need a MMBloomShaker on your post processing volume.
*   **Chromatic Aberration** : control the force of a chromatic aberration over time. You’ll need a MMChromaticAberrationShaker on your post processing volume.
*   **Color Grading** : lets you play with many color grading options : post exposure, saturation, hue shift, contrast… You’ll need a MMColorGradingShaker on your post processing volume.
*   **Depth of Field** : lets you control depth of field focus distance, aperture and focal length over time. You’ll need a MMDepthOfFieldShaker on your post processing volume.
*   **Global PP Volume Auto Blend** : tween a PostProcessing volume’s weight.
*   **Lens Distortion** : lens distortion on demand. You’ll need a MMLensDistortionShaker on your post processing volume.
*   **PP Moving Filter** : move a post processing filter in or out of the camera.
*   **Vignette** : control vignette parameters over time. You’ll need a MMVignetteShaker on your post processing volume.

*   **Flicker** : lets you rapidly change the color of a material. By default this will control the target renderer’s shader’s Color value but the feedback also lets you specify your own if you want. Comes with flicker duration, octave and color control. You can also provide a list of extra target renderers, in which case all will flicker at once.
*   **Fog** : lets you animate the density, color, end and start distance of your scene’s fog
*   **Material** : changes the material of the target renderer everytime it’s played, out of an array of materials. You can swap them sequentially or randomly.
*   **Line Renderer** : lets you update a line renderer’s width and color over time.
*   **Material Set Property** : set the value of the property of your choice on the target renderer’s material.
*   **MMBlink** : controls an MMBlink, letting you do advanced blinking behaviours, either by enabling/disabling a gameobject, changing its alpha, emission intensity, or a value of your choice on a shader), with or without interpolation, and will let you define repeat patterns and phases.
*   **Shader Controller** : similar to the Float Controller, lets you control most settings of any shader. Will require a ShaderController component on your target (or targets, it lets you control more than one at once)
*   **Shader Global** : lets you control global shader properties at runtime.
*   **Sprite** : change the sprite on a target sprite renderer
*   **SpriteRenderer** : take control of a SpriteRenderer’s color and X or Y flip
*   **SpriteRenderer Alpha** : lets you animate the alpha of a target sprite renderer over time, regardless of its color
*   **Skybox** : lets you assign a new material (at random or not) to change the scene’s skybox to a new one
*   **TextureOffset** : lets you control a target renderer’s material’s texture offset over time
*   **TextureScale** : lets you control a target renderer’s material’s texture scale over time
*   **Trail Renderer** : lets you update a trail renderer’s length, width and color over time

*   **LoadScene** : lets you load a destination scene using various methods, either native or using MMTools’ loading screens
*   **UnloadScene** : lets you unload a scene, specified either via its build index or name

*   **Float Spring** : control any float spring (vignette intensity, light, timescale, and so many more), either directly or via event.
*   **Vector2 Spring** : control any Vector2 spring (texture offset, etc)
*   **Vector3 Spring** : control any Vector3 spring (position, scale, etc)
*   **Vector4 Spring** : control any Vector4 spring
*   **Color Spring** : control any Color spring (light color, sprite color, image, etc)

*   **TextMeshPro Font Size** : lets you modify the size of a TMP’s font over time
*   **TextMeshPro Text** : lets you modify the text of a target TMP text component
*   **TextMeshPro Character Spacing** : change horizontal spacing between characters in your TMP text over time
*   **TextMeshPro Count To** : lets you update a target TMP text with a float or rounded value going from A to B over time
*   **TextMeshPro Count To Long** : same as CountTo, but using long instead of floats (useful to count up to really big numbers)
*   **TextMeshPro Word Spacing** : change horizontal spacing between words in your TMP text over time
*   **TextMeshPro Line Spacing** : change vertical spacing between lines in your TMP text over time
*   **TextMeshPro Paragraph Spacing** : change vertical spacing between paragraphs in your TMP text over time
*   **TextMeshPro Color** : change text color over time
*   **TextMeshPro Alpha** : change text alpha over time
*   **TextMeshPro Outline Width** : change a text’s outline width over time
*   **TextMeshPro Outline Color** : change a text’s outline color over time
*   **TextMeshPro Dilate** : will tweak the position of the text contour in the distance field
*   **TextMeshPro Softness** : will let you animate the softness of the text contour
*   **TextMeshPro TextReveal** : lets you reveal a target text character by character, word by word, or line by line, over time

All Time related feedbacks use the **MMTimeManager API**. If you decide to use any of these, and plan on modifying the timescale in other places in your scripts, it’s best to do all timescale changes via this API. The Time Manager handles a pile of timescales, letting you, for example, slow down an already slowed timescale for a short time, then come back to it. If you bypass it and access the timescale API directly, it won’t know about your changes and this will lead to issues. If you don’t want to use it, you’ll want to consider creating dedicated feedbacks that target your own time scale API.

*   **Freeze Frame** : freeze the timescale for a short duration of your choice. Requires a **TimeManager** in your scene.
*   **Time Modifier** : complete control over time, slow it down, speed it up, with optional customizable interpolation. You can also trigger Change or Reset time modifications, letting you change the timescale to a new one indefinitely, or reset it to its previous value, respectively. Requires a **TimeManager** in your scene.

*   **Position** : lets you tweak the position of a transform over time with different modes : A to B will move the object from an initial to a destination position, at the specified speed, duration and acceleration. Along Curve will move the object along the defined curve, with remapped values, on any or all of the 3 axes. To Destination will move the object to the specified destination.
*   **Rotation** : lets you play with the rotation of a transform over time, packed with options. Similar to the position feedback, you can rotate an object in absolute mode, additive (adding to its current rotation at the start of the play), or to a defined destination.
*   **Scale** : lets you animate the scale of a transform over time. Comes with similar options and settings as the Position and Rotation feedbacks.
    
*   **Position Spring** : move or bump a target’s position using a spring.
*   **Rotation Spring** : move or bump a target’s rotation using a spring.
*   **Scale Spring** : move or bump a target’s scale using a spring.
*   **Squash & Stretch Spring** : move or bump a target’s scale by squashing & stretching it using a spring.
    
*   **Wiggle** : lets you play with rotation, scale and position over time. You’ll need an MMWiggle component on your target object for this to work.
*   **Rotate Position Around** : lets you rotate a target object around another center object, with full axis control.
*   **DestinationTransform** : lets you animate all properties (position, rotation, scale) of a transform to match a destination transform’s properties
*   **SquashAndStretch** : modify the scale of an object on an axis while the other two axis (or only one) get automatically modified to conserve mass. This requires a normalized scale (see note below).
*   **Position Shake** : lets you activate a target position shaker. The shaker will move its target object’s position for the specified duration, within a certain range and along a certain direction. You can control the randomness of that shake, as well as its attenuation over time. This requires one or more MMPositionShaker(s).
*   **Rotation Shake** : lets you activate a target rotation shaker. The shaker will move its target object’s position for the specified duration, within a certain range and along a certain direction. You can control the randomness of that shake, as well as its attenuation over time. This requires one or more MMRotationShaker(s).
*   **Scale Shake** : lets you activate a target scale shaker. The shaker will move its target object’s position for the specified duration, within a certain range and along a certain direction. You can control the randomness of that shake, as well as its attenuation over time. This requires one or more MMScaleShaker(s).
*   **Look At** : lets you rotate a Transform to have it face another target transform (or a direction, or specific world coordinates), complete with optional axis locks and event/shaker support, in which case you’ll need a MMLookAtShaker on your target(s).
*   **Set Parent** : lets you change the parent Transform of a target Transform

**An important note about scale:** When dealing with scale (squash and stretch, scale shake, scale spring, etc), you’ll want to make sure the Transform you’re targeting has a normalized scale of 1,1,1. That doesn’t mean you can’t use these feedbacks on Transforms with other scales, you just need to parent them under container objects to do so. Here’s an example of a hierarchy: MyCharacter (your prefab main object, maybe with some logic, CharacterController etc, scale 1,1,1)

*   MyModelContainer (an optional container for your model, scale 1,1,1)
*   *   MySquashAndStretchContainer (an empty object, scale 1,1,1 that you target with your S&S feedback)
*   *   *   MyActualModel (your Mesh Renderer, scale can be anything you want)

Note that this decoupling can also be useful in plenty of other situations (rotating an object on multiple axis at various speeds, achieving complex translations, etc).

*   **ImageRaycastTarget** : this feedback will let you control the RaycastTarget parameter of a target image, turning it on or off on play
*   **CanvasGroup** : lets you control a CanvasGroup’s alpha over time
*   **CanvasGroupBlocksRaycasts** : lets you turn the BlocksRaycast parameter of a target CanvasGroup on or off on play
*   **Graphic** : lets you change the color of a target Graphic over time
*   **Graphic CrossFade** : lets you trigger cross fades on a target Graphic
*   **Image** : lets you play with the color of an Image over time
*   **Image Alpha** : lets you play with the alpha of an Image over time
*   **Image Fill** : lets you play with the fill of an Image over time
*   **Image Material** : lets you change the material of the target Image
*   **Image Sprite** : lets you change the sprite of the target Image
*   **Image Texture Offset** : animate an Image’s texture offset over time
*   **Image Texture Scale** : animate an Image’s texture scale over time
*   **Raycast Target** : lets you control the RaycastTarget parameter of a target image, turning it on or off on play
*   **RectTransformAnchor** : lets you control a RectTransform’s min and max anchor positions over time
*   **RectTransformPivot** : lets you control the position of a RectTransform’s pivot point over time
*   **RectTransformOffset** : lets you control the offset of the lower left corner of the rectangle relative to the lower left anchor, and the offset of the upper right corner of the rectangle relative to the upper right anchor
*   **RectTransformSizeDelta** : lets you animate the size of this RectTransform relative to the distances between the anchors, over time
*   **Floating Text** : lets you easily spawn floaty text (usually damage text, but not limited to that)
*   **Text** : lets you control the contents of a target Text
*   **TextColor** : lets you change the color of a target Text over time
*   **TextFontSize** : lets you alter the font size of a target text over time
*   **VideoPlayer Feedback** which will let you control video players in all sorts of ways (Play, Pause, Toggle, Stop, Prepare, StepForward, StepBackward, SetPlaybackSpeed, SetDirectAudioVolume, SetDirectAudioMute, GoToFrame, ToggleLoop)

A word of caution: [UI Toolkit](https://docs.unity3d.com/Manual/UIElements.html) is Unity’s “new” UI system, separate from the “old” Canvas one. Feel supports both equally, so you’re free to pick and use the one you prefer. The following feedbacks are dedicated to UI Toolkit. UI Toolkit feedbacks behave mostly like other feedbacks, but due to how Unity built that system, there are a few things to know before using them :

*   because UI Toolkit isn’t supported the same way on all Unity editor versions, all of these feedbacks, and their associated demo, are in a UnityPackage within the asset that you need to extract first. In your project panel, search the **FeelUIToolkitPackage** unitypackage, and double click on it to import its contents
*   for all UI Toolkit feedbacks, you’ll need to specify your UIDocument in the TargetDocument field, pick a QueryMode (either Name or Class), then define a Query (the element name or class name to look for in your UI Document to find the object you want to impact). This has to return one or more elements. If your query returns more than one element, all of them will be impacted by the feedback
*   make sure you check the **FeelUIToolkitFeedbacksDemo** scene, it showcases all of these feedbacks in action
    
*   **Background Color** : interpolate background color over time
*   **Border Color** : control border color over time
*   **Border Radius** : change the radius of UI elements’ borders over time
*   **Border Width** : change the width of elements’ borders over time
*   **Class** : lets you modify the classes on target UI elements
*   **Font Size** : change the font size of a target UI element
*   **Image Tint** : change the tint of a target image
*   **Opacity** : change the opacity of a visual element over time
*   **Rotate** : rotate one or more target visual elements
*   **Scale** : change the scale of one or more target visual elements
*   **Size** : change the size of one or more target visual elements
*   **Stylesheet** : attach a new stylesheet to your UI Document
*   **Text** : replace a text with a new one
*   **TextColor** : change a text’s color over time
*   **Transform Origin** : lets you move the point of origin where rotation, scaling, and translation occur
*   **Translate** : translate a UI element
*   **Visible** : lets you toggle a visual element’s visibility on and off

All of these require their respective URP shaker on a Volume to function. Make sure you pick the URP versions of the shaders and feedbacks when working with URP, it won’t work otherwise.

*   **Bloom URP** : control bloom intensity over time
*   **Chromatic Aberration URP** : control the force of a chromatic aberration over time
*   **Color Adjustments URP** : lets you play with many color adjustments options : post exposure, saturation, hue shift, contrast…
*   **Depth of Field URP** : lets you control depth of field parameters over time
*   **Global PP Volume Auto Blend URP** : tween a PostProcessing volume’s weight
*   **Lens Distortion URP** : lens distortion on demand
*   **Motion Blur URP** : motion blur level over time
*   **Panini Projection URP** : tweak a panini projection’s distance and crop to fit over time
*   **Vignette URP** : control vignette parameters over time
*   **White Balance URP** : control white balance parameters over time

*   **Light** : complete control over a light’s intensity and color over time
*   **Light 2D** : complete control over a URP 2D light’s intensity and color (and more) over time

*   **DebugBreak** : causes a Debug.Break() when the feedback is played
*   **DebugComment** : lets you store a text in its inspector, useful if you want to leave a note of why you setup a feedback a certain way, for example. Can optionnally output it to the console.
*   **DebugLog** : lets you output debug messages to the console, using different methods (MMDebug, warning, error, log, etc)

The list is always growing, and suggestions are welcome, so don’t hesitate to [drop me a line with your idea](https://feel.moremountains.com/feel-contact)! There’s also a [public contributions repository](https://github.com/reunono/FeelExtensions) you can check, where you’ll find, among other things, feedbacks for DOTween or Unity’s 2D light system.