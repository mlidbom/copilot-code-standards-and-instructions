# When using APIs that fight our code style, hide them behind an anti-corruption layer.

## Naked primitives standing in for a domain concept

`IntPtr`/`nint` (a bare `void*`) is the worst case; a `Guid` id, a bare `int`, a magic `string` are the same problem. Such a primitive is acceptable **only in the exact signature an external API / ABI / serialization format dictates** — the `[DllImport]` extern, the callback delegate a native API hands us, the wire-format DTO. **One line in from that edge it is already wrapped** in a type with domain meaning; every signature the boundary exposes speaks that type, never the primitive.

A wrapper with domain meaning is created and all of our code uses that.

### What type to create
depends on what actually hides behind the primitive. 
* something with meaningful state and functionality:  interface or class
* one out of a list of possible values might be an enum etc

Default to class if unsure. Data tends to grow functionality and class is the swiss knife.

### Behavior goes with data.

If a method logically belongs on the abstraction our wrapper represents, that should probably be methods on our wrapper, 
not implemented by some other class that we pass our wrapper to.
