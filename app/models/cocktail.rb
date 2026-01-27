class Cocktail < ApplicationRecord
  # Associations
  # The `dependent: :destroy` on cocktails deletes associated doses when a cocktail is deleted, but not ingredients.
  belongs_to :user
  has_many :favorites, dependent: :destroy # cocktails owned by user
  has_many :favorited_by_users, through: :favorites, source: :user # creates method cocktail.favorited_by_users, which returns all users who have favorited this cocktail.
  has_many :doses, dependent: :destroy # creates a method cocktail.doses
  has_many :ingredients, through: :doses # creates a method cocktail.ingredients
  has_many :tags, dependent: :destroy # creates a method cocktail.tags
  has_many :user_reviews, dependent: :destroy # creates a method cocktail.user_reviews
  has_one_attached :photo # The `has_one_attached` macro (`has_one_attached :photo`) sets up a one-to-one mapping between records and files. Each record can have one file attached to it.
  # The `has_many_attached` macro (`has_many_attached :photos`) sets up a one-to-many relationship between records and files. Each record can have many files attached to it.

  accepts_nested_attributes_for :doses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :tags, allow_destroy: true, reject_if: :all_blank
  # accepts_nested_attributes_for :tags, allow_destroy: true, reject_if: proc { |attributes| attributes["name"].blank? }
  # The code in line 10 probably does the same as the code in line 9.

  #validations
  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: true
  validates :about, presence: true # Short description about the cocktail.
  validates :description, presence: true # Recipe method.
  COCKTAIL_IMAGES = (1..26).map { |i| "cocktail-#{i}.jpg" } # Builds an array of strings with reference to the cocktail image file names ["cocktail-1.jpg", "cocktail-2.jpg", "cocktail-3.jpg", "...", "cocktail-26.jpg"]
  validates :img_url, inclusion: { in: COCKTAIL_IMAGES}, allow_blank: true
  # The `inclusion` validation already ensures a value must be selected from the list, so `presence: true` is redundant.
  # The `allow_blank: true` option lets the field be empty but still validates it if a value is provided.
  # Image url (drop down menu in form) linking to images already saved inside web app.

  validate :max_doses_limit # In Rails, `validates` (plural) is used for built-in validation helpers like presence, uniqueness, length, and format, while `validate` (singular) is used for custom validation methods that contain your own business logic.
  validate :max_tags_limit

  private

  def max_doses_limit
    if doses.size > 5
      errors.add(:doses, "maximum 5 ingredients are allowed")
    end
  end

  def max_tags_limit
    if tags.size > 10
      errors.add(:tags, "maximum 10 tags are allowed")
    end
  end
end
