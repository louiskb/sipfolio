class CocktailSchema < RubyLLM::Schema
  # Basic cocktail info.
  string :name,
    description: "Creative and appealing cocktail name"

  string :about,
    description: "A short descriptive summary about the cocktail like flavor profile, characteristics, and/or best setting/times to drink it"

  string :description,
    description: "Recipe method on how to make the cocktail drink with clear instructions (2-5 sentences)"

  # Ingredients as array of objects matching doses model.
  array :ingredients,
    description: "List of ingredients with precise measurements" do
      object do
          string :ingredient_name,
          description: "Name of the ingredient (e.g. 'Vodka', 'Lime Juice', 'Syrup')"

          float :amount,
            description: "Amount in ml. Can use decimals like 1.5, 2.0, 0.5, 0.25"
      end
    end

  # Tags as simple array of strings
  array :tags,
    of: :string,
    description: "3-5 descriptive tags (e.g. 'sweet', 'refreshing', 'citrus', 'strong', 'tropical', 'classical')"
end
