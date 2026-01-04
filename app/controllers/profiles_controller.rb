class ProfilesController < ApplicationController

  def index
    # joins(:user) adds INNER JOIN users ON users.id = profiles.user_id
    # users.username references the joined table's column
    @profiles = Profile.joins(:user).order("users.username ASC")
  end

  def show
    @profile = Profile.find(params[:id])

  end


end
