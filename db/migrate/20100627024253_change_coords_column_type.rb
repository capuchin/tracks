class ChangeCoordsColumnType < ActiveRecord::Migration
  def self.up
    change_column :g_map_tracks, :coords, :text
  end

  def self.down
    change_column :g_map_tracks, :coords, :varchar
  end
end
