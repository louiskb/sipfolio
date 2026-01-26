class AddImgUrlToCocktails < ActiveRecord::Migration[7.1]
  def change
    add_column :cocktails, :img_url, :string
  end
end
