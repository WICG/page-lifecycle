# A Lifecycle for the Web
## Motivation
For detailed motivation see [this doc](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.ejq0luje6eyb).

With large numbers of web apps (and tabs) running, critical resources such as memory, CPU, battery, network etc easily get oversubscribed, leading to a bad end user experience.
Application lifecycle is a key way that modern OS' manage resources. On Android, iOS and also more recent Windows versions, apps can be started and stopped at will by the platform. This lets the platform streamline and re-allocate resources where they best benefit the user.

On the web, we’ve tackled this with one-off features eg. reactive tab-discarding in extreme memory pressure - which can break websites.
While this is okay in the short term, in the long term it is important to incorporate first class support in the web platform, create the right incentive structure for web developers, and allow the system to proactively reallocate resources and avoid getting into extreme resource situations.

For a platform to support application lifecycle, it needs to both:
* provide developers with signals about transitions between the lifecycle states
* provide lifecycle-compatible APIs that allow key capabilities to work even when the app is backgrounded or stopped.

The web ecosystem lacks a clear lifecycle. This proposal attempts to define what the lifecycle of a web page is and add necessary extensions to enable supporting two important system interventions necessary for resource re-allocation:
* Tab discarding for memory saving
* CPU stopping for battery saving

Whereas mobile platforms have rich service-bound APIs that allow apps to deliver their experience when backgrounded, most of the web platform's capabilities are tab-coupled. Audio for instance only works when the tab is alive, so when a tab is killed in the background that plays audio, there is no way to keep that tab playing sound. A [list of background use-cases is here](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.5kyzj3e4880y). In an ideal world, web apps would be able to deliver the experience they want to their users, without having to rely on their page always being resident and running on the machine.

