class ProfilesController < ApplicationController

  def index
    # joins(:user) adds INNER JOIN users ON users.id = profiles.user_id
    # users.username references the joined table's column
    @profiles = Profile.joins(:user).order("users.username ASC")
    @hero_banner = hero_banner_list
  end

  def show
    @profile = Profile.find(params[:id])
    @hero_banner = hero_banner_list
  end

  private

  def hero_banner_list
    ["cocktail-banner-3.jpg", "cocktail-banner-9.jpg", "cocktail-banner-10.jpg", "cocktails-banner-1.jpg", "cocktails-banner-1.jpg", "cocktails-banner-2.jpg", "cocktails-banner-4.jpg", "cocktails-banner-5.jpg", "cocktails-banner-7.jpg", "cocktails-banner-8.jpg", "cocktails-banner-9.jpg"]
  end

end
