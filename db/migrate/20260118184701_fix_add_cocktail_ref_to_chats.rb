class FixAddCocktailRefToChats < ActiveRecord::Migration[7.1]
def up
  add_reference :chats, :cocktail, index: true, foreign_key: true

  execute <<-SQL.squish
    UPDATE chats
    SET cocktail_id = (SELECT id FROM cocktails ORDER BY id LIMIT 1)
    WHERE cocktail_id IS NULL;
  SQL

  change_column_null :chats, :cocktail_id, false
end
end
