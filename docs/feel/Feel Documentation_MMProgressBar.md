This section explains how to use Feel to create juicy progress bars in your game

*   [Introduction](#introduction)[](#introduction)
*   [Setup](#setup)[](#setup)
    *   [How to setup a MM Progress Bar?](#how-to-setup-a-mm-progress-bar)[](#how-to-setup-a-mm-progress-bar)
*   [Progress bar customization](#progress-bar-customization)[](#progress-bar-customization)
*   [More ways to control the bar via script](#more-ways-to-control-the-bar-via-script)[](#more-ways-to-control-the-bar-via-script)
*   [MM Health Bars](#mm-health-bars)[](#mm-health-bars)
    *   [How to use the MMHealthBar component to automatically draw health bars?](#how-to-use-the-mmhealthbar-component-to-automatically-draw-healt)[](#how-to-use-the-mmhealthbar-component-to-automatically-draw-healt)

Progress bars are one of the **most common UI elements** in games. They’re a great way to visualize a number vs a total number, and whether it’s health, stamina, mana, ammo, time left to escape a dreadful dungeon, there’s a good chance your game will need a few bars too. And while making a progress bar isn’t exactly rocket science, crafting one that **looks and feels good** is an art.

The **MMProgressBar** component solves this struggle, and will give you juicy progress bars in no time, with an easy to use API to control them. It will let you animate the properties of some UI elements (usually Images) to reflect a value between 2 bounds.

What that component does is control a number of “bars” (typically that’ll be a horizontal rectangle, but this can work with circles, squares, images, anything you want) : a **ForegroundBar**, representing the current value of the bar, and two optional delayed bars. The **DelayedBarDecreasing** will “lag” behind the foreground bar when the bar value decreases. This lets the Player see what has been lost. The **DelayedBarIncreasing** will move first when the bar value increases, and the foreground bar will lag behind it, showing the Player what has been gained.

That progress bar can be anywhere in your game, from your HUD to in-world canvas, it’s up to you.

You’ll find examples of the MMProgressBar in action **in the FeelMMProgressBar demo scene**.

Setting up a MMProgressBar is very easy. In the following steps, we’ll setup a very basic one, using simple rectangles as our bars.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new empty scene, add a UI > **Canvas** to it
3.  create an empty child object under that Canvas at 0,0, name it MyBar
4.  add a UI > **Image** under MyBar at 0,0, name it BackgroundBar, set its color to black, set its width to 300, and its Pivot.x to 0
5.  duplicate MyBar, name it DelayedBarDecreasing, color:orange
6.  duplicate DelayedBarDecreasing, name it DelayedBarIncreasing, color:yellow
7.  duplicate DelayedBarIncreasing, name it ForegroundBar, color:green
8.  now that you have your four bars on top of each other (with the green one showing first), add a **MMProgressBar** component to MyBar (careful, there are two MMProgressBar components in Feel, one is used for NV demos only, you want the one with the colored inspector. Go with Add Component > More Mountains > Tools > GUI > MM Progress Bar)
9.  unfold the top inspector group (Bindings) and drag your ForegroundBar and DelayedBars into their corresponding slots there
10.  under the FillSettings foldout, set SetInitialFillValueOnStart to true, and set InitialFillValue to 1, BarFillMode:FixedDuration
11.  press play in the editor, then at the bottom of the inspector, under the Debug foldout, press the Minus10 / Plus10Percent buttons, congratulations, you’ve got a working progress bar!

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

The MMProgressBar inspector lets you customize the bar to your liking. Under its various foldouts, you’ll find fields to control every aspect of it. While most fields are self explaining, here’s a list of the main options :

*   **Bindings** : you’ll want to drag your foreground and delayed bar(s) into the corresponding slots. PlayerID is just an ID you can use to identify the bar, for example when trying to access it from another script
*   **Fill Settings** : Lets you define where the bar’s fill value when the current value is 0 or 1, lets you set an optional automatically filled value on start (you may want to leave that to false and handle that initialization in your code). Then you can define bar direction, fill mode (if you go for FillAmount, make sure you’re using an Image set to Filled type), and a timescale to work on. Finally, BarFillMode lets you have the bars move on a fixed duration (it’ll always take Xs for the bar to from one point to another, regardless of the distance) or SpeedBased, where the bar will take longer to cross bigger gaps
*   **Bar settings** : for each bar, you’ll be able to set speeds and durations (which one will be used depends on your BarFillMode), as well as movement curves for them
*   **Bump** : the bar comes with built-in “bump” feedbacks, letting you change the scale and color of the bar automatically every time the value changes. You can decide to have that “bump” on increase or on decrease (or on both), and you can set an intensity multiplier, to have bigger bumps on bigger value changes
*   **Events** : the bar exposes Unity Events for every step of its life cycle, from bump to movement start/stop. This lets you plug in other components (typically a MMF Player) to enhance your bar further. You can look at the **FeelMMProgressBar demo** for an example of that, where the HorizontalBar triggers various MMF Players when the bar decreases and increases.
*   **Text** : optionally, you can bind a Text or TextMeshPro component to your bar, and its text value will be updated along with the bars. You can add a prefix and suffix, display (or not) the total value, and define a text format for the display
*   **Debug** : a set of buttons that let you update or set the bar to the value set in the DebugNewTargetValue slider, force a bump, or move the bar by 10% increments
*   **Debug Read Only** : 4 sliders showcasing the progress of the bar in realtime (don’t touch these, they’re read only)

Like for all other classes in Feel, you’ll find more info about its methods [in the API documentation](http://feel-docs.moremountains.com/API/class_more_mountains_1_1_tools_1_1_m_m_progress_bar.html), or in the class itself (like all classes, it’s fully commented), but here are the main ways to interact with a bar. In all the code lines below, **TargetProgressBar** is a reference to a MMProgressBar.

There are two main types of methods to change the value of a bar, Update and Set. Update will change the value and trigger a bump (a visual feedback potentially impacting the scale, color of the bars, having them lerp to position), while Set methods won’t cause a bump, virtually teleporting the bar to the final state

```
// updates the bar to the specified value, between a min and a max that you specify, causing a bump 
TargetProgressBar.UpdateBar(Value, SomeMinValue, SomeMaxValue);
// so for example, this would put a bar at 50% : 
TargetProgressBar.UpdateBar(20f, 0f, 40f);
// updates the bar to the specified normalized value, a value between 0f and 1f, causing a bump
TargetProgressBar.UpdateBar01(NormalizedValue);
// so for example, this would put a bar at 50% : 
TargetProgressBar.UpdateBar01(0.5f);

// instantly sets the bar value to the specified value, without causing a bump
TargetProgressBar.SetBar(Value, SomeMinValue, SomeMaxValue);
// instantly sets the bar value to the specified normalized value, without causing a bump
TargetProgressBar.SetBar01(NormalizedValue);
```

Make sure to check the [API documentation](http://feel-docs.moremountains.com/API/class_more_mountains_1_1_tools_1_1_m_m_progress_bar.html) for more info on the various methods you can use to control your bars!

The **MMHealthBar** component leverages the power of the MMProgressBar and gives you an out of the box solution to add a health bar (or any bar really) to any object in one click. That (health) bar will live in the world (as opposed to an overlay UI), and will follow the object you attach it to, with options to billboard, hide automatically, do things on death, etc. It’s a neat component to use if you want little MM Progress Bars that live in the world and don’t necessarily want to control every aspects of them. Here are steps to set one up :

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  create a new, empty scene
3.  create a cube, position it at 0,0,0
4.  add a **MMHealthBar component** to it
5.  press play, you’ll notice the healthbar gets drawn above your cube
6.  if you now want to interact with your **MMHealthBar** and update it, you’ll need to pass it data to update it. We’ll use a script to do so.
7.  create a new C# class, call it **TestMMHealthBar**, and paste the following in it :

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