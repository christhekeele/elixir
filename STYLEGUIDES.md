# Elixir Styleguides

The best way to learn Elixir's style is to read the source! (It's a rewarding
exercise, for many reasons.) We try here to present some of the most
widespread conventions.

## Code

## Documentation

Code documentation (`@doc`, `@moduledoc`, `@typedoc`) has a special convention:
the first paragraph is considered to be a short summary, 80 characters or less.

For functions, macros and callbacks say what it will do. For example write
something like:

```elixir
@doc """
Return only those elements for which `fun` is true.

...
"""
def filter(collection, fun) ...
```

For modules, records, protocols and types say what it is. For example write
something like:

```elixir
defrecord File.Stat, [...] do
  @moduledoc """
  Information about a file.

  ...
  """
end
```

Try to keep unnecessary details out of the summary. It's only there to
give a user a quick idea of what the documented "thing" does/is. The rest of the
documentation string can contain the details, for example when a value and when
`nil` is returned.

Remember the context that summaries will be presented in. Omit extra words
that will be apparent in that context:

- Phrases like "A module that..." or "A function for...". The subject of the
  summary can be implicit.
- Qualifiers like "...the given string...". The indefinite "...a string..."
  is plenty.

If possible include examples, preferably in a form that works with doctests.
For example:

```elixir
@doc """
Return only those elements for which `fun` is true.

## Examples

    iex> Enum.filter([1, 2, 3], fn(x) -> rem(x, 2) == 0 end)
    [2]

"""
def filter(collection, fun) ...
```

This makes it easy to test the examples so that they don't go stale and examples
are often a great help in explaining what a function does.

For wrapper modules or abstractions around libraries, try to introduce links
to the original concept. For example, a link to
[OTP behaviours](erlang.org/doc/design_principles/des_princ.html#id58199)
in the moduledoc for Behaviours, or a link to
[Erlang's Code library](http://www.erlang.org/doc/man/code.html)
in the moduledoc for Elixir's Code.

## Tests
