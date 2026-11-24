# When a code standard would make the code worse, make an exception and mark it for review

The code standards are defaults, each with a reason. Where following one would make the code worse, make an exception
there: write what is better, and put a `//review:` comment at the code
([tagged todo comments](062-tagged-todo-comments.md)) that says which standard, and why the exception is better here.
Such as when the standard's reason doesn't hold in the case at hand, or when what it prescribes can't do what the code
needs.

An exception is not for a standard you would simply have written differently: most of them say what the user wants
where that isn't what most code does.

When the user has approved an exception, its comment becomes a `rationale:violation-approved:` comment, which stays:

```csharp
//rationale:violation-approved:Magnus-2026-11-15: a raw lock, because the plugin can't reference Compze.Threading.
```

- **It overrides the rules for the code it's on:** whoever reads or changes that code next, human or agent, leaves the
  exception alone, and no review or inspection pass reopens it.
- **Only the user's approval writes one,** naming him and the date. An agent never writes it on its own, nor turns its
  own `//review:` into one.
- **At the code it concerns:** on the line before it, inside the member. When the whole member or type is the
  exception, first in that member's or type's body: never in its doc comment, which is published (see
  [tagged todo comments](062-tagged-todo-comments.md)).
- **What the comment can't hold,** such as an exception wider than one place in the code, or reasoning too long for a
  comment, goes in a document under `dev_docs/code_standard_exceptions`, which the comment points to.
