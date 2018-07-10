Code.require_file("../test_helper.exs", __DIR__)

defmodule Kernel.DocsTest do
  use ExUnit.Case

  import PathHelpers

  test "attributes format" do
    defmodule DocAttributes do
      @moduledoc "Module doc"
      assert @moduledoc == "Module doc"
      assert Module.get_attribute(__MODULE__, :moduledoc) == {__ENV__.line - 2, "Module doc"}

      @typedoc "Type doc"
      assert @typedoc == "Type doc"
      assert Module.get_attribute(__MODULE__, :typedoc) == {__ENV__.line - 2, "Type doc"}
      @type foobar :: any

      @doc "Function doc"
      assert @doc == "Function doc"
      assert Module.get_attribute(__MODULE__, :doc) == {__ENV__.line - 2, "Function doc"}

      def foobar() do
        :ok
      end
    end
  end

  test "compiled without docs" do
    Code.compiler_options(docs: false)

    write_beam(
      defmodule WithoutDocs do
        @moduledoc "Module doc"

        @doc "Some doc"
        def foobar(arg), do: arg
      end
    )

    assert Code.fetch_docs(WithoutDocs) == {:error, :chunk_not_found}
  after
    Code.compiler_options(docs: true)
  end

  test "compiled in memory does not have accessible docs" do
    defmodule InMemoryDocs do
      @moduledoc "Module doc"

      @doc "Some doc"
      def foobar(arg), do: arg
    end

    assert Code.fetch_docs(InMemoryDocs) == {:error, :module_not_found}
  end

  test "raises on invalid @since" do
    assert_raise ArgumentError, ~r"should be a string representing the version", fn ->
      defmodule InvalidSince do
        @since 1.2
        def foo, do: :bar
      end
    end
  end

  test "raises on invalid @doc" do
    assert_raise ArgumentError, ~r/When set dynamically, it should be {line, doc}/, fn ->
      defmodule DocAttributesFormat do
        Module.put_attribute(__MODULE__, :moduledoc, "Other")
      end
    end

    assert_raise ArgumentError, ~r/should be a binary, a boolean, or nil/, fn ->
      defmodule AtSyntaxDocAttributesFormat do
        @moduledoc :not_a_binary
      end
    end
  end

  describe "compiled with docs" do
    test "infers signatures" do
      write_beam(
        defmodule SignatureDocs do
          def arg_names([], [], %{}, [], %{}), do: false

          @year 2015
          def with_defaults(@year, arg \\ 0, year \\ @year, fun \\ &>=/2) do
            {fun, arg + year}
          end

          def with_map_and_default(%{key: value} \\ %{key: :default}), do: value
          def with_struct(%URI{}), do: :ok

          def with_underscore({_, _} = _two_tuple), do: :ok
          def with_underscore(_), do: :error

          def only_underscore(_), do: :ok

          def two_good_names(first, :ok), do: first
          def two_good_names(second, :error), do: second
        end
      )

      assert {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(SignatureDocs)
      signatures = for {{:function, n, a}, _, signature, _, %{}} <- docs, do: {{n, a}, signature}

      assert [
               arg_names,
               only_underscore,
               two_good_names,
               with_defaults,
               with_map_and_default,
               with_struct,
               with_underscore
             ] = Enum.sort(signatures)

      # arg_names/5
      assert {{:arg_names, 5}, ["arg_names(list1, list2, map1, list3, map2)"]} = arg_names

      # only_underscore/1
      assert {{:only_underscore, 1}, ["only_underscore(_)"]} = only_underscore

      # two_good_names/2
      assert {{:two_good_names, 2}, ["two_good_names(first, atom)"]} = two_good_names

      # with_defaults/4
      assert {{:with_defaults, 4},
              ["with_defaults(int, arg \\\\ 0, year \\\\ 2015, fun \\\\ &>=/2)"]} = with_defaults

      # with_map_and_default/1
      assert {{:with_map_and_default, 1}, ["with_map_and_default(map \\\\ %{key: :default})"]} =
               with_map_and_default

      # with_struct/1
      assert {{:with_struct, 1}, ["with_struct(uri)"]} = with_struct

      # with_underscore/1
      assert {{:with_underscore, 1}, ["with_underscore(two_tuple)"]} = with_underscore
    end

    test "includes docs for functions, modules, types and callbacks" do
      write_beam(
        defmodule SampleDocs do
          @moduledoc "Module doc"

          @typedoc "Type doc"
          @since "1.2.3"
          @type foo(any) :: any

          @typedoc "Opaque type doc"
          @opaque bar(any) :: any

          @doc "Callback doc"
          @since "1.2.3"
          @deprecated "use baz/2 instead"
          @callback foo(any) :: any

          @doc false
          @callback bar() :: term
          @callback baz(any, term) :: any

          @doc "Macrocallback doc"
          @macrocallback qux(any) :: any

          @doc "Function doc"
          @since "1.2.3"
          @deprecated "use baz/2 instead"
          def foo(arg \\ 0), do: arg + 1

          @doc "Multiple bodiless clause doc"
          @since "1.2.3"
          def bar(_arg)
          def bar(_arg)
          def bar(arg), do: arg + 1

          @doc "Wrong doc"
          @since "1.2"
          def baz(_arg)
          def baz(arg), do: arg + 1
          @doc "Multiple bodiless clause and docs"
          @since "1.2.3"
          def baz(_arg)

          @doc false
          def qux(true), do: false

          # We do this to avoid the deprecation warning.
          module = Module
          module.add_doc(__MODULE__, __ENV__.line, :def, {:nullary, 0}, [], "add_doc")
          def nullary, do: 0
        end
      )

      assert {:docs_v1, _, :elixir, "text/markdown", %{"en" => module_doc}, %{}, docs} =
               Code.fetch_docs(SampleDocs)

      assert module_doc == "Module doc"

      [
        callback_bar,
        callback_baz,
        callback_foo,
        function_bar,
        function_baz,
        function_foo,
        function_nullary,
        function_qux,
        macrocallback_qux,
        type_bar,
        type_foo
      ] = Enum.sort(docs)

      assert {{:callback, :bar, 0}, _, [], :hidden, %{}} = callback_bar
      assert {{:callback, :baz, 2}, _, [], :none, %{}} = callback_baz

      assert {{:callback, :foo, 1}, _, [], %{"en" => "Callback doc"},
              %{since: "1.2.3", deprecated: "use baz/2 instead"}} = callback_foo

      assert {{:function, :bar, 1}, _, ["bar(arg)"], %{"en" => "Multiple bodiless clause doc"},
              %{since: "1.2.3"}} = function_bar

      assert {{:function, :baz, 1}, _, ["baz(arg)"],
              %{"en" => "Multiple bodiless clause and docs"}, %{since: "1.2.3"}} = function_baz

      assert {{:function, :foo, 1}, _, ["foo(arg \\\\ 0)"], %{"en" => "Function doc"},
              %{since: "1.2.3", deprecated: "use baz/2 instead", defaults: 1}} = function_foo

      assert {{:function, :nullary, 0}, _, ["nullary()"], %{"en" => "add_doc"}, %{}} =
               function_nullary

      assert {{:function, :qux, 1}, _, ["qux(bool)"], :hidden, %{}} = function_qux

      assert {{:macrocallback, :qux, 1}, _, [], %{"en" => "Macrocallback doc"}, %{}} =
               macrocallback_qux

      assert {{:type, :bar, 1}, _, [], %{"en" => "Opaque type doc"}, %{opaque: true}} = type_bar
      assert {{:type, :foo, 1}, _, [], %{"en" => "Type doc"}, %{since: "1.2.3"}} = type_foo
    end
  end

  test "@impl true doesn't set @doc false if previous implementation has docs" do
    write_beam(
      defmodule Docs do
        defmodule SampleBehaviour do
          @callback foo(any()) :: any()
          @callback bar() :: any()
          @callback baz() :: any()
        end

        @behaviour SampleBehaviour

        @doc "Foo docs"
        def foo(nil), do: nil

        @impl true
        def foo(_), do: false

        @impl true
        def bar(), do: true

        @doc "Baz docs"
        @impl true
        def baz(), do: true

        def fuz(), do: true
      end
    )

    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Docs)
    function_docs = for {{:function, name, arity}, _, _, doc, _} <- docs, do: {{name, arity}, doc}

    assert [
             {{:bar, 0}, :hidden},
             {{:baz, 0}, %{"en" => "Baz docs"}},
             {{:foo, 1}, %{"en" => "Foo docs"}},
             {{:fuz, 0}, :none}
           ] = Enum.sort(function_docs)
  end
end
