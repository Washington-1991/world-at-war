module Diplomacy
  class ResolveTradeContext
    Result = Struct.new(
      :importer_user,
      :exporter_user,
      :same_user,
      :allowed,
      :blocked_reason,
      :importer_relation,
      :exporter_relation,
      :importer_relation_state,
      :exporter_relation_state,
      :importer_trade_policy,
      :exporter_trade_policy,
      :importer_effective_trade_policy,
      :exporter_effective_trade_policy,
      :importer_tariff_rate_basis_points,
      :applied_tariff_rate_basis_points,
      keyword_init: true
    ) do
      def allowed?
        allowed
      end

      def blocked?
        !allowed
      end

      def same_user?
        same_user
      end

      def blocked_by_importer?
        blocked_reason == :importer_embargo || blocked_reason == :mutual_embargo
      end

      def blocked_by_exporter?
        blocked_reason == :exporter_embargo || blocked_reason == :mutual_embargo
      end
    end

    def self.call(importer_user:, exporter_user:)
      new(
        importer_user: importer_user,
        exporter_user: exporter_user
      ).call
    end

    def initialize(importer_user:, exporter_user:)
      @importer_user = importer_user
      @exporter_user = exporter_user
    end

    def call
      validate_user!(importer_user, "importer_user")
      validate_user!(exporter_user, "exporter_user")

      return same_user_result if same_user?

      importer_relation = relation_for(
        source_user: importer_user,
        target_user: exporter_user
      )

      exporter_relation = relation_for(
        source_user: exporter_user,
        target_user: importer_user
      )

      importer_embargoed = importer_relation.effectively_embargoed?
      exporter_embargoed = exporter_relation.effectively_embargoed?

      allowed = !importer_embargoed && !exporter_embargoed

      Result.new(
        importer_user: importer_user,
        exporter_user: exporter_user,
        same_user: false,
        allowed: allowed,
        blocked_reason: blocked_reason_for(
          importer_embargoed: importer_embargoed,
          exporter_embargoed: exporter_embargoed
        ),
        importer_relation: importer_relation,
        exporter_relation: exporter_relation,
        importer_relation_state: importer_relation.relation_state,
        exporter_relation_state: exporter_relation.relation_state,
        importer_trade_policy: importer_relation.trade_policy,
        exporter_trade_policy: exporter_relation.trade_policy,
        importer_effective_trade_policy: importer_relation.effective_trade_policy,
        exporter_effective_trade_policy: exporter_relation.effective_trade_policy,
        importer_tariff_rate_basis_points: importer_relation.tariff_rate_basis_points,
        applied_tariff_rate_basis_points: allowed ? importer_relation.tariff_rate_basis_points : nil
      )
    end

    private

    attr_reader :importer_user, :exporter_user

    def validate_user!(user, argument_name)
      return if user.present? && user.id.present? && user.persisted?

      raise ArgumentError, "#{argument_name} must be a persisted User"
    end

    def same_user?
      importer_user.id == exporter_user.id
    end

    def same_user_result
      Result.new(
        importer_user: importer_user,
        exporter_user: exporter_user,
        same_user: true,
        allowed: true,
        blocked_reason: nil,
        importer_relation: nil,
        exporter_relation: nil,
        importer_relation_state: nil,
        exporter_relation_state: nil,
        importer_trade_policy: nil,
        exporter_trade_policy: nil,
        importer_effective_trade_policy: nil,
        exporter_effective_trade_policy: nil,
        importer_tariff_rate_basis_points: 0,
        applied_tariff_rate_basis_points: 0
      )
    end

    def relation_for(source_user:, target_user:)
      DiplomaticRelation.find_by(
        source_user: source_user,
        target_user: target_user
      ) || DiplomaticRelation.new(
        source_user: source_user,
        target_user: target_user
      )
    end

    def blocked_reason_for(importer_embargoed:, exporter_embargoed:)
      if importer_embargoed && exporter_embargoed
        :mutual_embargo
      elsif importer_embargoed
        :importer_embargo
      elsif exporter_embargoed
        :exporter_embargo
      end
    end
  end
end
