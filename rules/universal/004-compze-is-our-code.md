# Compze is our code: recommend changing it, prominently, whenever our own code would have earned the change

Compze is Magnus's own set of libraries and tools. In a repository that uses it, treat it as our code, not as a
third-party dependency: hold it to the same standards as the repository you work in. Anything that would trigger a
refactoring, a fix or an addition in that repository's own code triggers a recommendation for Compze:

- **A missing API you had to work around.** Compze.Contracts having `True()` and no `False()`, so the code asserts a
  negation another way.
- **An API that forces awkward code on its consumers,** or a name that tells less than the truth.
- **A bug or surprising behavior.** Disposing an endpoint also disposes the container, on a thread-pool thread, so a
  host cannot stop serving and then tear its graph down on the thread that built it.
- **Code written here that belongs in one of Compze's libraries:** it fits the domain of a library Compze already has,
  such as a locking primitive for Compze.Threading or an assertion for Compze.Contracts, and it's something we'd publish
  to the world. Having nothing about this repository in it isn't enough: Compze isn't the home for everything
  general-purpose.

## How to recommend it

- **Prominently: under a heading of its own,** `### COMPZE RECOMMENDATION ###`, near the top of the report, never as a
  closing "your call". Say what to change in Compze, why, and what you did here in the meantime.
- **Mark the workaround at the code** with a `todo:compze:` comment (see the rule on tagged todo comments): the Compze
  change it waits for, and what to do here once it lands, usually to delete the workaround. One grep then finds every
  workaround to remove when Compze changes.
- **Don't change Compze from another repository's session unless asked.** Another session may be working in Compze;
  the recommendation goes to Magnus, who decides where and when it's made.

In Compze's own repository, Compze is simply the code you work in, and this rule asks nothing extra.
