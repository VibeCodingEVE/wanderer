defmodule WandererApp.Utils.EVEUtilTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Map.Operations.Connections
  alias WandererApp.Utils.EVEUtil

  describe "get_wh_size/1" do
    test "returns nil when the type is unknown or a K162" do
      assert EVEUtil.get_wh_size(nil) == nil
      assert EVEUtil.get_wh_size("K162") == nil
      assert EVEUtil.get_wh_size("NOPE") == nil
    end

    test "maps each mass class to its ship size" do
      # 5M, 62M, 375M, 1B and 2B per jump
      assert EVEUtil.get_wh_size("A009") == Connections.small_ship_size()
      assert EVEUtil.get_wh_size("L614") == Connections.medium_ship_size()
      assert EVEUtil.get_wh_size("B520") == Connections.large_ship_size()
      assert EVEUtil.get_wh_size("D792") == Connections.freight_ship_size()
      assert EVEUtil.get_wh_size("N432") == Connections.capital_ship_size()
    end

    test "capital holes between C5/C6 and low/null are capital sized" do
      for type <- ["C140", "C248", "C391", "Z142"] do
        assert EVEUtil.get_wh_size(type) == Connections.capital_ship_size(),
               "#{type} should allow capitals"
      end
    end

    test "every wormhole type gets the largest ship size that fits its jump mass" do
      {:ok, types} = WandererApp.CachedInfo.get_wormhole_types()

      for %{name: name, max_mass_per_jump: mass} <- types, not is_nil(mass), name != "K162" do
        expected =
          cond do
            mass >= 2_000_000_000 -> Connections.capital_ship_size()
            mass >= 1_000_000_000 -> Connections.freight_ship_size()
            mass >= 375_000_000 -> Connections.large_ship_size()
            mass >= 62_000_000 -> Connections.medium_ship_size()
            true -> Connections.small_ship_size()
          end

        assert EVEUtil.get_wh_size(name) == expected, "#{name} (#{mass})"
      end
    end
  end
end