### Lifecycle States
![Lifecycle States](https://github.com/spanicker/web-lifecycle/blob/master/LifecycleStates.png)

For details on the app lifecycle states and definitions see [this doc](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.edtdhepwctwy).\
For more detail on bfcache usage [see here](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.79h8apoh4g7g).\
This proposal formalizes states for STOPPED and DISCARDED.

Lifecycle State | Visibility | Developer Expectation | System Interventions
--------------- | ---------- | --------------------- | --------------------
STOPPED | Not Visible | Hand off for background work and stop execution. | CPU suspension for battery saving: stop CPU after N minutes based on resource constraints
DISCARDED | Not Visible | System has discarded background tab to reclaim memory. If user revisits tab, this will reload the tab. | Tab discarding for memory saving: fully unloaded, no memory consumption.

### End-of-life scenarios
There are 3 high level scenarios for “end-of-life”.
#### 1. System Interventions
The system moves the app to STOPPED state and stops CPU usage, or the system moves the app to DISCARDED state and discards the app to reclaim memory. Handling this is in-scope for this proposal.\
For detailed Scenarios and Requirements, see the [list here](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.rsruvllnv993).
#### 2. User Exit
The user may close the tab (foreground or background) or navigate away OR on mobile, swipe the app away from task switcher. The user may background the app by minimizing the window OR on mobile by going to the homescreen and task switcher.\
**NOTE:** Handling user exit scenarios is out-of-scope for this proposal. We assume no changes there from today, although we try to be be consistent with existing handlers when reusing them.\
For categories of work that happen in end-of-life see the [list of End-of-life use-cases here](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.qftifuoc2315).
#### 3. Unexpected Termination
Apps can get killed in scenarios where it is not possible to deliver a callback, such as OOM crashes, OS kills the process under memory pressure, crashes or hangs due to browser bugs, device runs out of battery etc. Therefore it is possible for apps to transition from any state to TERMINATED without any callback being fired.\
**NOTE:** Improvements to handling unexpected termination is out-of-scope for this proposal.

## Proposal (MVP)
![Lifecycle Callbacks](https://github.com/spanicker/web-lifecycle/blob/master/LifecycleCallbacks.png)

We propose the following changes for the MVP:
* A `reason` attribute will be added to events for `pagehide` and `pageshow`; it will return an enum to indicate why the event fired, eg. due to transition to / from STOPPED, DISCARDED etc. 
* `pagehide` is fired to signal HIDDEN -> STOPPED. `reason` here is `stopped`.
* `pageshow` is fired to signal STOPPED -> ACTIVE. This will be used to undo what was done in `pagehide` above. `reason` here is `stopped`.
* `pageshow` is fired to signal DISCARDED -> ACTIVE. This will be used to restore view state persisted in `pagehide` above, when the user revisits a discarded tab. `reason` here is `discarded`.\

Suggestion for implementers: before moving app to DISCARDED it is recommended to run `beforeunload` handler and if it returns string (i.e. needs to show modal dialog) then the tab discard should be omitted, to prevent risk of data loss.

### Reusing existing callbacks vs. Adding new callbacks
We have chosen to reuse existing callbacks (pagehide, pageshow) vs. adding new callbacks. While this will cause some compat issues (eg. affects analytics reporting), it has the advantage of not adding complexity to the platform, easier for browsers to implement (faster time to ship) and consequently better story for adoption and long term interop. 
Reusing existing callbacks has significant trade-offs, for instance this makes it harder to impose restrictions, and support new capabilities.
For details on tradeoffs, see [this section in master doc](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.9tbw6aj3tl04).

### API sketch
**NOTE:** `persisted` attribute on pagehide indicates whether bfcache was involved.
```
enum TransitionReason { "discarded", "stopped", ... };

interface PageTransitionEvent : Event {
    ...
    readonly attribute TransitionReason reason;
}
```

Handle HIDDEN -> STOPPED
```
function handlePageHide(e) {
   // feature detect
   if (e.reason) { ...
   // Handle transition to STOPPED
   if (e.reason == “stopped”) {
     // handle state transition HIDDEN -> STOPPED
}
window.addEventListener("pagehide", handlePageHide);
```
NOTE: subsequently the app may get discarded, without firing another callback.

Handle STOPPED -> ACTIVE or DISCARDED -> ACTIVE
```

function handlePageShow(e) {
   // feature detect
   if (e.reason) { ...
   // Handle transition
   if (e.reason == “stopped”) {
     // handle state transition STOPPED -> ACTIVE
   } else if (e.reason == “discarded”) {
     // handle state transition DISCARDED -> ACTIVE
   }
}
window.addEventListener("pageshow", handlePageShow);
```
### Callbacks in State Transition Scenarios
* A. System stops (CPU suspension) background tab; user revisits\
[HIDDEN] -------------> `onpagehide` (`reason: “stopped”`) [STOPPED]\
--(user revisit)----> `onpageshow` (`reason: “stopped”`) [ACTIVE]

* B. System discards stopped tab; user revisits\
(previously called `onpagehide` (`reason: “stopped”`) ----> [STOPPED]\
----(tab discard)----> <no callback here> [DISCARDED]\
--(user revisit)----> [LOADING] -> `onpageshow` (`reason: “discarded”`) [ACTIVE]

* C. System discards background tab; user revisits\
[HIDDEN] ---(tab discard)------>\
`onpagehide` (`reason: “stopped”`) [STOPPED] ---(system tab discard)---> [DISCARDED]\
--(user revisit)----> [LOADING] -> `onpageshow` (`reason: “discarded”`) [ACTIVE]

State Transition | Lifecycle Callback | Trigger | Expected Developer Action
---------------- | ------------------ | ------- | -------------------------
ACTIVE -> HIDDEN | onpagevisibilitychange: hidden (already exists) | Desktop: tab is in background, or window is fully hidden; Mobile: user clicks on task switcher or homescreen | stop UI work; persist app state; report to analytics
HIDDEN -> ACTIVE | `onpagevisibilitychange`: `visible` (already exists) | User revisits background tab | undo what was done above; report to analytics
HIDDEN -> STOPPED | `pagehide`: (`reason: stopped`) OR (`reason: navigate`) for bfcache | System initiated CPU suspension; OR user navigate with bfcache | report to analytics; teardown, release resources; hand off for background work and stop execution. Save transient UI state in case app is moved to DISCARDED.
STOPPED -> ACTIVE | `pageshow`: (`reason: stopped`) | user revisits STOPPED tab or navigates back (bfcache) | undo what was done above; report to analytics
STOPPED -> DISCARDED | (no callback) | System initiated tab-discard | (no advance warning here)
DISCARDED -> ACTIVE | `pageshow`: (`reason: discarded`) | user revisits tab after system tab discard | restore transient UI state

### Restrictions and Capabilities in proposed callbacks
If excessive work is performed in the `pagehide` callback fired on STOPPED, there is a cost to this in terms of resource consumption i.e. CPU, network.
We need to strike a balance between enabling the system to move the app to STOPPED for conserving resources AND enabling the app to take action without consuming excessive resources in these callbacks.
To accomplish this, certain restrictions are needed in these callbacks, ideally:
- upper time limit in the callback i.e. allowed wall time eg. 5s
- upper limit on allowed CPU time
- Maybe restrictions on network eg. disallow network except sendBeacon / Fetch keep-alive

**NOTE:** Reusing existing callbacks makes it hard to impose these restrictions as it would cause inconsistency with pagehide / unload in user exit scenarios; however we are exploring what is possible here.

Separately, it is useful for apps to be able to do legitimate async work in these callbacks such as writing to IndexedDB. However this does not reliably work in pagehide / unload handler today. We are exploring support for [ExtendableEvent.waitUntil](https://developer.mozilla.org/en-US/docs/Web/API/ExtendableEvent/waitUntil) API to do async work eg. IndexedDB writes.

### Guarantess for end-of-life callbacks
**Should there be a guaranteed callback that fires in end-of-life scenarios?**

On user exit, the browser should guarantee that one callback will fire and finish, before the app is torn down. 
However, there is no “guaranteed” callback at the (very) time of system exit.
This is consistent with mobile platforms (Android and iOS):
- in Android [onPause](https://developer.android.com/reference/android/app/Activity.html#onPause()) is the guaranteed callback for user exit
- on iOS, the equivalent is [willResignActive](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive)
- On Android and iOS the system kills background apps that were previously stopped; corresponding callbacks have already fired beforehand (eg. onPause, onStop on Android), and there is no callback before system kill.

**What should be the “guaranteed” callback for the Web?**

We should align with the mobile model (Android and iOS) on the web. For this we need to ensure the following:
1. on user exit: only one callback is guaranteed to fire and complete
2. on system exit: above callback should have already fired, yet another callback is not guaranteed to fire (guarantee is simply not possible in many cases)

For #1, ideally all apps will transition through PASSIVE state before they can be killed and potentially we could, in the future, introduce a new callback here -- that is guaranteed.
In practice though, there is already a callback that is (almost) guaranteed - this is pagevisibility (although there are bugs in browsers, causing it to not fire in some cases).
For instance on mobile web, if the user goes to the homescreen OR task-switcher and then swipes away, then pagevisibility=hidden will fire (on homescreen, task-switcher) no other callback is fired on swipe (unload, pagehide etc).
So there is probably not a compelling reason to create another “guaranteed” callback, at the moment.

While unload callback is widely used, it is fundamentally unreliable, for instance it does not fire on mobile if user goes to task-switcher and then swipes. There are currently no plans to make unload more reliable. (The long term vision is to replace it with declarative APIs for desktop)

For #2, callback for STOPPED state is not guaranteed on user exit scenarios.
On system exit scenarios, typically STOPPED callback (and pagevisibility=hidden for sure) would have already fired previously BUT there is no guarantee that STOPPED callback *must* have fired.

### Further Reading
For details on the following topics see the Master Doc:
* [Persisting Transient View State](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.9u8nhnl3oez)
* [Handling Background Work and role of Service Worker](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.w3vi1ouug35y)
* [Alternatives Considered](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.ubo7g7vcr9ri)

