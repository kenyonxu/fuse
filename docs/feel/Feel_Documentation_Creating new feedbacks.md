This section explains all there is to know to create a new MMFeedback.

*   [Creating a new feedback](#creating-a-new-feedback)[](#creating-a-new-feedback)
*   [Modifying an existing feedback](#modifying-an-existing-feedback)[](#modifying-an-existing-feedback)
*   [The MMF\_FeedbackBase class](#the-mmf_feedbackbase-class)[](#the-mmf_feedbackbase-class)
*   [Extensions Repository](#extensions-repository)[](#extensions-repository)

Creating a new feedback is very easy. Create a new class, have it inherit from MMF\_Feedback, and override the methods you’re interested in (usually CustomInitialization, CustomPlayFeedback, CustomStopFeedback and CustomReset). You can look at each feedback for a reference of how it’s done, they’re all heavily commented. Here’s a template you can use as a starting point :

```
using UnityEngine;
using MoreMountains.Tools;

namespace MoreMountains.Feedbacks
{
    [AddComponentMenu("")]
    [FeedbackHelp("You can add a description for your feedback here.")]
    [FeedbackPath("ChosenPath/MyFeedbackNameGoesHere")]
    public class MMF_MyFeedbackName : MMF_Feedback
    {
        /// a static bool used to disable all feedbacks of this type at once
        public static bool FeedbackTypeAuthorized = true;
        /// use this override to specify the duration of your feedback (don't hesitate to look at other feedbacks for reference)
        public override float FeedbackDuration { get { return 0f; } }
        /// pick a color here for your feedback's inspector
    		#if UNITY_EDITOR
    			public override Color FeedbackColor { get { return MMFeedbacksInspectorColors.DebugColor; } }
    		#endif

    		protected override void CustomInitialization(MMF_Player owner)
    		{
    			base.CustomInitialization(owner);
    			// your init code goes here
    		}

        protected override void CustomPlayFeedback(Vector3 position, float feedbacksIntensity = 1.0f)
        {
            if (!Active || !FeedbackTypeAuthorized)
            {
                return;
            }            
            // your play code goes here
        }

        protected override void CustomStopFeedback(Vector3 position, float feedbacksIntensity = 1)
        {
	        if (!FeedbackTypeAuthorized)
	        {
		        return;
	        }            
	        // your stop code goes here
        }
    }
}
```

Sometimes you find a feedback that does **almost** what you’re after, but not exactly. In situations like that, you have a few options :

*   **create a new feedback entirely** : this will work, but it may be a waste of time to redo everything another feedback already does, and it’ll make for a lot of duplicated code
*   **modify the existing feedback** : this is also possible, but you may lose your changes the next time you update Feel
*   **inherit from the current feedback and change its behavior** : that’s usually the recommended option, it’s the fastest, cleanest and safest way to do it

Inheriting from an existing feedback and extending it is done just like for any other class in C#. You can learn more about how it’s done [in Unity’s documentation](https://learn.unity.com/tutorial/inheritance).

Let’s go over a simple example : let’s say we’re using the **TextMeshPro Count To** feedback to display our current in-game credits, maybe at the end of a level, to have that text display go from 0 to the collected amount. It’s all working fine, but we’d like to add a dollar sign at the end of it. Smarter people might say we could just add another text element next to it, with our dollar sign. But for the sake of the demonstration, what if we wanted to have the feedback itself add a suffix to the same text element?

That’s easily done with **inheritance**. The first thing to do is figure out what script to extend. The name of feedbacks in Feel **always starts with the ‘MMF\_’ prefix**. You can usually find a feedback via the search bar in your editor’s Project panel, simply type its name. In our case, we want to extend MMF\_TMPCountTo. Let’s do it :

```
using MoreMountains.Feedbacks;
using UnityEngine;

// here you specify how to access that feedback in the "Add Feedback" dropdown
[FeedbackPath("TextMesh Pro/TMP Count To With Suffix")]

// we declare the name of our class, and specify it inherits from MMF_TMPCountTo
public class MMF_TMPCountToSuffix : MMF_TMPCountTo
{
    // we want this new feedback to display a suffix, so we create a new string we'll add to our text
	public string Suffix = "$";

    // we override the UpdateText method, which is the only part of the feedback we want to change,
    // the rest will behave as it did before
	protected override void UpdateText(float currentValue)
	{
        // we call the base method, as we want it to run unchanged, we just want to do an extra thing at the end
        // of course that's not mandatory, and we could have changed entirely how that method behaves by simply not calling base
		base.UpdateText(currentValue);
        // we add our suffix to our TextMeshPro
		TargetTMPText.text = TargetTMPText.text + Suffix;
	}
}
```

Now we can just remove our old feedback, and start using this new one in its place. Extending feedbacks is a great way to use their existing power and adapt it to your exact project specs. If, while extending a feedback, you feel like the current feedback’s structure isn’t ideal, never hesitate to use the [support form](https://feel.moremountains.com/feel-contact) to request changes to it, Feel is designed to be extended upon, and is constantly improving on that aspect. All suggestions are welcome!

Feedbacks come with a base class you can extend if your use case applies. That abstract class is designed to handle cases where your feedback is meant to modify one or more values (float, vector, color, int, bool, etc) over time, or instantly. Good examples would be the alpha of a CanvasGroup, or the volume of an AudioSource.

If your use case matches, then using that class as a base will save you a lot of time. You can look at the MMF\_CanvasGroup for a reference of how it’s done.

```
using MoreMountains.Tools;
using UnityEngine;
using UnityEngine.Scripting.APIUpdating;

namespace MoreMountains.Feedbacks
{
  /// <summary>
  /// This feedback lets you control the opacity of a canvas group over time
  /// </summary>
  [AddComponentMenu("")]
  [FeedbackHelp("This feedback lets you control the opacity of a canvas group over time.")]
  [MovedFrom(false, null, "MoreMountains.Feedbacks.MMTools")]
  [FeedbackPath("UI/CanvasGroup")]
  public class MMF_CanvasGroup : MMF_FeedbackBase
  {
    /// sets the inspector color for this feedback
    #if UNITY_EDITOR
    public override Color FeedbackColor { get { return MMFeedbacksInspectorColors.UIColor; } }
    public override bool EvaluateRequiresSetup() { return (TargetCanvasGroup == null); }
    public override string RequiredTargetText { get { return TargetCanvasGroup != null ? TargetCanvasGroup.name : "";  } }
    public override string RequiresSetupText { get { return "This feedback requires that a TargetCanvasGroup be set to be able to work properly. You can set one below."; } }
    #endif
    public override bool HasAutomatedTargetAcquisition => true;
    protected override void AutomateTargetAcquisition() => TargetCanvasGroup = FindAutomatedTarget<CanvasGroup>();

    // below we declare a number of properties that are specific to our use case
    // for each value you'll want to have a MMTweenType curve to move over,
    // a target, remap zero and one values, and a value to apply on instant

    [MMFInspectorGroup("Canvas Group", true, 12, true)]
    /// the receiver to write the level to
    [Tooltip("the receiver to write the level to")]
    public CanvasGroup TargetCanvasGroup;
    /// the curve to tween the opacity on
    [Tooltip("the curve to tween the opacity on")]
    [MMFEnumCondition("Mode", (int)MMFeedbackBase.Modes.OverTime)]
    public MMTweenType AlphaCurve = new MMTweenType(new AnimationCurve(new Keyframe(0, 0), new Keyframe(0.3f, 1f), new Keyframe(1, 0)));
    /// the value to remap the opacity curve's 0 to
    [Tooltip("the value to remap the opacity curve's 0 to")]
    [MMFEnumCondition("Mode", (int)MMFeedbackBase.Modes.OverTime)]
    public float RemapZero = 0f;
    /// the value to remap the opacity curve's 1 to
    [Tooltip("the value to remap the opacity curve's 1 to")]
    [MMFEnumCondition("Mode", (int)MMFeedbackBase.Modes.OverTime)]
    public float RemapOne = 1f;
    /// the value to move the opacity to in instant mode
    [Tooltip("the value to move the opacity to in instant mode")]
    [MMFEnumCondition("Mode", (int)MMFeedbackBase.Modes.Instant)]
    public float InstantAlpha;

    public override void OnAddFeedback()
    {
      base.OnAddFeedback();
      RelativeValues = false;
    }

    // this method is where the magic happens.
    // we create a base target and a receiver. We bind our receiver's object
    // and specify what property we want to impact on it
    // then we setup our MMF_FeedbackBaseTarget, and finally we add it to our list of targets. That's all!
    protected override void FillTargets()
    {
    	if (TargetCanvasGroup == null)
      {
        return;
      }
    	MMF_FeedbackBaseTarget target = new MMF_FeedbackBaseTarget();
    	MMPropertyReceiver receiver = new MMPropertyReceiver();
    	receiver.TargetObject = TargetCanvasGroup.gameObject;
    	receiver.TargetComponent = TargetCanvasGroup;
    	receiver.TargetPropertyName = "alpha";
    	receiver.RelativeValue = RelativeValues;
    	target.Target = receiver;
    	target.LevelCurve = AlphaCurve;
    	target.RemapLevelZero = RemapZero;
    	target.RemapLevelOne = RemapOne;
    	target.InstantLevel = InstantAlpha;
    	_targets.Add(target);
    }
  }
}

```

If you create a new feedback and think others might benefit from it, or if you’re looking for more feedbacks or Feel tools, you can check the [Feel Extensions Repository on Github](https://github.com/reunono/FeelExtensions). Contributions are of course always welcome!