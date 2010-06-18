class CreateGChartTracks < ActiveRecord::Migration
  def self.up
    create_table :g_chart_tracks do |t|
      t.integer :track_id
      t.text :data

      t.timestamps
    end
  end

  def self.down
    drop_table :g_chart_tracks
  end
end

