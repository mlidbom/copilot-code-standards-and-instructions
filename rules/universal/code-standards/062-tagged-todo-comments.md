# Tagged todo comments: what's left to do about some code goes in a comment at that code

When you find something about a piece of code that should change, and you don't change it now, put a **tagged comment at
that code**: a bug you found, a duplication, a design that should change, a change that is decided but not yet made. A
mention in your summary alone gets lost; a comment at the code is seen by whoever reads or changes that code next, moves
with it when it's refactored, and is listed by the IDE.

## The tags

A tag is a word and a colon, at the start of the comment. The IDE's TODO patterns match them case-insensitively and list
them in its TODO window (Rider: Settings > Editor > TODO; a solution's own patterns are in its `.DotSettings`).

- `bug:` behavior that is wrong, found and not fixed.
- `refactor:` design that should change: code that implements the same thing as other code, a name that tells less than
  the truth, a responsibility in the wrong place.
- `todo:` a change that is decided and not yet made. Say who decided it and when, such as "(Magnus, 2026-11-09)".
- `todo:compze:` a workaround for something Compze should change: the Compze change it waits for, and what to do here
  once it lands. See the rule "Compze is our code".
- `urgent:` a todo of top priority.
- `performance:` code that is slow enough to matter, with what was measured or observed.
- `wip:` an aspect of the code that is the way it is because of work in progress, and will or should change when the work
  is done.
- `review:` something strange or potentially problematic about the code, for the other one to look at or to discuss. The
  user adds them for you to look at, and you add them for the user. When you find one addressed to you, look into it and
  answer the user about it.
- `review-naming:` a review comment that is only about the name of something: a name you chose or changed on your own, or
  a name you doubt, for the user's pass over the names. An area may follow it, to make such comments searchable, such as
  `review-naming:matching:`. The `review:` pattern doesn't match it, so a solution needs a TODO pattern of its own for it.

The user's other tags, such as `review:rebuttal:` and `todo:docs:`, are the user's to use.

## Writing one

- Put it on the line before the code it concerns, inside the member, as for any inline comment; never on a member or a type.
- Write it for someone who doesn't know the context: what is wrong or to be done, and why, in the project's ubiquitous
  language. Name the other code involved, such as the duplicate.
- One item per comment. Indented lines that follow it are part of the same item, for the IDE too.

```csharp
//refactor: TagPickerViewModel.CanBeANewTag checks the same two rules. One method in Core, such as
//   Tags.WhyItCannotBeATagAPersonManages, should say why for both.
```

## Working with them

- **Before changing a file, look at its tagged comments.** Resolving one along with the work is welcome; delete the comment
  once it's resolved.
- **In the summary at the end of a task, list the tagged comments you added and those you resolved.**
- **To list them all, grep with the IDE's patterns,** such as
  `grep -rniE "(^|\W)(bug|todo|refactor|performance|urgent|review|review-naming|wip):" --include=*.cs <source folder>`. It finds what the IDE
  finds, and also the tags inside string literals, which the IDE skips.
- **What spans many files, or isn't tied to any code, belongs in the project's documents,** not in a comment.

See also the collaboration rule "The codebase must improve over time, never degrade", whose "anything you noticed was wrong
but didn't fix" this puts at the code, and [inline comments](061-inline-comments.md).
