defmodule PhoenixKit.Modules.Legal.ReservedRoutePrefixesTest do
  @moduledoc """
  Pins that Legal declares "legal" as a reserved top-level route prefix, so
  Publishing's group-catch-all dispatch (which would otherwise treat the
  "legal" Publishing group Legal creates as fair game) knows to leave the
  host app's own "/legal" route alone.
  """
  use ExUnit.Case, async: true

  test "reserves the \"legal\" prefix" do
    assert PhoenixKit.Modules.Legal.reserved_route_prefixes() == ["legal"]
  end
end
