class AddAiGeneratedToCocktails < ActiveRecord::Migration[7.1]
  def change
    add_column :cocktails, :ai_generated, :boolean
  end
end
