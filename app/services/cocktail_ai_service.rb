class CocktailAiService
  def initialize(user, model: 'gpt-4o')
    @user = user
    @model = model
  end

  # CREATE new cocktail from prompt
  def create_from_prompt(prompt)
    chat = build_chat_for_creation
    response = chat.ask(prompt)

    # Create cocktail with nested associations
    build_cocktail_from_data(response.content)
  end

  # REVISE existing cocktail
  def revise_cocktail(cocktail, revision_prompt)
    chat = build_chat_for_revision(cocktail)
    response = chat.ask(revision_prompt)

    # Update cocktail with nested associations
    update_cocktail_from_data(cocktail, response.content)
  end

  private

  # SipSense Mix AI cocktail CREATION methods and logic.
  def build_chat_for_creation
    RubyLLM.chat(model: @model).with_schema(CocktailSchema).with_instructions(creation_prompt)
  end

  def creation_prompt
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

  def build_cocktail_from_data(data)
    # build method creates cocktail in memory with user association automatically set.
    cocktail = @user.cocktails.build(
      name: data["name"],
      about: data["about"],
      description: data["description"],
      img_url: Cocktail::COCKTAIL_IMAGES.sample
    )

    # Loop through AI-generated ingredients
    data["ingredients"].each do |ingredient_data|
      # Find existing ingredient or create new one (prevents duplicates)
      # titleize ensures consistent capitalization: "lime juice" -> "Lime Juice"
      ingredient = Ingredient.find_or_create_by(
        name: ingredient_data["ingredient_name"].titleize
      )

      # Build method creates dose in memory, linked to cocktail and ingredient.
      cocktail.doses.build(ingredient: ingredient, amount: ingredient_data["amount"])
    end

    # Loop through AI-generated tags
    data["tags"].each do |tag_name|
      # build method creates tag in memory, linked to cocktail.
      cocktail.tags.build(name: tag_name.downcase)
    end

    cocktail.ai_generated = true

    # Save cocktail with all associations in one database transaction.
    # If any validation fails, nothing gets saved (maintains data integrity).
    cocktail.save
    # return the "built" cocktail object.
    cocktail
  end

  # SipSense Mix AI cocktail REVISION methods and logic.
  def build_chat_for_revision(cocktail)
    RubyLLM.chat(model: @model).with_schema(CocktailSchema).with_instructions(revision_prompt(cocktail))
  end

  def revision_prompt(cocktail)
    current_ingredients = cocktail.doses.map do |dose|
      "#{dose.amount}ml #{dose.ingredient.name}"
    end.join(", ")

    current_tags = cocktail.tags.pluck(:name).join(", ")

    <<~PROMPT
      Persona: You are SipSense AI, an expert mixologist with 20 years of experience crafting innovation and classic cocktails. You understand flavor profiles, balance, and proper mixology techniques.

      Context: You're helping a Sipfolio app user revise an existing cocktail recipe. The user wants to improve or modify their cocktail based on their feedback.

      Current Cocktail:
      - Name: #{cocktail.name}
      - About: #{cocktail.about}
      - Description: #{cocktail.description}
      - Ingredients: #{current_ingredients}
      - Tags: #{current_tags}

      Task: Based on the user's revision request, create an improved version of this cocktail. You may adjust ingredients, measurements, change the name, or completely reimagine it based on their feedback.

      Guidelines:
      - Keep what works unless the user asks to change it.
      - Measurements in millimeters (ml) as decimals.
      - Maximum 5 ingredients (respects the cocktail validation).
      - 3-10 relevant tags.
      - Maintain or improve flavor balance.
      - If user is vague, make thoughtful improvements.
    PROMPT
  end

  def update_cocktail_from_data(cocktail, data)
    # Clear existing associations
    cocktail.doses.destroy_all
    cocktail.tags.destroy_all

    # Update basic attributes
    cocktail.name = data["name"]
    cocktail.about = data["about"]
    cocktail.description = data["description"]
    # cocktail.img_url = Cocktail::COCKTAIL_IMAGES.sample

    # Rebuild associations
    # Loop through AI-generated ingredients
    data["ingredients"].each do |ingredient_data|
      # Find existing ingredient or create new one (prevents duplicates)
      # titleize ensures consistent capitalization: "lime juice" -> "Lime Juice"
      ingredient = Ingredient.find_or_create_by(
        name: ingredient_data["ingredient_name"].titleize
      )

      # Build method creates dose in memory, linked to cocktail and ingredient.
      cocktail.doses.build(ingredient: ingredient, amount: ingredient_data["amount"])
    end

    # Loop through AI-generated tags
    data["tags"].each do |tag_name|
      # build method creates tag in memory, linked to cocktail.
      cocktail.tags.build(name: tag_name.downcase)
    end

    # Save cocktail with all associations in one database transaction.
    # If any validation fails, nothing gets saved (maintains data integrity).
    cocktail.save
    # return the "built" cocktail object.
    cocktail
  end
end
