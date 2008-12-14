class Track < ActiveRecord::Base
  belongs_to :area
  has_many :track_akas, :order => 'name'
  belongs_to :track_grade
  belongs_to :track_access
  belongs_to :condition
  has_many :track_connections
  has_many :track_reports

  validates_presence_of   :name
  validates_format_of     :name, :with => /^[\w ']+$/i, :message => 'can only contain letters and numbers (and spaces).'
  validate                :ensure_name_not_numeric
  validates_length_of     :name, :maximum => 40, :message => 'Track name too long, maximum is 40 characters.'
  validates_uniqueness_of :name
  validate                :overview_is_not_empty

  RECENT_TRACK_COUNT = 3
  RECENT_HISTORY_OFFSET = Time.now - 1.week

  def self.find_recent(limit = RECENT_TRACK_COUNT, offset = RECENT_HISTORY_OFFSET)
    previous_by_time = find(:all, :order => 'date DESC', :conditions => ["date > ?", offset])
    previous_by_time.length > limit ? previous_by_time : find(:all, :limit => limit, :order => 'date DESC')
  end

  def self.find_recent_by(area_id)
    previous_by_time = find(:all, :order => 'date DESC', :conditions => ["area_id = ? AND date > ?", area_id, RECENT_HISTORY_OFFSET])
    previous_by_time.length > RECENT_TRACK_COUNT ? previous_by_time : find(:all, :limit => RECENT_TRACK_COUNT, :order => 'date DESC', :conditions => ["area_id = ?", area_id])
  end
  
  def file_path_exists?
    FileTest.exist?(full_filename)
  end
  
  def filename
    "#{self.area.state.nation.id}_#{self.area.state.id}_#{self.area.id}_#{self.id}.kml"
  end
  
  def full_filename
    "#{RAILS_ROOT}/public/paths/" + filename
  end

  # Track connections in array of [connecting_track_name,connection_id,track_id]
  def get_connections
    connections = []
    track_connections.each do |c|
      connections << [Track.find(c.connect_track_id, :select => "name").name, c.id, c.connect_track_id]
    end
    connections.sort
  end

private

  def ensure_name_not_numeric
    errors.add(:name, "cannot be all numbers") if /^[0-9]*$/.match(name)
  end
  
  def overview_is_not_empty
    errors.add(nil, "Overview cannot be empty.") if desc_overview.empty?
  end
end
