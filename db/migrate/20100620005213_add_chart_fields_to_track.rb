class AddChartFieldsToTrack < ActiveRecord::Migration
  def self.up
    add_column :tracks, :display_chart, :boolean, :default => 1
    add_column :tracks, :type_of_chart, :string, :default => 'single'

  end

  def self.down
    remove_column :tracks, :display_chart
    remove_column :tracks, :type_of_chart
  end
end
