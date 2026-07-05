This page explains how to use the finite state machine included in Feel.

*   [What’s a state machine?](#whats-a-state-machine)[](#whats-a-state-machine)
*   [Creating a state machine](#creating-a-state-machine)[](#creating-a-state-machine)
*   [Listening to state changes](#listening-to-state-changes)[](#listening-to-state-changes)

A **state machine** (or finite state machine) is a mathematical model of computation. It is an abstract machine that can be in **exactly one** of a finite number of **states** at any given time. It’s a **design pattern** frequently used in games, to keep track of the state of a character, of a weapon, of the progress of a character, etc.

Feel comes with a simple class, **MMStateMachine**, that you can use if you want to, which handles state machines, storing states, and triggering events to act on these changes.

The class below shows you a typical use case of a state machine. This class simulates a character controller, reading input and “*jumping*” or “*dashing*” based on it. To test it, simply create a new empty scene, create a new empty game object, call it “*MyTestCharacter*”, and add a MyCharacter component to it. Once you press play, a debug on-screen console will display the **current state** of your “*character*”. Once you start pressing space, D or R, it’ll change state to new ones.

```
using MoreMountains.Tools;
using UnityEngine;

/// a demo class of a very basic character controller. It reads input and updates a state machine.
public class MyCharacter : MonoBehaviour
{
    /// we declare all the possible states for our finite state machine
    public enum MovementStates { Null, Idle, Walking, Running, Dashing, Jumping }
    /// we declare our state machine, and specify it'll work on MovementStates
    public MMStateMachine<MovementStates> MovementState;

    /// on Awake we initialize our state machine
    private void Awake()
    {
        MovementState = new MMStateMachine<MovementStates>(this.gameObject, true);
    }

    /// on Update we look for input and trigger our character controller's methods accordingly
    /// each of these methods change the current state of our character on our state machine
    /// In a real controller they would also apply forces, move our character around, change its speed, etc
    private void Update()
    {
        if (Input.GetKeyDown("space"))
        {
            Jump();
        }
        if (Input.GetKeyDown("d"))
        {
            Dash();
        }
        if (Input.GetKeyDown("r"))
        {
            Run();
        }

        // we also output the current state to our on-screen debug console
        MMDebug.DebugOnScreen("Current Character State", MovementState.CurrentState);
    }

    private void Jump()
    {
        MovementState.ChangeState(MovementStates.Jumping);
    }

    private void Dash()
    {
        MovementState.ChangeState(MovementStates.Dashing);
    }

    private void Run()
    {
        MovementState.ChangeState(MovementStates.Running);
    }
}
```

From any class, this system lets you **listen** to state changes, and act on them. It then becomes very easy to do things “*when exiting the jump state*” or “*when entering the dashing state*”. The following class shows you how it’s done. To test it, in the same scene as before, on the same object, or on another in your scene, add a **MyListeningClass** component.

```
using MoreMountains.Tools;
using UnityEngine;

/// an example of a listening class that will act when the character changes state
public class MyListeningClass : MonoBehaviour, MMEventListener<MMStateChangeEvent<MyCharacter.MovementStates>>
{
    // on enable we start listening for event changes   
    private void OnEnable()
    {
        this.MMEventStartListening<MMStateChangeEvent<MyCharacter.MovementStates>>();
    }

    // on disable we stop listening for event changes
    private void OnDisable()
    {
        this.MMEventStopListening<MMStateChangeEvent<MyCharacter.MovementStates>>();
    }

    // when we catch a new state change event, we can then play any logic we want
    public void OnMMEvent(MMStateChangeEvent<MyCharacter.MovementStates> movementStateEvent)
    {
        // we can do stuff based on the new state our state machine is now in
        switch (movementStateEvent.NewState)
        {
            case MyCharacter.MovementStates.Jumping:
                Debug.Log("we're jumping now");
                break;
            case MyCharacter.MovementStates.Dashing:
                Debug.Log("we're dashing now");
                break;
        }

        // or based on the state it was in previously
        switch (movementStateEvent.PreviousState)
        {
            case MyCharacter.MovementStates.Running:
                // we can also always get a reference to the gameobject that triggered the event
                Debug.Log("object "+movementStateEvent.Target+" was running but we're not running anymore");
                break;
        }
    }
}
```