class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
  end

  def user_profile
    @user = current_user
    @cocktails = @user.cocktails
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
end
