class AddCoordsToGMapTrack < ActiveRecord::Migration
  def self.up
    add_column :g_map_tracks, :coords, :string
  end

  def self.down
    remove_column :g_map_tracks, :coords
  end
end
