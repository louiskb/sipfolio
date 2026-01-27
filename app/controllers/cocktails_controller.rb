class CocktailsController < ApplicationController
  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?
  before_action :set_cocktail, only: [:sipsense_revise, :revise_with_ai]

  # CREATE WITH AI
  def sipsense_mix
    # Renders the create form view.
    authorize Cocktail, :create_with_ai?
  end

  def create_with_ai
    # Create a cocktail with ai process / logic.
    authorize Cocktail, :create_with_ai?

    begin # Start error handling block
      service = CocktailAiService.new(current_user)
      @cocktail = service.create_from_prompt(cocktail_ai_params[:prompt])


      if @cocktail.persisted?
        redirect_to @cocktail, notice: "SipSense AI created your cocktail!"
      else
        flash.now[:alert] = "Failed #{@cocktail.errors.full_messages.join(', ')}"
        @prompt = cocktail_ai_params[:prompt] # Preserve user input. cocktail_ai_params is a method call that returns a hash `Returns: { prompt: "..." }` and the hash keys are accessed using square brackets like so `cocktail_ai_params[:prompt]`. cocktail_ai_params does not accept any arguments either.
        render :sipsense_mix, status: :unprocessable_content
      end

    rescue StandardError => e # Catch any errors (API failures, network issues, etc.)
      handle_ai_error(e, :sipsense_mix)
    end # End error handling block
  end

  # REVISE WITH AI
  def sipsense_revise
    # Renders the revise form view.
    authorize @cocktail, :sipsense_revise?
  end

  def revise_with_ai
    # Revise a cocktail with ai process / logic.
    authorize @cocktail, :revise_with_ai?

    begin
      service = CocktailAiService.new(current_user)
      @cocktail = service.revise_cocktail(@cocktail, cocktail_ai_params[:prompt])

      if @cocktail.persisted?
        redirect_to @cocktail, notice: "SipSense AI revised your cocktail!"
      else
        flash.now[:alert] = "Failed: #{@cocktail.errors.full_messages.join(', ')}"
        @prompt = cocktail_ai_params[:prompt] # Preserve user input. cocktail_ai_params is a method call that returns a hash `Returns: { prompt: "..." }` and the hash keys are accessed using square brackets like so `cocktail_ai_params[:prompt]`. cocktail_ai_params does not accept any arguments either.
        render :sipsense_revise, status: :unprocessable_content
      end
    rescue StandardError => e # Catch any errors (API failures, network issues, etc.)
      handle_ai_error(e, :sipsense_revise)
    end # End error handling block
  end

  def index
    # @cocktails = Cocktail.all
    # Above (uncommented `@cocktails = Cocktail.all`) is the unfiltered version of cocktails and holds the entire unfiltered collection of cocktails.
    @cocktails = policy_scope(Cocktail) # Holds the filtered collection of cocktails that the current user is authorized to see, according to the rules defined in the CocktailPolicy.
    @ingredients = Ingredient.all
    @doses = Dose.all
    @tags = Tag.all
    @user_reviews = UserReview.all
    @cocktail_favs = current_user.favorited_cocktails
    @hero_banner = hero_banner_list
  end

  def show
    @cocktail = Cocktail.find(params[:id])
    @ingredients = @cocktail.ingredients
    @doses = @cocktail.doses
    @tags = @cocktail.tags
    @user_reviews = @cocktail.user_reviews
    @cocktail_rating_avg = show_cocktail_ratings(@user_reviews, @cocktail)
    @cocktail_img_list = create_img_list
    authorize @cocktail # Another way to write this is authorize(@cocktail) but Ruby syntax allows the omission of parentheses () after the method call (#authorize) when the meaning is clear. It is common in Rails code to write the version without parentheses for readability.
  end

  def new
    @cocktail = Cocktail.new
    5.times { @cocktail.doses.build.build_ingredient } # builds both dose and nested ingredient
    10.times { @cocktail.tags.build }
    @hero_banner = hero_banner_list
    authorize @cocktail
  end

  def create
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
    @hero_banner = hero_banner_list
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

  # AI Creation and Revise methods
  def set_cocktail
    @cocktail = Cocktail.find(params[:id])
  end

  def cocktail_ai_params
    params.require(:cocktail).permit(:prompt)
  end

  def handle_ai_error(error, render_action)
    Rails.logger.error "AI error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    flash.now[:alert] = "AI encountered an error. Please try again."
    @prompt = cocktail_ai_params[:prompt]
    render render_action, status: :unprocessable_content
  end

  # Non-AI methods
  def cocktail_params
    params.require(:cocktail).permit(:name, :about, :description, :img_url, :photo, doses_attributes: [:id, :amount, :ingredient_id, { ingredient_attributes: [:id, :name] }, :_destroy], tags_attributes: [:id, :name, :_destroy])
  end

  def create_img_list
    (1..26).map { |i| "cocktail-#{i}.jpg" }
  end

  def hero_banner_list
    ["cocktail-banner-3.jpg", "cocktail-banner-9.jpg", "cocktail-banner-10.jpg", "cocktails-banner-1.jpg", "cocktails-banner-1.jpg", "cocktails-banner-2.jpg", "cocktails-banner-4.jpg", "cocktails-banner-5.jpg", "cocktails-banner-7.jpg", "cocktails-banner-8.jpg", "cocktails-banner-9.jpg"]
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
