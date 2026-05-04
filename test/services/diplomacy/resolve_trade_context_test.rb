require "test_helper"

module Diplomacy
  class ResolveTradeContextTest < ActiveSupport::TestCase
    setup do
      unique_token = SecureRandom.hex(4)

      @importer = create_user(
        email: "importer-#{unique_token}@example.com",
        name: "Importer"
      )

      @exporter = create_user(
        email: "exporter-#{unique_token}@example.com",
        name: "Exporter"
      )
    end

    test "allows trade by default when no diplomatic relations exist" do
      result = resolve_trade

      assert result.allowed?
      assert_not result.blocked?
      assert_not result.same_user?

      assert_equal "neutral", result.importer_relation_state
      assert_equal "neutral", result.exporter_relation_state

      assert_equal "open", result.importer_trade_policy
      assert_equal "open", result.exporter_trade_policy

      assert_equal "open", result.importer_effective_trade_policy
      assert_equal "open", result.exporter_effective_trade_policy

      assert_equal 1_000, result.importer_tariff_rate_basis_points
      assert_equal 1_000, result.applied_tariff_rate_basis_points
      assert_nil result.blocked_reason
    end

    test "same user trade bypasses diplomacy and tariffs" do
      result = Diplomacy::ResolveTradeContext.call(
        importer_user: @importer,
        exporter_user: @importer
      )

      assert result.allowed?
      assert result.same_user?
      assert_equal 0, result.importer_tariff_rate_basis_points
      assert_equal 0, result.applied_tariff_rate_basis_points
      assert_nil result.blocked_reason
    end

    test "friendly importer relation applies friendly tariff" do
      DiplomaticRelation.create!(
        source_user: @importer,
        target_user: @exporter,
        relation_state: :friendly
      )

      result = resolve_trade

      assert result.allowed?
      assert_equal "friendly", result.importer_relation_state
      assert_equal 500, result.importer_tariff_rate_basis_points
      assert_equal 500, result.applied_tariff_rate_basis_points
    end

    test "ally importer relation applies zero tariff" do
      DiplomaticRelation.create!(
        source_user: @importer,
        target_user: @exporter,
        relation_state: :ally
      )

      result = resolve_trade

      assert result.allowed?
      assert_equal "ally", result.importer_relation_state
      assert_equal 0, result.importer_tariff_rate_basis_points
      assert_equal 0, result.applied_tariff_rate_basis_points
    end

    test "hostile importer relation applies hostile tariff when trade is open" do
      DiplomaticRelation.create!(
        source_user: @importer,
        target_user: @exporter,
        relation_state: :hostile,
        trade_policy: :open
      )

      result = resolve_trade

      assert result.allowed?
      assert_equal "hostile", result.importer_relation_state
      assert_equal 2_500, result.importer_tariff_rate_basis_points
      assert_equal 2_500, result.applied_tariff_rate_basis_points
    end

    test "exporter relation does not define importer tariff" do
      DiplomaticRelation.create!(
        source_user: @exporter,
        target_user: @importer,
        relation_state: :friendly
      )

      result = resolve_trade

      assert result.allowed?
      assert_equal "neutral", result.importer_relation_state
      assert_equal "friendly", result.exporter_relation_state
      assert_equal 1_000, result.applied_tariff_rate_basis_points
    end

    test "manual importer embargo blocks trade" do
      DiplomaticRelation.create!(
        source_user: @importer,
        target_user: @exporter,
        relation_state: :hostile,
        trade_policy: :embargoed
      )

      result = resolve_trade

      assert result.blocked?
      assert result.blocked_by_importer?
      assert_not result.blocked_by_exporter?
      assert_equal :importer_embargo, result.blocked_reason
      assert_nil result.applied_tariff_rate_basis_points
    end

    test "manual exporter embargo blocks trade" do
      DiplomaticRelation.create!(
        source_user: @exporter,
        target_user: @importer,
        relation_state: :hostile,
        trade_policy: :embargoed
      )

      result = resolve_trade

      assert result.blocked?
      assert result.blocked_by_exporter?
      assert_not result.blocked_by_importer?
      assert_equal :exporter_embargo, result.blocked_reason
      assert_nil result.applied_tariff_rate_basis_points
    end

    test "enemy importer relation automatically blocks trade" do
      DiplomaticRelation.create!(
        source_user: @importer,
        target_user: @exporter,
        relation_state: :enemy,
        trade_policy: :open
      )

      result = resolve_trade

      assert result.blocked?
      assert result.blocked_by_importer?
      assert_equal :importer_embargo, result.blocked_reason
      assert_equal "embargoed", result.importer_effective_trade_policy
      assert_nil result.importer_tariff_rate_basis_points
      assert_nil result.applied_tariff_rate_basis_points
    end

    test "war exporter relation automatically blocks trade" do
      DiplomaticRelation.create!(
        source_user: @exporter,
        target_user: @importer,
        relation_state: :war,
        trade_policy: :open
      )

      result = resolve_trade

      assert result.blocked?
      assert result.blocked_by_exporter?
      assert_equal :exporter_embargo, result.blocked_reason
      assert_equal "embargoed", result.exporter_effective_trade_policy
      assert_nil result.applied_tariff_rate_basis_points
    end

    test "mutual embargo blocks trade from both sides" do
      DiplomaticRelation.create!(
        source_user: @importer,
        target_user: @exporter,
        relation_state: :hostile,
        trade_policy: :embargoed
      )

      DiplomaticRelation.create!(
        source_user: @exporter,
        target_user: @importer,
        relation_state: :enemy,
        trade_policy: :open
      )

      result = resolve_trade

      assert result.blocked?
      assert result.blocked_by_importer?
      assert result.blocked_by_exporter?
      assert_equal :mutual_embargo, result.blocked_reason
      assert_nil result.applied_tariff_rate_basis_points
    end

    test "raises when importer is not persisted" do
      unsaved_user = User.new(
        email: "unsaved@example.com",
        name: "Unsaved",
        birth_date: Date.new(1991, 1, 1),
        birth_country: "Uruguay",
        role: :player
      )

      assert_raises(ArgumentError) do
        Diplomacy::ResolveTradeContext.call(
          importer_user: unsaved_user,
          exporter_user: @exporter
        )
      end
    end

    test "raises when exporter is nil" do
      assert_raises(ArgumentError) do
        Diplomacy::ResolveTradeContext.call(
          importer_user: @importer,
          exporter_user: nil
        )
      end
    end

    private

    def resolve_trade
      Diplomacy::ResolveTradeContext.call(
        importer_user: @importer,
        exporter_user: @exporter
      )
    end

    def create_user(email:, name:)
      User.create!(
        email: email,
        name: name,
        birth_date: Date.new(1991, 1, 1),
        birth_country: "Uruguay",
        role: :player
      )
    end
  end
end
