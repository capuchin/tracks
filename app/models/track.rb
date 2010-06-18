class Track < ActiveRecord::Base

  require 'gmap_polyline_encoder'
  require 'hpricot'
  include TwitterHelper
  include TextHelper
  include Coords

  require 'rubygems'
  require 'json'
  require 'net/http'

  belongs_to :area
  has_many :track_akas, :order => 'name'
  belongs_to :track_grade
  belongs_to :track_access
  belongs_to :condition
  has_many :track_connections
  has_many :track_reports
  has_many :g_map_tracks, :order => 'sequence'
  has_many :g_chart_tracks
  # has_many :medias, :conditions => ["ref_type = ? AND ref_id = ?", 'track', id]

  before_validation       :fix_name
  validates_presence_of   :name
  validates_format_of     :name, :with => /^[\w ']+$/i, :message => 'can only contain letters and numbers (and spaces).'
  validates_length_of     :name, :maximum => 40, :message => 'Track name too long, maximum is 40 characters.'
  validate                :name_is_unique_for_region
  validate                :overview_is_not_empty

  RECENT_TRACK_COUNT = 5
  RECENT_HISTORY_OFFSET = Time.now - 1.week
  Track::LENGTH_SOURCE_CALC = 'calc'
  Track::LENGTH_SOURCE_USER = 'user'

  def medias
    Media.find(:all, :conditions => ["ref_type = ? AND ref_id = ?", 'track', id])
  end

  # Apply % adjustment for calculated lengths
  def adjusted_length
    return length if length_source == LENGTH_SOURCE_USER
    (length * (100 + length_adjust_percent)) / 100
  end

  def self.find_recent(offset = RECENT_HISTORY_OFFSET)
    previous_by_time = find(:all, :order => 'updated_at DESC', :conditions => ["updated_at > ?", offset])
    previous_by_time.length > RECENT_TRACK_COUNT ? previous_by_time : find(:all, :limit => RECENT_TRACK_COUNT, :order => 'updated_at DESC')
  end

  def self.find_recent_by_area(area_id)
    previous_by_time = find(:all, :order => 'updated_at DESC', :conditions => ["area_id = ? AND updated_at > ?", area_id, RECENT_HISTORY_OFFSET])
    previous_by_time.length > RECENT_TRACK_COUNT ? previous_by_time : find(:all, :limit => RECENT_TRACK_COUNT, :order => 'updated_at DESC', :conditions => ["area_id = ?", area_id])
  end

  def self.find_recent_by_region(region_id)
    track_ids = []
    Region.find(region_id).areas.each do |a|
      track_ids << a.tracks.collect(&:id)
    end

    previous_by_time = find(:all, :order => 'updated_at DESC', :conditions => ["id in (?) AND updated_at > ?", track_ids.flatten, RECENT_HISTORY_OFFSET])
    previous_by_time.length > RECENT_TRACK_COUNT ? previous_by_time : find(:all, :limit => RECENT_TRACK_COUNT, :order => 'updated_at DESC', :conditions => ["id in (?)", track_ids.flatten])

    # previous_by_time = find(:all, :order => 'updated_at DESC', :conditions => ["area_id = ? AND updated_at > ?", area_id, RECENT_HISTORY_OFFSET])
    # previous_by_time.length > RECENT_TRACK_COUNT ? previous_by_time : find(:all, :limit => RECENT_TRACK_COUNT, :order => 'updated_at DESC', :conditions => ["area_id = ?", area_id])
  end

  def file_path_exists?
    FileTest.exist?(full_filename)
  end
  
  def filename
    "#{id}"
  end
  
  def full_filename
    "paths/" + filename
  end

  def gps_file_exists?
    gpx_file_exists? || kml_file_exists?
  end

  def gpx_file_exists?
    File.exists?("#{full_filename}.gpx")
  end

  def kml_file_exists?
    File.exists?("#{full_filename}.kml")
  end

  def process_kml_path(doc)
    GMapTrack.delete(g_map_tracks)
    main_name = doc.search('name').first
    main_name = main_name.nil? ? name : main_name.inner_html
    len = 0.0

    # Go through each 'placemark', get name and then process the coordinates
    doc.search("placemark").each_with_index do |placemark, i|
      sub_name = placemark.search('name')
      sub_name = sub_name.nil? ? name : sub_name.inner_html
      next if placemark.search('linestring').empty?
      coords = ""
      placemark.search('coordinates').each do |path|
        data = []
        path.inner_html.gsub(/\r/,'').gsub(/\n/,' ').split(" ").each do |coord|
          coord.strip!
          next if coord.empty?
          lng,lat,alt = coord.split(",")
          # puts "#{lat}, #{lng}, #{alt}"
          data << [lat.to_f,lng.to_f]

          coord = coord + ' '
          coords += coord
        end

        encoder = GMapPolylineEncoder.new()
        result = encoder.encode(data)

        seg_len = calculate_path_length(data)/1000
        len += seg_len
        
        GMapTrack.new(:track_id => id, :points => result[:points], :coords => coords, :length => seg_len, :levels => result[:levels], :num_levels => result[:numLevels], :zoom => result[:zoomFactor], :sequence => i, :name => sub_name).save!
      end
    end

    self.length = len
    self.length_source = LENGTH_SOURCE_CALC
    self.length_adjust_percent = 5
    self.save!
  end

  def create_chart
    # Simplest case, we just get ele from first track segment
    samples = 100
    points = self.g_map_tracks.first.points
    ele = get_ele(points, samples)

    data = "" 
    max = ele['results'].first['elevation'] 
    min = ele['results'].first['elevation']
    ele['results'].each do |e|
      data += e['elevation'].to_s
      data += ","

      if e['elevation'] < min
        min = e['elevation']
      end
      if e['elevation'] > max
        max = e['elevation']
      end
    end
    data = data.chop
    chart = "<img src=\"http://chart.apis.google.com/chart?cht=lc&amp;chs=582x150&amp;chds=#{min},#{max}&amp;chd=t:#{data}&amp;chco=229944&amp;chm=B,9ed472,0,0,0&amp;chxt=x,x,y,y&amp;chxl=1:||Dist (km)||3:||Ele (m)|&amp;chxr=0,0,#{self.g_map_tracks.first.length}|2,#{min},#{max}&amp;&amp;chf=c,ls,90,d9f1ff,0.25,CCDFFF,0.25\" alt=\"Chart\">"
  end

  # take polyline, number of samples and return json object
  def get_ele(points, samples)
    domain = "maps.google.com"
    path = "/maps/api/elevation/json"
    resp = Net::HTTP.get_response(domain, "#{path}?path=enc:#{points}&samples=#{samples}&sensor=false")
    data = resp.body
    result = JSON.parse(data)
  end

  # if our kml has no ele data, look up ele and store it
  def process_ele
    # TODO test for has_ele
    GChartTrack.delete(g_chart_tracks)
    if ! has_ele(self)
      data = create_chart
    end
    GChartTrack.new(:track_id => id, :data => data).save
    self.save
  end
    
  # take a track, return elevation data as json object
  def get_ele_custom(order)
    #logger.error YAML::dump(self)
    return if self.g_map_tracks.empty?

    data = Array.new()
    lat_lng = ""

    # TODO 
    # make configurable which segments and in what order
    # 
    #self.g_map_tracks.each do |gmt|
    gmt = self.g_map_tracks.first
    triplets = gmt.coords.split(" ")
    triplets.each do |triplet|
      #logger.error YAML::dump(triplet)
      lng,lat,alt = triplet.split(",")
      #logger.error "lat" 
      #logger.error YAML::dump(lat)
      data << [lat.to_f,lng.to_f]
    end
    logger.error("--- --- concat coords --- ---")
    logger.error lat_lng
    #logger.error(YAML::dump(data))

    encoder = GMapPolylineEncoder.new()
    polyline = encoder.encode(data)
    points = "nra{F{qki`@OJ[HKHGJFb@"
    logger.error YAML::dump(polyline[:points])

    domain = "maps.google.com"
    path = "/maps/api/elevation/json"
    base_url = "http://maps.google.com/maps/api/elevation/json"
    samples = "10"
    #unsafe = URI::REGEXP::UNSAFE
    #url = "#{base_url}?path=enc:#{polyline[:points]}&samples=#{samples}&sensor=#{sensor}"

    resp = Net::HTTP.get_response(domain, "#{path}?path=enc:#{polyline[:points]}&samples=#{samples}&sensor=false")
    data = resp.body
    result = JSON.parse(data)

    #data = "dummy"
    data
    #str = "http://#{domain}#{path}?path=enc:#{points}&samples=#{samples}&sensor=false"
    #str
  end

  # create one polyline from multiple coord strings
  # TODO exclude "spur lines"
  def create_concat_polyline
    
  end

  def fetch_chart
    # if !has_ele(@track.g_map_track)
    data = get_ele(@track)
    GChartTrack.new(:track_id => id, :data => data).save!
  end

  # Track connections in array of [connecting_track_name,connection_id,track_id]
  def get_connections
    connections = []
    track_connections.each do |c|
      connections << [Track.find(c.connect_track_id, :select => "name").name, c.id, c.connect_track_id]
    end
    connections.sort
  end

  def self.get_markers(area_id)
    find(:all, :conditions => ["area_id = ? AND zoom != 0", area_id], :select => 'latitude, longitude, name, id').collect { |t| [t.latitude, t.longitude, t.name, t.id] }
  end

  def self.length_summary(area_ids)
    summary = {}
    area_ids.each do |area_id|
      find(:all, :conditions => ["area_id = ?", area_id], :select => 'condition_id, length').each do |track|
        if track.length > 0 and track.condition_id != nil
          summary[track.condition_id] = summary.has_key?(track.condition_id) ? summary[track.condition_id] + track.adjusted_length : track.adjusted_length
        end
      end
    end
    summary
  end

  def tweet_new
    tweet format_for_twitter("New track #{name} added to #{area.name}, #{area.region.name}.")
  end

  protected

  # Shoe-horn twitter message (some of), and track url
  def format_for_twitter(message)
    url = shorten_url "http://#{URL_BASE}/track/show/#{id}"
    message[0, 140 - 1 + url.length] + ' ' + url
  end

  def overview_is_not_empty
    errors.add_to_base("Overview cannot be empty.") if desc_overview.blank?
  end

  def fix_name
    fix_stupid_quotes!(name)
  end

  def name_is_unique_for_region
    if id.nil?
      existing = Track.find(:all, :conditions => ["name = ? AND area_id in (?)", name, area.region.areas.collect(&:id)], :select => 'name').size
    else
      existing = Track.find(:all, :conditions => ["id != ? AND name = ? AND area_id in (?)", id, name, area.region.areas.collect(&:id)], :select => 'name').size
    end
    errors.add(:name, "must be unique within #{area.region.name}") if existing != 0
  end
end
