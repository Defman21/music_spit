defmodule MusicSpitTest do
  use ExUnit.Case
  doctest MusicSpit

  test "greets the world" do
    assert MusicSpit.hello() == :world
  end
end
