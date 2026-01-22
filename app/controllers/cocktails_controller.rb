class CocktailsController < ApplicationController
  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  def index
    # @cocktails = Cocktail.all
    # Above (uncommented `@cocktails = Cocktail.all`) is the unfiltered version of cocktails and holds the entire unfiltered collection of cocktails.
    @cocktails = policy_scope(Cocktail) # Holds the filtered collection of cocktails that the current user is authorized to see, according to the rules defined in the CocktailPolicy.
    @ingredients = Ingredient.all
    @doses = Dose.all
    @tags = Tag.all
    @user_reviews = UserReview.all
    @cocktail_favs = current_user.favorited_cocktails
  end

  def show
    @cocktail = Cocktail.find(params[:id])
    @ingredients = @cocktail.ingredients
    @doses = @cocktail.doses
    @tags = @cocktail.tags
    @user_reviews = @cocktail.user_reviews
    @cocktail_rating_avg = show_cocktail_ratings(@user_reviews, @cocktail)
    authorize @cocktail # Another way to write this is authorize(@cocktail) but Ruby syntax allows the omission of parentheses () after the method call (#authorize) when the meaning is clear. It is common in Rails code to write the version without parentheses for readability.
  end

  def new
    @cocktail = Cocktail.new
    5.times { @cocktail.doses.build.build_ingredient } # builds both dose and nested ingredient
    10.times { @cocktail.tags.build }
    authorize @cocktail
  end

  def create
    # raise
    @cocktail = Cocktail.new(cocktail_params)
    @cocktail.user = current_user
    authorize @cocktail

    if @cocktail.save
      redirect_to cocktail_path(@cocktail), notice: "Cocktail was successfully created."
    else
      render "new", status: :unprocessable_content
    end
  end

  def edit
    @cocktail = Cocktail.find(params[:id])
    authorize @cocktail
  end

  def update
    @cocktail = Cocktail.find(params[:id])
    authorize @cocktail

    if @cocktail.update(cocktail_params)
      redirect_to cocktail_path(@cocktail)
    else
      render "edit", status: :unprocessable_content
    end
  end

  def destroy
    @cocktail = Cocktail.find(params[:id])
    authorize @cocktail

    if @cocktail.destroy
      redirect_to cocktails_path, status: :see_other
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def cocktail_params
    params.require(:cocktail).permit(:name, :about, :description, doses_attributes: [:id, :amount, :ingredient_id, { ingredient_attributes: [:id, :name] }, :_destroy], tags_attributes: [:id, :name, :_destroy])
  end

  def show_cocktail_ratings(user_reviews, cocktail)
    cocktail_rating = []

    user_reviews.each do |review|
      cocktail_rating.push(review.rating)
    end

    if cocktail_rating.any?
      (cocktail_rating.sum / cocktail_rating.length)
    else
      0
    end

  end

end
