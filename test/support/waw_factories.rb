# test/support/waw_factories.rb
require "securerandom"
require "date"

module WawFactories
  def create_user!(email: "user-#{SecureRandom.hex(4)}@example.com", password: "secret123")
    attrs = {}

    attrs[:email] = email if User.column_names.include?("email")

    if User.column_names.include?("role")
      if User.respond_to?(:roles) && User.roles.is_a?(Hash)
        attrs[:role] = User.roles.key?("player") ? "player" : User.roles.keys.first
      else
        attrs[:role] = "player"
      end
    end

    attrs[:admin] = false if User.column_names.include?("admin")

    if User.column_names.include?("password_digest")
      begin
        require "bcrypt"
        attrs[:password_digest] = BCrypt::Password.create(password)
      rescue LoadError
        attrs[:password_digest] = SecureRandom.hex(16)
      end
    end

    attrs[:name] = "Test User" if User.column_names.include?("name")
    attrs[:username] = "testuser_#{SecureRandom.hex(4)}" if User.column_names.include?("username")

    if User.column_names.include?("birth_date")
      attrs[:birth_date] ||= Date.new(1990, 1, 1)
    end

    if User.column_names.include?("birth_country")
      attrs[:birth_country] ||= "FR"
    end

    presence_attrs = User.validators.grep(ActiveModel::Validations::PresenceValidator)
                         .flat_map(&:attributes)
                         .map(&:to_s)
                         .uniq

    presence_attrs.each do |field|
      next if attrs.key?(field.to_sym)
      next unless User.column_names.include?(field)

      col = User.columns_hash[field]
      attrs[field.to_sym] =
        case col.type
        when :date
          Date.new(1990, 1, 1)
        when :datetime, :time
          Time.current
        when :integer
          0
        when :float, :decimal
          0
        when :boolean
          false
        else
          "XX"
        end
    end

    User.create!(attrs)
  end

  def create_city!(user:, total_population: 200, workers_population: 120, free_population: 80, **attrs)
    defaults = {
      user: user,
      total_population: total_population,
      free_population: free_population,
      workers_population: workers_population,
      military_population: 0,
      university_population: 0,
      laboratory_population: 0,
      food: 10_000,
      coal: 0,
      iron_ore: 0,
      stone: 10_000,
      wood: 10_000,
      crude_oil: 0,
      fuel: 0,
      energy: 0,
      knowledge: 0,
      money: 10_000
    }

    City.create!(defaults.merge(attrs))
  end

  def create_building!(key: "farm-#{SecureRandom.hex(3)}", rules: {})
    normalized_rules =
      if rules.is_a?(Hash) && rules.key?("levels")
        rules
      else
        { "levels" => rules.transform_keys(&:to_s) }
      end

    Building.create!(
      key: key,
      name: key.capitalize,
      description: "",
      image: "",
      infrastructure_cost: 0,
      has_hp: true,
      rules: normalized_rules
    )
  end

  def create_city_building!(city:, building:, level: 1, enabled: true, workers_assigned: 0, assigned_resource: nil)
    CityBuilding.create!(
      city: city,
      building: building,
      level: level,
      enabled: enabled,
      workers_assigned: workers_assigned,
      assigned_resource: assigned_resource
    )
  end
end
