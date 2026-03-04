class CitiesController < ApplicationController
  before_action :require_user!
  before_action :set_city, only: %i[show]

  def index
    @cities = current_user.cities
  end

  def show
    @city.tick!
  end

  private

  # No usamos Devise aquí: solo bloquea si no hay sesión de usuario.
  def require_user!
    head(:unauthorized) unless current_user
  end

  def set_city
    @city = current_user.cities.find(params[:id])
  end
end
