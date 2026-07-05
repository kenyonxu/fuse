This page covers the many ways you can use the MMRadio system.

*   [What’s MMRadio?](#whats-mmradio)[](#whats-mmradio)
*   [How to use MMRadio?](#how-to-use-mmradio)[](#how-to-use-mmradio)
*   [Radio Signals](#radio-signals)[](#radio-signals)
*   [Using MMRadio with feedbacks](#using-mmradio-with-feedbacks)[](#using-mmradio-with-feedbacks)

**MMRadio** is a system born out of the frustration of wanting to control properties from other objects, and always writing custom code for it. It’s a system meant to be used **without having to write a line of code**, both to read properties on any object, and to write new values. It’s called MMRadio because its main intended use lets you have a **Broadcaster** read and “broadcast” a value on an object, that can then be listened by many **Receivers**, that can then use that input to drive values on their own targets.

Let’s say you have a giant GTA-like level, and for some reason you’d like every lamp in the level to reflect the health of the character (healthy : very bright lights, damaged : almost off lights). You could have a class on your lamps look at the health of the character, but it’s probably gonna be costly. A better pattern would be to have your character trigger an event every time it gets hit. Lamps can then listen to it, and change their intensity. MMRadio lets you do that without a single line of code, and will only have a (very low) cost when the value changes, so it’s as efficient as can be.

You can see an example of **MMRadio** in the **MMRadioDemo** scene (Feel/MMTools/Tools/MMRadio). If you press play you’ll see a bunch of cubes move all at once at relatively high speed. They’re all driven by a broadcaster (**TestBroadcaster**, in the hierarchy panel). You can study it, or disable it for now, as we’ll create a new one.

Create an empty object, add a **MMRadioBroadcaster** component to it. In its Emitter slot drag the Cube1 object from the hierarchy. In **Component**, select Transform, and in **Property** select position. In TargetAxis leave X. The rest can stay as default for now, but you’ll see that you can define remap rules, and a channel to broadcast on. The rest of the scene is already setup to listen to Channel 0, so you can move on. Press play, nothing should happen. That’s normal. Now select the **Cube1** object, and move it on the X axis (that’s the red one), you should see all the other cubes move on their Y axis in sync with your cube. That’s the MMRadio system at work.

You can select any of the other cubes to see how they’re setup. All of them have a **MMRadioReceiver** component, where we also target the position property, but this time we specify that we want to modify the y axis. You can also define random multipliers, remap rules, and a channel to listen to.

As we’ve seen, we can use **any value** on **any object** to broadcast. So any class in your game can do the trick. But there are also ready made “**signal**” classes that you can use, that will continuously (or once) emit a level you can then broadcast. So the default way to use them is to add them to the same object as your broadcaster, or nested under it, and then drag that object in your Broadcaster’s TargetObject slot, select your signal in the Component dropdown, then its Level property.

Feel comes with two of these built-in (and a MMRadioSignal abstract class you can extend to create your own signals) :

*   **MMRadioSignalAudioAnalyzer** : this one will let you target a MMAudioAnalyzer and listen to a specific beat
*   **MMRadioSignalGenerator** : this one will let you create and customize a signal by combining base curves. You can tweak a lot of parameters to get something unique, from the Duration of your signal (in seconds), to its curve components. You can add and combine sine waves, pulse, sawtooth, animation curves, noises, tweens etc to craft your own unique signal. The live preview makes it very easy.

You can also use a feedback to trigger your signals if you want. The **MMFeedbackRadioSignal** is designed just for that. Add it just like any other feedback, and from its inspector you’ll be able to set a target signal, and it’ll also let you define a duration, global multiplier and timescale. This is meant to be used with **OneTime** mode signals only.