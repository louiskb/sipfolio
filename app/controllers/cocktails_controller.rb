class CocktailsController < ApplicationController
  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  def sipsense_mix
    # Renders the form view.
  end

  def create_with_ai
    user_prompt = cocktail_ai_params[:prompt]

    begin # Start error handling block

      # Initialize chat with schema and instructions
      chat = RubyLLM.chat(model: 'gpt-4.1-nano').with_schema(CocktailSchema).with_instructions(context_prompt)

      # Get AI response
      response = chat.ask(user_prompt)
      cocktail_data = response.content

      # Create cocktail with nested associations
      @cocktail = create_cocktail_from_ai_data(cocktail_data)

      if @cocktail.persisted?
        redirect_to @cocktail, notice: "🍹 SipSense AI created your cocktail!"
      else
        flash.now[:alert] = "Failed to create cocktail: #{@cocktail.error.full_messages.join(', ')}"
        @prompt = user_prompt # Preserve user input
        render :sipsense_mix, status: :unprocessable_entity
      end

    rescue StandardError => e # Catch any errors (API failures, network issues, etc.)
      Rails.logger.error "AI cocktail creation failed: #{e.message}"
      Rails.logger.error "AI encountered an error. Please try again."
      @prompt = user_prompt
      render :sipsense_mix, status: :unprocessable_entity
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

  def cocktail_ai_params
    params.require(:cocktail).permit(:prompt)
  end

  def context_prompt
    <<~PROMPT
      Persona: You are SipSense AI, an expert mixologist with 20 years of experience crafting innovation and classic cocktails. You understand flavor profiles, balance, and proper mixology techniques.

      Context: You're helping users of Sipfolio, a cocktail portfolio app for enthusiasts and professionals. The recipes you create will be saved to their personal collection and potentially shared with the community. Your audience ranges from home bartenders to professional mixologists.

      Task: based ont he user's description, create a complete, well-balanced cocktail recipe. The recipe must be practical, delicious, and follow proper mixology principles. Ensure measurements are precise in ml and instructions are clear.

      Guidelines:
      - Measurements must be in millimeters (ml) as decimal numbers (e.g. 1.5, 2.0, 0.5, 0.25)
      - Maximum 5 ingredients (respects the cocktail validation)
      - Use standard bar ingredients unless user specifically requests exotic items.
      - Create balanced flavor profiles (consider sweet, sour, bitter, strong elements).
      - Include 3-10 relevant tags for categorization (under the 10 tag limit).
      - Be creative with names but keep them memorable and appealing.
      - If the user's request is vague, use your expertise to create something exceptional.
    PROMPT
  end

  def create_cocktail_from_ai_data(data)
    # build method creates cocktail in memory with user association automatically set.
    cocktail = current_user.cocktails.build(
      name: data["name"],
      description: data["description"]
    )

    # Loop through AI-generated ingredients
    data["ingredients"].each do |ingredient_data|
      # Find existing ingredient or create new one (prevents duplicates)
      # titleize ensures consistent capitalization: "lime juice" -> "Lime Juice"
      ingredient = Ingredient.find_or_create_by(
        name: ingredient_data["ingredient_name"].titleize
      )

      # Build method creates dose in memory, linked to cocktail and ingredient.
      cocktail.doses.build(
        ingredient: ingredient,
        amount: ingredient_data["amount"]
      )
    end

      # Loop through AI-generated tags
      data["tags"].each do |tag_name|
        #build method creates tag in memory, linked to cocktail.
        cocktail.tags.build(name: tag_name.downcase)
      end

      # Save cocktail with all associations in one database transaction.
      # If any validation fails, nothing gets saved (maintains data integrity).
      cocktail.save

      # Return the cocktail object.
      cocktail
    end
  end

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
