class AddAboutToCocktails < ActiveRecord::Migration[7.1]
  def change
    add_column :cocktails, :about, :string
  end
end
