This page explains how you can use the MMTimeManager class to handle timescale changes in your game.

*   [What is the MM Time Manager?](#what-is-the-mm-time-manager)[](#what-is-the-mm-time-manager)
*   [Using the MM Time Manager](#using-the-mm-time-manager)[](#using-the-mm-time-manager)
*   [Using feedbacks to control time](#using-feedbacks-to-control-time)[](#using-feedbacks-to-control-time)
    *   [How to control the timescale using a feedback?](#how-to-control-the-timescale-using-a-feedback)[](#how-to-control-the-timescale-using-a-feedback)
*   [Controlling time via code](#controlling-time-via-code)[](#controlling-time-via-code)

Being able to manage your game’s **timescale** safely and efficiently is essential. Feel comes with a (completely optional) time scale manager, the **MMTimeManager**. It’s lightweight, very easy to use, and will let you implement slow down effects, free frames, or speed up your game in a smooth way using only one-liners.

![Jekyll](https://feel-docs.moremountains.com/images/mmtimemanager-1.png)

the MMTimeManager inspector

To start using the **MMTimeManager**, all you need to do is create a new empty object in your scene, optionally name it TimeManager, and via the Add Component menu, add a MMTimeManager to it. That’s it, you’re ready to control time!

You can now control the timescale, and don’t even have to use code to do so. The following steps will guide you through the setup of a simple feedback that will let you slow down time for a short moment.

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager, in an empty scene
2.  Create a new empty object, name it MMTimeManager, add a **MMTimeManager** component to it
3.  Create a new empty object, name it Test, add a **MMF\_Player** component to it
4.  Add a Time > Timescale Modifier feedback to your MMF Player
5.  Press play in the editor, then the green Play button on your MMF Player, time scale will slow down to half speed for 1 second, then come back to normal

You could also use a **Time > Freeze Frame** feedback to trigger (you guessed it) freeze frames.

Once you have a MMTimeManager in your scene, you can start controlling time from any script, simply by triggering **events**. Here are a few examples of the kind of calls you can make:

A simple use of the time manager is triggering freeze frames, stopping time for a very short duration, a game feel technique commonly used to put the spotlight on the impact of a hit. Here’s how you can trigger a short one:

```
MMFreezeFrameEvent.Trigger(0.05f);
```

The following line will, from any script, order the timescale to change to 0.5 (so time will appear slowed down by half), for 1 second, with a smooth transition. After that one second, the timescale will revert to normal on its own.

```
MMTimeScaleEvent.Trigger(MMTimeScaleMethods.For, 0.5f, 1f, true, 50f, false);
```

The last parameter in that call (infinite) can be used to alter a timescale permanently (until we change our mind about it). This next line will permanently change the timescale to 0.25 (so a quarter of normal speed):

```
MMTimeScaleEvent.Trigger(MMTimeScaleMethods.For, 0.25f, 0f, true, 50f, true);
```

And to get back to a normal timescale, it’s as simple as calling this line:

```
MMTimeScaleEvent.Unfreeze();
```

It’s important to note that the MMTimeManager lets you **stack timescale modifiers**. So you could for example have an event change the time scale from 1 to 5, then 2, then 0.5. If you were to call Unfreeze a first time, you’d go back to 2, call it again, you’re at 5, then one more time to go back to 1. This makes having multiple objects interact with the timescale very safe.

If you want to bypass the stack and just reset the timescale instantly to its normal state, you can use this line:

```
MMTimeScaleEvent.Reset();
```