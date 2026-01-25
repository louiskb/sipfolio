class RemoveCocktailFromChats < ActiveRecord::Migration[7.1]
  def change
    remove_reference :chats, :cocktail, null: false, foreign_key: true
  end
end
