module TrackHelper

  def get_paths(track, path_type)
    return if track.g_map_tracks.empty?

    # monkey the overview so it plays nicely with javascript
    overview = replace_for_view(h(track.desc_overview)).gsub(/"/,'\"').gsub(/[\r\n\f]+/,' ')

    path = "prepareTrack();"
    track.g_map_tracks.each do |gmt|
      path += "trackData.push({" \
      "name: \"#{gmt.name.nil? ? track.name : gmt.name}\"," \
      "page: '/track/show/#{track.id}'," \
      "grade: '#{track.track_grade.name}'," \
      "length: '#{distance(track.adjusted_length)}'," \
      "conditions: '#{track.condition.name}'," \
      "description: \"#{overview}\"," \
      "segmentType: '#{path_type}'," \
      "points: \"#{gmt.points}\"," \
      "levels: \"#{gmt.levels}\"," \
      "zoomFactor: #{gmt.zoom}," \
      "numLevels: #{gmt.num_levels}" \
      "});"
    end
    path + "processTrack();\n"
  end

  # If any of the of the coords triples have a non-zero altitude, return true
  def has_ele(track)
    flag = false
    return if track.g_map_tracks.empty?
    track.g_map_tracks.each do |gmt| 
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


end
