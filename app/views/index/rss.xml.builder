xml.instruct! :xml, :version=>"1.0" 
xml.rss(:version=>"2.0"){
  xml.channel{
    xml.title("Tracks: recent reports")
    xml.link("http://www.tracks.org.nz/index/rss")
    xml.description("Recent track reports")
    xml.language('en-us')
    
    for report in @track_reports
      xml.item do
        xml.title(Track.find(:first, :conditions => ["id = ?", report.track_id], :select => 'name').name)
        xml.description(replace_for_view(report.description))
        xml.pubDate(report.date.to_s(:track))
        xml.author(User.find(report.user_id, :select => 'login').login)
        xml.link("http://www.tracks.org.nz/track/show/" + report.track_id.to_s)
        xml.guid("http://www.tracks.org.nz/track/show/" + report.track_id.to_s)
      end
    end
  }
}