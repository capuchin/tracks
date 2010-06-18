class AddLengthToGMapTrack < ActiveRecord::Migration
  def self.up
    add_column :g_map_tracks, :length, :float
  end

  def self.down
    remove_column :g_map_tracks, :length
  end
end
