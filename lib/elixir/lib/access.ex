import Kernel, except: [access: 2]

defprotocol Access do
  @moduledoc """
  Retrieves an element from a data structure.

  The Access protocol is the underlying protocol invoked
  when the brackets syntax is used. For instance, `foo[bar]`
  is translated to `access foo, bar` which, by default,
  invokes the `Access.access` protocol.

  This protocol is limited and is implemented only for the
  following built-in types: keywords, records and functions.
  """

  @only [List, Record, Atom]

  @doc """
  Retrieves an element from a `container` identified by a `key`.
  """
  def access(container, key)
end

defimpl Access, for: List do
  @doc """
  Access the given `key` in a tuple `list`.

  ## Examples

      iex> keywords = [a: 1, b: 2]
      ...> keywords[:a]
      1

      iex> star_ratings = [{1.0, "★"}, {1.5, "★☆"}, {2.0, "★★"}]
      ...> star_ratings[1.5]
      "★☆"

  """
  def access([], _key), do: nil

  def access(list, key) do
    case :lists.keyfind(key, 1, list) do
      { ^key, value } -> value
      false -> nil
    end
  end
end

defimpl Access, for: Atom do
  @doc """
  Raises an exception, since atoms can't be Accessed at runtime.

  The Access protocol is only available to atoms at compilation time,
  so we raise an informative exception if this occurs at any other point.
  """
  def access(nil, _) do
    nil
  end

  def access(atom, _) do
    raise "The access protocol can only be invoked for atoms at " <>
      "compilation time, tried to invoke it for #{inspect atom}"
  end
end
