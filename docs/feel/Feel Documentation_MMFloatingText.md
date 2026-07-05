This section explains how to use the MMFloatingText system to spawn texts in your game world

*   [Introduction](#introduction)[](#introduction)
*   [Setup](#setup)[](#setup)
    *   [How to setup floating texts to play them via feedbacks?](#how-to-setup-floating-texts-to-play-them-via-feedbacks)[](#how-to-setup-floating-texts-to-play-them-via-feedbacks)

It’s quite frequent that in a game you’ll want to communicate to the player some values on screen, at the spot where they’re relevant. This can be damage numbers, produced currencies, or even some text messages, it’s up to you!

Feel makes it **easy** to add floating texts that feel good to your game.

You can find an example of floating damage texts in the **FeelTactical demo scene**. Damage texts feedbacks require a **MMFloatingTextSpawner**, and in this scene you’ll find three different one (one per shooter/cube), nested under the Managers node. Each Tactical shooter has a **ShootFeedbacks** bound to it, and each triggers (among other things) a Floating Text feedback. Each of these targets a specific Channel, and is in turn caught one of the three MMFloatingTextSpawners (the one with the matching Channel).

*   the first spawner spawns very basic floating texts
*   the second one spawns feedback powered texts, that will play a MMF\_Player once spawned, in this case animating the rotation, position, color and spacing of the texts
*   the third one spawns TextMeshPro floating texts

1.  in Unity 6000.0.23f1 (or higher), create a new project and import Feel v5.8 via the Package Manager
2.  in an empty scene (or your scene), create a new empty gameobject, name it “FloatingTextSpawner”, add a **MMFloatingTextSpawner component** to it.
3.  in your project panel, search for the MMFloatingText prefab, and drag it into the newly created spawner, under its Pooler settings, in the PooledSimpleMMFloatingText slot
4.  create a new empty object, call it “TestPlayer”, position it at 0,0,0, then add a **MMF Player** component to it
5.  add a new UI > **Floating Text** feedback to it
6.  press play in the editor, then the green Play button on your MMF Player, you’ll see a “100” text spawn every time

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