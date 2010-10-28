class ChangeCoordsColumnType < ActiveRecord::Migration
  def self.up
    change_column :g_map_tracks, :coords, :mediumtext
  end

  def self.down
    change_column :g_map_tracks, :coords, :varchar
  end
end
