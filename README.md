# A Lifecycle for the Web
## Background
For detailed motivation see [this doc](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#).

With large numbers of web apps (and tabs) running, critical resources such as memory, CPU, battery, network etc easily get oversubscribed, leading to a bad end user experience.
Application lifecycle is a key way that modern OS' manage resources. On Android, iOS and also more recent Windows versions, apps can be started and stopped at will by the platform. This lets the platform streamline and re-allocate resources where they best benefit the user.

On the web, we’ve tackled this with interventions on behalf of end users and built one-off features eg. reactive tab-discarding in extreme memory pressure - which can break websites. 
While this is okay in the short term, in the long term it is important to incorporate first class support in the web platform, create the right incentive structure for web developers, and allow the system to proactively reallocate resources and avoid getting into extreme resource situations.

For a platform to support application lifecycle, it needs to both provide developers with signals about transitions between the lifecycle states, AND provide lifecycle-compatible APIs that allow key capabilities to work even when the app is backgrounded or stopped.
The web ecosystem lacks a clear lifecycle. This proposal attempts to define what the lifecycle of a web page is and then add some extensions to enable formalizing new lifecycle states in a developer friendly way. For example, we want to suspend CPU in background tabs in some cases, similar to how some browsers do so with in-memory back-forward caches (aka bfcache).

Whereas mobile platforms have rich service-bound APIs that allow apps to deliver their experience when backgrounded, most of the web platform's capabilities are tab-coupled. Audio for instance only works when the tab is alive, so when a tab is killed in the background that plays audio, there is no way to keep that tab playing sound. A [list of background use-cases is here](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.5kyzj3e4880y). In an ideal world, web apps would be able to deliver the experience they want to their users, without having to rely on their page always being resident and running on the machine.

### Lifecycle States
![Lifecycle States](https://github.com/spanicker/web-lifecycle/blob/master/LifecycleStates.png)

For details on the app lifecycle states and definitions see [this doc](https://docs.google.com/document/d/1UuS6ff4Fd4igZgL50LDS8MeROVrOfkN13RbiP2nTT9I/edit#heading=h.edtdhepwctwy).
This proposal aims to formalize states for STOPPED and DISCARDED, and expose necessary web APIs to support two important system interventions necessary for resource re-allocation:
* Tab discarding for memory saving - this puts the app in DISCARDED state.
* CPU stopping for battery saving - this puts the app in STOPPED state.


Lifecycle State | Visibility | Developer Expectation | System Interventions
--------------- | ---------- | --------------------- | --------------------
STOPPED | Not Visible | Hand off for background work and stop execution. | CPU suspension for battery saving: stop CPU after N minutes based on resource constraints
DISCARDED | Not Visible | System has discarded background tab to reclaim memory. If user revisits tab, this will reload the tab. | Tab discarding for memory saving: fully unloaded, no memory consumption.

