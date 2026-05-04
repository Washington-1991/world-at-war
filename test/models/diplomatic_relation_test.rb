require "test_helper"

class DiplomaticRelationTest < ActiveSupport::TestCase
  setup do
    unique_token = SecureRandom.hex(4)

    @source_user = User.create!(
      email: "source-#{unique_token}@example.com",
      name: "Source",
      birth_date: Date.new(1991, 1, 1),
      birth_country: "Uruguay",
      role: :player
    )

    @target_user = User.create!(
      email: "target-#{unique_token}@example.com",
      name: "Target",
      birth_date: Date.new(1992, 1, 1),
      birth_country: "Poland",
      role: :player
    )
  end

  test "is valid with default values" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user
    )

    assert relation.valid?
    assert_equal "neutral", relation.relation_state
    assert_equal "open", relation.trade_policy
    assert_equal "open", relation.effective_trade_policy
    assert_equal 1_000, relation.tariff_rate_basis_points
  end

  test "does not allow self relation" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @source_user
    )

    assert_not relation.valid?
    assert_includes relation.errors[:target_user_id], "must be different from source_user_id"
  end

  test "does not allow duplicated directed relation" do
    DiplomaticRelation.create!(
      source_user: @source_user,
      target_user: @target_user
    )

    duplicate = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user
    )

    assert_not duplicate.valid?
  end

  test "allows inverse relation" do
    DiplomaticRelation.create!(
      source_user: @source_user,
      target_user: @target_user
    )

    inverse = DiplomaticRelation.new(
      source_user: @target_user,
      target_user: @source_user
    )

    assert inverse.valid?
  end

  test "enemy forces effective embargo" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :enemy,
      trade_policy: :open
    )

    assert relation.valid?
    assert_equal "embargoed", relation.effective_trade_policy
    assert relation.effectively_embargoed?
    assert_nil relation.tariff_rate_basis_points
  end

  test "war forces effective embargo" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :war,
      trade_policy: :open
    )

    assert relation.valid?
    assert_equal "embargoed", relation.effective_trade_policy
    assert relation.effectively_embargoed?
    assert_nil relation.tariff_rate_basis_points
  end

  test "manual embargo is allowed for hostile relation" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :hostile,
      trade_policy: :embargoed
    )

    assert relation.valid?
    assert_equal "embargoed", relation.effective_trade_policy
  end

  test "manual embargo is not allowed for neutral relation" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :neutral,
      trade_policy: :embargoed
    )

    assert_not relation.valid?
    assert_includes relation.errors[:trade_policy], "can only be embargoed when relation_state is hostile, enemy, or war"
  end

  test "manual embargo is not allowed for friendly relation" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :friendly,
      trade_policy: :embargoed
    )

    assert_not relation.valid?
    assert_includes relation.errors[:trade_policy], "can only be embargoed when relation_state is hostile, enemy, or war"
  end

  test "ally cannot be embargoed" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :ally,
      trade_policy: :embargoed
    )

    assert_not relation.valid?
    assert_includes relation.errors[:trade_policy], "cannot be embargoed when relation_state is ally"
  end

  test "tariff rate depends on relation state" do
    relation = DiplomaticRelation.new(
      source_user: @source_user,
      target_user: @target_user
    )

    relation.relation_state = :ally
    assert_equal 0, relation.tariff_rate_basis_points

    relation.relation_state = :friendly
    assert_equal 500, relation.tariff_rate_basis_points

    relation.relation_state = :neutral
    assert_equal 1_000, relation.tariff_rate_basis_points

    relation.relation_state = :hostile
    assert_equal 2_500, relation.tariff_rate_basis_points

    relation.relation_state = :enemy
    assert_nil relation.tariff_rate_basis_points

    relation.relation_state = :war
    assert_nil relation.tariff_rate_basis_points
  end
end
