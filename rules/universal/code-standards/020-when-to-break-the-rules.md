# When a code standard would make the code worse, make an exception and mark it for review

The code standards are defaults, each with a reason. Where following one would make the code worse, make an exception
there: write what is better, and put a `//review:` comment at the code
([tagged todo comments](062-tagged-todo-comments.md)) that says which standard, and why the exception is better here.
Such as when the standard's reason doesn't hold in the case at hand, or when what it prescribes can't do what the code
needs.

An exception is not for a standard you would simply have written differently: most of them say what the user wants
where that isn't what most code does.

When the user has approved an exception:

- **Its comment becomes a `//rationale:` comment,** which stays: it tells the next reader that the code is this way on
  purpose, and why.
- **What the comment can't hold,** such as an exception wider than one place in the code, or reasoning too long for a
  comment, goes in a document under `dev_docs/code_standard_exceptions`, which the comment points to.
