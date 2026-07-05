
This is the documentation for Feel, the best way to add game feel to your game, available on Unity's Asset Store.

*   [What is Feel?](#what-is-feel)[](#what-is-feel)
*   [Why is it great?](#why-is-it-great)[](#why-is-it-great)
*   [What’s the best way to update Feel from an old version to a new one?](#whats-the-best-way-to-update-feel-from-an-old-version-to-a-new-one)[](#whats-the-best-way-to-update-feel-from-an-old-version-to-a-new-one)
*   [Does it work everywhere ?](#does-it-work-everywhere-)[](#does-it-work-everywhere-)
*   [Can I import FEEL into other MoreMountains assets?](#can-i-import-feel-into-other-moremountains-assets)[](#can-i-import-feel-into-other-moremountains-assets)

**Feel** is a ready-to-use solution to provide **on-demand game feel** to your Unity game, with as little friction or setup as possible. It’s a **modular**, **user friendly**, and **very easy to extend** system you can build upon.

I strongly believe **game feel** (or juice, or microinteractions, or feedbacks) is one of the most important parts of game design.

Making sure the player understands the consequences of their actions is the best way to make sure interactions are rewarding and engaging. Providing proper feedback when the player makes an action, or when something significant happens in the game is mandatory. Whether it’s a screenshake, a flash, an object’s scale bumping, or all of these at once, it will only make the experience more **satisfying**.

You can learn more about feedbacks in Martin Jonasson and Petri Purho’s talk [“Juice it or lose it”](https://www.youtube.com/watch?v=Fy0aCDmgnxg), the wonderful “[Art of screenshake](https://www.youtube.com/watch?v=AJdEqssNZ-U)” talk by Jan Willem Nijman, or my own talk about [game feel and fast prototyping at Unite Los Angeles in 2018](https://www.youtube.com/watch?v=NU29QKag8a0), or this one in Copenhagen in 2019 :

Implementing these kinds of feedbacks isn’t necessarily rocket science, shaking a camera is quite an easy task. But after working on tons of games and prototypes, I’ve found myself often going back to the same game feel recipes, and I wanted to remove as much friction as possible between an idea for a feedback and its in-game implementation. Initially created for (and built into) the **[TopDown Engine](https://assetstore.unity.com/packages/templates/systems/topdown-engine-89636?aid=1011lKhG)** and **[Corgi Engine](https://assetstore.unity.com/packages/templates/systems/corgi-engine-2d-2-5d-platformer-26617?aid=1011lKhG)**, I’ve decided to make this system public, hoping it’ll help people improve the feel of their game.

![An example of MMFeedbacks in action](https://moremountains.com/assets/resources/mmfeedbacks/DemoScreenshake.gif)

Whatever you do, **make sure you have a commit / backup to rollback to if a problem happens**. Then, remove the old Feel folder, and import the new one.

If you don’t remove the old version, due to the way the Asset Store importer works, some scripts may be duplicated, not removed, etc. Depending on what version you’re updating from, and what version you’re updating to, you may have some light refactoring to do. Make sure you [check the release notes](https://feel.moremountains.com/feel-releases) to see what changed and what may have an impact on your own code.

If you’re updating from a version older than 4.0, be aware that this update **phases out the legacy MMFeedbacks component**, and with it the auto updater that was active since the 3.0 days. **Convert your MMFeedbacks before updating**, if you’re still using any.

The short answer is yes, **Feel works on all platforms Unity supports**. Feel’s scripts are **well optimized**, and come at as low a cost as possible. That said, Feel targets native APIs and systems in Unity, and doesn’t change their cost. So typically, post processing effects will be costly on mobile, regardless of whether you use Feel or not. Feel won’t prevent you from using feedbacks to instantiate a billion particle systems if you want to, but for sure this won’t work well on Switch. And so on. So really the question you should ask yourself is what you plan on using Feel with. Make sure you have a frame budget, and the things you have Feel act upon fit within that budget.

If you’re using the Corgi Engine, Infinite Runner Engine, Nice Touch or TopDown Engine, they **already include MMFeedbacks and MMTools** (or parts of them), the two main components of FEEL, so importing FEEL on top is usually not needed. If you decide to do so, some of the common libraries may be out of sync.

Make sure you always remove the oldest ones (remove the Feel folder if you had one, remove the MMFeedbacks and MMTools folders if you had them), import the new ones, and be prepared to refactor a few things. You can also simply uncheck the common libraries folders on import. Or just wait a little while for the next engine update.

Note that if you plan on using it with Highroad Engine, you’ll likely have some refactor to do, which isn’t recommended if you’re new to C#. They have some libraries in common and they’re out of sync at the moment. That will be fixed in upcoming updates to these two assets.