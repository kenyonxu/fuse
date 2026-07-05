This page explains what MMTools are and how to use them

*   [What’s MMTools?](#whats-mmtools)[](#whats-mmtools)
*   [MMTools Recipes](#mmtools-recipes)[](#mmtools-recipes)
    *   [How to make an object wiggle in your scene?](#how-to-make-an-object-wiggle-in-your-scene)[](#how-to-make-an-object-wiggle-in-your-scene)
    *   [How to use the MMHealthBar component to automatically draw health bars?](#how-to-use-the-mmhealthbar-component-to-automatically-draw-healt)[](#how-to-use-the-mmhealthbar-component-to-automatically-draw-healt)
    *   [Setting up a MMBlink component](#setting-up-a-mmblink-component)[](#setting-up-a-mmblink-component)

MMTools is a collection of helpers and systems used by most, if not all, MoreMountains assets.

They’re included in Feel, and you’re free to use them in any project you want. Don’t hesitate to explore and experiment with them, they’re all commented and documented in details in the API documentation.

While more documentation on MMTools is still on its way, this video should give you a first tour of some of its contents :

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  in a new scene, create a cube
3.  add a **MMWiggle component** to it
4.  check the **Position checkbox**, set its **Wiggle Type** to Noise, press play, you now have a wiggling cube
5.  you can now increase the frequency, amplitude, or add a shift (useful if you have more than one of these), and play with all the other options

6.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
7.  create a new, empty scene
8.  create a cube, position it at 0,0,0
9.  add a **MMHealthBar component** to it
10.  press play, you’ll notice the healthbar gets drawn above your cube
11.  if you now want to interact with your **MMHealthBar** and update it, you’ll need to pass it data to update it. We’ll use a script to do so.
12.  create a new C# class, call it **TestMMHealthBar**, and paste the following in it :

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