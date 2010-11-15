class Track < ActiveRecord::Base

  require 'gmap_polyline_encoder'
  require 'hpricot'
  include TwitterHelper
  include TextHelper
  include Coords

  require 'rubygems'
  require 'json'
  require 'net/http'
  require 'htmlentities'

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
		debugger
		logger.error "== gmap tracks before =="
		logger.error(g_map_tracks.length)

    GMapTrack.delete_all(["track_id = ?", id])
		#self.g_map_tracks.delete

		logger.error "== gmap tracks after =="
		logger.error(g_map_tracks.length)

		#GMapTrack.delete(:conditions => track_id = self.id)
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

  def get_chart_data
    total_samples = 70
    total_length = 0
    g_map_tracks.each do |t|
      total_length += t.length
    end

		sample_coords = get_samples(self.g_map_tracks.first.coords, total_length, total_samples)

    # lat, lngs are in part of array
    ele = get_ele_locations(sample_coords[0])
    
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

    # Chart components
    max += 20 # pad graph
    min -= 20
    chart_url = "http://chart.apis.google.com/chart?"
    chart_type = "cht=lc&amp;"
    chart_size = "chs=582x150&amp;"
    data_scale = "chds=#{min},#{max}&amp;"
    data_series = "chd=t:#{data}&amp;"
    series_color = "chco=229944&amp;"
    line_fill = "chm=B,9ed472,0,0,0&amp;"
    visible_axis = "chxt=x,x,y,y&amp;"
    axis_lables = "chxl=1:||Dist (km)||3:||Ele (m)|&amp;"
    axis_range = "chxr=0,0,#{self.g_map_tracks.first.length}|2,#{min},#{max}&amp;"
    bg_fill = "chf=c,ls,90,d9f1ff,0.25,CCDFFF,0.25"

    chart = "<img src=\"" + chart_url + chart_type + chart_size + data_scale + data_series + series_color + line_fill + visible_axis + \
    axis_lables + axis_range + bg_fill + "\" alt=\"Chart\">"
  end

  # Generate multi segment chart
  def get_chart_data_multi
		#self.reload
    total_samples = 70
    total_length = 0
    self.g_map_tracks.each do |t|
      total_length += t.length
    end

    # joins coords of segments from g_map_track table into a big string
    track_coords = join_coords

    # sample_coords now has cum_dist attached ['lat1,lng1|lat2,lng2'][cum_dist1|cum_dist2]
    sample_coords = get_samples(track_coords, total_length, total_samples)

    # Get elevation data from lat,lngs
    ele = get_ele_locations(sample_coords[0])

    # Create x,y strings for graph 
    # Get min/max elevation for graph height
    data_y = "" 
    max = ele['results'].first['elevation'] 
    min = ele['results'].first['elevation']
    ele['results'].each do |e|
      data_y += e['elevation'].to_s
      data_y += ","
      if e['elevation'] < min
        min = e['elevation']
      end
      if e['elevation'] > max
        max = e['elevation']
      end
    end
    data_y = data_y.chop

    # get accum_dist of middle and end points of each segment
    segs = get_dists_for_segments(total_length, sample_coords[1].split(',').last) # Use length as calculated from segments and from whole line
    # get index (nth) of middle and end points of each segment
    segs = get_indexes_for_segments(segs, sample_coords[1]) 

    # Build segment markers
    seg_markers = ''
    segs.each do |segment|
      s = segment.pop
      seg_markers += '|v,229944,0,' + s['end_index'].to_s + ',1'
      seg_markers += '|A' + abbreviate_track_name(s['name']) + ',000000,0,' + s['mid_index'].to_s  + ',8'
    end

    # Construct chart url
    max += 200 # pad top of graph so theres room of labels
    min -= 20 # pad bottom
    chart_url         = "http://chart.apis.google.com/chart?"
    chart_type        = "cht=lc&amp;"
    chart_size        = "chs=582x200&amp;"
    data_scale        = "chds=#{min},#{max}&amp;"
    data              = "chd=t:#{data_y}&amp;"
    series_color      = "chco=229944&amp;"
    line_fill         = "chm=B,9ed472,0,0,0#{seg_markers}&amp;"
    visible_axis      = "chxt=x,x,y,y&amp;"
    axis_labels       = "chxl=1:||Dist (km)||3:||Ele (m)|||&amp;"
    axis_range        = "chxr=0,0,#{self.length}|2,#{min},#{max}&amp;"
    bg_fill 					= "chf=c,ls,90,d9f1ff,0.25,CCDFFF,0.25"

    chart = "<img src=\"" + chart_url + chart_type + chart_size + data_scale + data + series_color + line_fill + visible_axis + axis_labels + axis_range + bg_fill + "\" alt=\"Chart\">"
  end
  
  # Only use first and last letters for second and thrid words in name
  # eg. Big ring boulevard -> Big rg bd
  def abbreviate_track_name(name)
    decoder = HTMLEntities.new
    name = decoder.decode(name) # convert &apos; to ' etc
    name_split = name.split(' ')
    name_abrv = ''
    name_split.each_with_index do |word,index|
      if index == 0
        name_abrv = word
      end 
      if index >= 1
        word = word.slice(0, 1) + word.slice(word.length - 1, word.length)
        name_abrv += ' ' + word
      end
    end
    name_abrv
  end

  # get accum_dist of middle and end points of each segment
  def get_dists_for_segments(tot_from_segs, tot_from_line)
    segs = Hash.new
    start_dist = 0
    self.g_map_tracks.each_with_index do |t,index|
      ratio = t.length / tot_from_segs.to_f
      rel_length = ratio * tot_from_line.to_f
      segs[index] = {
        'name' => t.name, 
        'mid_dist' => start_dist + (rel_length / 2),
        'mid_index' => 0, 
        'end_dist' => start_dist + rel_length,
        'end_index' => 0 
      }
			start_dist += rel_length
    end
    segs
  end

	# TODO shouldnt I just work out index based on number of samples and propotion of track a segment represents?
	# eg.  4km out of 20km  and 10 samples would be 2nd point.
	# meh
  # Get indexes of middle and end points of each segment
  def get_indexes_for_segments(segs, points)
    seg_index = 0
    point_index_max = 0
    points.split(',').each_with_index do |point, point_index|
      point_index_max = point_index
      # Stop if we have gone off the end
      break if segs[seg_index] == nil
      # If we are past the mid point of our segment, record index of that point
      if point.to_f >= segs[seg_index]['mid_dist'] and segs[seg_index]['mid_index'] == 0
        segs[seg_index]['mid_index'] = point_index
      end
      # If we are past the end point of our segment, record index of that point
      if point.to_f >= segs[seg_index]['end_dist'] and segs[seg_index]['end_index'] == 0
        segs[seg_index]['end_index'] = point_index
        seg_index +=1
      end
    end
    # make sure that the last end_index always matches the index of the last point in the segment
    if segs[seg_index] == nil
      segs[seg_index-1]['end_index'] = point_index_max
    else
      segs[seg_index]['end_index'] = point_index_max
    end
    segs
  end

  # take polyline, number of samples. return elevations evenly spaced samples
  def get_ele(points, samples)
    domain = "maps.google.com"
    path = "/maps/api/elevation/json"
    resp = Net::HTTP.get_response(domain, "#{path}?path=enc:#{points}&samples=#{samples}&sensor=false")
    data = resp.body
    result = JSON.parse(data)
  end

  # take points, return elevations for each point
  def get_ele_locations(points)
    domain = "maps.google.com"
    path = "/maps/api/elevation/json"
    resp = Net::HTTP.get_response(domain, "#{path}?locations=#{points}&sensor=false")
    data = resp.body
    result = JSON.parse(data)
  end

  # Take gmap_track and join together the coord strings for each segment
  def join_coords
    coords_list = ""
    self.g_map_tracks.each do |t|
      coords_list << t.coords
    end
    coords_list
  end

  # Some encoded polylines are longer than uri limit (approx 2k chars)
  # so we now only include points we want elevations for in our requests
  # take a line, find evenly spaced points
  # return samples (lat, lng, cum_dist)
  def get_samples(line, length, samples)
    sample_dist = 1000 * (length / samples)
    sample_line = ""
    sample_cum_dist = ""
    # on first dist calc prev and current points will be the same
    prev_lat,prev_lng = line.first.split(",")
    dist = 0
    cum_dist = 0
    #total = line.split(' ').count - 1
    line.split(' ').each_with_index do |point, i|
      lat,lng,alt = point.split(",")
      if i == 0
        dist = 0
      else
        dist += calculate_path_length([[prev_lat.to_f, prev_lng.to_f], [lat.to_f, lng.to_f]])
      end 
      cum_dist += dist

      # Take a sample at everytime we go over our sample distance (and sample 1st and last point)
      if dist >= sample_dist or i == 0 #or i == total
        # only do 6dp accuracy, otherwise urls too long
        lat = sprintf "%.6f", lat
        lng = sprintf "%.6f", lng
        # sample lat,lng
        sample_line << lng + ',' + lat + '|'

        # sample dist and convert from 1234.5678 to 1.23
        cum_dist_ks = cum_dist / 10000
        cum_dist_1dp = sprintf "%.1f", cum_dist_ks
        sample_cum_dist << cum_dist_1dp.to_s + ','
        dist = 0
      end
      prev_lat = lat
      prev_lng = lng
    end
    
    sample_line = sample_line.chop()
    sample_cum_dist = sample_cum_dist.chop()
    result = [sample_line, sample_cum_dist]
  end

  # If any of the of the coords triples have a non-zero altitude, return true
  def has_ele
    flag = false
    return if self.g_map_tracks.empty?
    self.g_map_tracks.each do |gmt|
      coord = gmt.coords.split(" ")
      coord.each do |c|
        lng,lat,alt = c.split(",")
        if alt.to_f != 0
          flag = true
          break
        end
      end
    end
    flag
  end

  # if our kml has no ele data, look up ele and store it
  def process_ele
    GChartTrack.delete(g_chart_tracks)
		# TODO use elevation from kml files
    #if ! has_ele
    #  data = get_chart_data(type_of_chart)
    #end
		self.reload
    if self.type_of_chart == 'multiple'
      data = get_chart_data_multi
    else
      data = get_chart_data
    end
      
    # make create method for chart that does all the g_chart specific bits
    GChartTrack.new(:track_id => id, :data => data).save
    self.save
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
    find(:all, :conditions => ["area_id = ? AND zoom != 0", area_id], :select => 'latitude, longitude, name, id, track_grade_id').collect { |t| [t.latitude, t.longitude, t.name, t.id, t.track_grade_id] }
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
