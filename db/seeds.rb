require 'faker'
require 'set'

puts "Cleaning the Database..."

Favorite.destroy_all if defined?(Favorite)
UserReview.destroy_all
Dose.destroy_all
Tag.destroy_all
Cocktail.destroy_all
Ingredient.destroy_all
User.destroy_all

puts "Database cleaned!"

# ---------- USERS ----------
puts "Creating users..."
users = []
22.times do
  username = Faker::Internet.username(specifier: 5..10).gsub(/[^A-Za-z0-9_]/, '_')
  user = User.create!(
    email: Faker::Internet.unique.email,
    password: ENV["USER_PASSWORDS"],
    username: username,
    first_name: Faker::Name.first_name,
    admin: false
  )
  users << user
end
user_admin = User.create!(
    email: ENV["ADMIN_EMAIL"],
    password: ENV["ADMIN_PASSWORD"],
    username: ENV["ADMIN_USERNAME"],
    first_name: Faker::Name.first_name,
    admin: true
  )
users << user_admin
user_1 = User.create!(
    email: ENV["USER_1_EMAIL"],
    password: ENV["USER_1_PASSWORD"],
    username: ENV["USER_1_USERNAME"],
    first_name: Faker::Name.first_name,
    admin: false
  )
users << user_1
puts "#{users.count} users created!"

# ---------- INGREDIENTS ----------
puts "Creating ingredients..."
ingredient_names = [
  "Tequila", "Triple Sec", "Lime Juice", "Vodka", "Coffee Liqueur",
  "Espresso", "Rum", "Coconut Cream", "Pineapple Juice",
  "Grapefruit Soda", "Gin", "Tonic Water", "Lemon Juice",
  "Simple Syrup", "Bitters", "Whiskey", "Vermouth", "Cranberry Juice",
  "Honey Syrup", "Mint Leaves", "Orange Peel"
]

ingredients = ingredient_names.map { |name| Ingredient.find_or_create_by!(name: name) }
puts "#{ingredients.count} ingredients created!"

# ---------- COCKTAILS ----------
puts "Creating cocktails..."
cocktails = []
used_cocktail_names = Set.new

users.each do |user|
  rand(1..4).times do
    # Generate a unique and descriptive cocktail name
    name = "#{Faker::Beer.name} #{['Martini', 'Fizz', 'Sour', 'Cooler', 'Spritz'].sample}".titleize
    next if used_cocktail_names.include?(name)
    used_cocktail_names << name

    # Create a short description about the cocktail.
    short_descriptions = [
      "A light, refreshing citrus drink with a subtle herbal finish.",
      "A bold, spirit-forward cocktail with warm notes of spice and oak.",
      "A crisp, bubbly concoction with bright berry aromas and a dry finish.",
      "A smooth, tropical blend with creamy texture and hints of coconut.",
      "A tart, zesty drink balanced by gentle sweetness and floral notes.",
      "A smoky, complex sipper with bittersweet undertones and lingering heat.",
      "A delicately sweet, tea-infused cocktail with soft citrus accents.",
      "A refreshing, garden-inspired mix with cucumber, herbs, and a clean finish.",
      "A rich, dessert-like drink with chocolate, coffee, and vanilla hints.",
      "A vibrant, fruity cocktail with a punchy aroma and a dry, crisp bite."
    ]

    about = short_descriptions.sample.capitalize

    # Create a realistic cocktail-style recipe description
    methods = [
      "Shake all ingredients with ice and strain into a chilled coupe glass.",
      "Stirring with ice until well chilled, then strain into a rocks glass over a large cube.",
      "Blend all ingredients until smooth, then serve with crushed ice in a tall glass.",
      "Pour over ice and top with soda for a light and refreshing finish."
    ]

    description = "Combine #{ingredients.sample.name.downcase}, #{ingredients.sample.name.downcase}, and "\
                  "#{ingredients.sample.name.downcase} in a shaker. #{methods.sample} "\
                  "Garnish with #{['a lime wheel', 'a mint sprig', 'an orange twist', 'a maraschino cherry'].sample} "\
                  "to complete this handcrafted cocktail experience."

    cocktail = Cocktail.create!(
      user: user,
      name: name,
      about: about,
      description: description
    )

    # Add doses (ingredient quantities)
    chosen_ingredients = ingredients.sample(rand(2..5))
    chosen_ingredients.each do |ingredient|
      Dose.find_or_create_by!(cocktail: cocktail, ingredient: ingredient) do |dose|
        dose.amount = rand(15..90) # in milliliters
      end
    end

    # Tag cocktails by key ingredients
    chosen_ingredients.each do |ingredient|
      Tag.find_or_create_by!(name: ingredient.name.downcase, cocktail: cocktail)
    end

    cocktails << cocktail
  end
end
puts "#{cocktails.count} cocktails created!"

# ---------- FAVORITES ----------
puts "Creating favorites..."
users.each do |user|
  favorite_count = [rand(10..40), cocktails.count].min
  cocktails.sample(favorite_count).each do |cocktail|
    next if cocktail.user == user
    user.favorites.find_or_create_by!(cocktail: cocktail)
  end
end
puts "Favorites created!"

# ---------- REVIEWS ----------
puts "Creating user reviews..."
users.each do |user|
  review_count = [rand(10..60), cocktails.count].min
  cocktails.sample(review_count).each do |cocktail|
    next if cocktail.user == user
    UserReview.find_or_create_by!(cocktail: cocktail, user: user) do |review|
      review.rating = rand(3.0..5.0).round(1)
      review.title = [
        "Perfectly Balanced",
        "Sweet and Smooth",
        "A Summer Favorite",
        "Classic",
        "Bold but Refreshing",
        "Too Good to Share",
        "Unexpected Delight",
        "Strong!",
        "Tropical Bliss",
        "Mixology Magic"
      ].sample
      review.review = "#{Faker::Restaurant.review} #{SecureRandom.hex(3)}"
      review.img_1 = "#{Faker::LoremFlickr.image(size: '400x400', search_terms: ['cocktail'])}?#{SecureRandom.hex(2)}"
      review.img_2 = "#{Faker::LoremFlickr.image(size: '400x400', search_terms: ['drink'])}?#{SecureRandom.hex(2)}"
      review.img_3 = "#{Faker::LoremFlickr.image(size: '400x400', search_terms: ['glass'])}?#{SecureRandom.hex(2)}"
    end
  end
end
puts "User reviews created!"

puts "Seed complete! 🎉 #{users.count} Users, #{cocktails.count} Cocktails, and #{users.count * 10}+ interactions generated!"
