# When a view gets a ViewModel — and when honest code-behind is right

A ViewModel earns its place where the view **owns editable state**: a working copy / edit session, computed
enabled/visible rules, validation, a commit. There it is the missing abstraction, not ceremony — each
"editable only while X" invariant becomes one computed property the controls bind to, stated once instead of
re-established in every change handler (`_loading`-style reentrancy guards are the tell that this is being
done by hand).

When several views show or edit the same changing state, the view model belongs to the object they show.
Bind each view to that state. Each editor still owns its caret, selection and scroll position.

Do NOT manufacture a ViewModel for:

- **Window-mechanics views** (flyouts, splash, positioning/bring-to-front/dismiss-on-deactivate chrome with
  a couple of actions) — the VM would be an anemic command bag; honest code-behind is the truthful model.
- **Views editing live external state they don't own** (OS settings applied immediately, device state) — a
  stateful VM there is a mirror of external state with sync/staleness hazards. Read live, refresh in place;
  per-item VMs for templated children are still fine.

Either way, native interop and window plumbing stay in code-behind even when a ViewModel exists.
