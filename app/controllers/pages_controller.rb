class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
    @hero_banner = hero_banner_list
  end

  def user_profile
    @user = current_user
    @cocktails = @user.cocktails
    @hero_banner = hero_banner_list
  end

  def journal
    @user = current_user
    @cocktails = @user.cocktails
    @cocktail_favs = @user.favorited_cocktails
    @user_reviews = UserReview.all
    @cocktail_img_list = create_img_list
  end

  private

  def create_img_list
    (1..26).map { |i| "cocktail-#{i}.jpg" }
  end

  def hero_banner_list
    ["cocktail-banner-3.jpg", "cocktail-banner-9.jpg", "cocktail-banner-10.jpg", "cocktails-banner-1.jpg", "cocktails-banner-1.jpg", "cocktails-banner-2.jpg", "cocktails-banner-4.jpg", "cocktails-banner-5.jpg", "cocktails-banner-7.jpg", "cocktails-banner-8.jpg", "cocktails-banner-9.jpg"]
  end
end
