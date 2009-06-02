// Polyline clicks fails in IE8 - known defect: http://code.google.com/p/gmaps-api-issues/issues/detail?id=1055&q=apitype:Javascript&colspec=ID%20Type%20Status%20Introduced%20Fixed%20Summary%20Internal%20Stars
// Polylines don't display in Earth map type.

var map;                               // Reference to the map object
var mapContainer;                      // Name of the DIV that will contain the map
var tracks = new Array();              // 2D list of tracks.  Allows for possibility that first dimension represents tracks and second dimension is segments of each track
var trackData = new Array();           // Detailed data for each track, including encoded polyline
var numSegments = 0;                   // Number of segments in the current track
var localSegments = new Array();       // Collate the segments of the current track
var currTrackSegment = 0;              // Segment counter
var currWeight = 1;                    // Default polyline weight (if not specified in trackData)
var currOpacity = 1;                   // Default polyline opacity (if not specified in trackData)
var currColor = "#00ff00";             // Default polyline color (if not specified in trackData)

function onLoad()
{  // Entry point from HTML
   if (GBrowserIsCompatible())
   {
      setup();
      for (var i = 0; i <= tracks.length - 1; i++)  // Each track
      {
         for (var j = 0; j <= tracks[i].length - 1; j++)    // Each segment of the current track
         {
            defineLine();
            drawLine(i, j)
         }
      }
   }
   else
   {
      alert("Sorry, the Google Maps API is not compatible with this browser");
   }
}

function setup()
{  // Setup the map
   mapContainer = document.getElementById("map");
   map = new GMap2(mapContainer);
   var uiOptions = map.getDefaultUI();
   map.setUI(uiOptions);   // new style controls, see http://googlegeodevelopers.blogspot.com/2009/02/posted-by-jez-fletcher-maps-api-team.html
   map.setCenter(maplatlng, mapZoom);
   map.addMapType(G_SATELLITE_3D_MAP);
   G_SATELLITE_3D_MAP.getName = function() {return "Earth 3D"}  // Rename Google Earth map type button
   map.setMapType(mapType);
   // *** GOverviewMapControl currently broken for minimized ***
   // ovMap = new GOverviewMapControl(new GSize(100,80));
   // map.addControl(ovMap);
   // ovMap.hide(true);
}

function defineLine()
{  // Define the appearance of each track type
   switch(trackData[currTrackSegment].segmentType)
   {
      case 'Main':
         currWeight = 4;
         currOpacity = 0.8;
         currColor = "#ff0000";
         break;    
      case 'Adjacent':
         currWeight = 2;
         currOpacity = 0.8;
         currColor = "#ffa000";
         break;    
      default:
         currWeight = 2;
         currOpacity = 0.8;
         currColor = "#ffff00";
   }
   return currWeight, currOpacity, currColor;
}

function drawLine(i, j)
{  // Draw each track
   var polyline = handleLineInteraction(tracks[i][j]);
   tracks[i][j].weight = currWeight;
   tracks[i][j].opacity = currOpacity;
   tracks[i][j].color = currColor;
   map.addOverlay(tracks[i][j]);
   currTrackSegment += 1;
}

function prepareTrack()
{  // Prepare for a new track to be added
   localSegments = [];
   numSegments = trackData.length;  // Number of track segments before adding these ones in this file
}

function processTrack()
{  // Process the most recently added track
   for (var s = numSegments; s <= trackData.length - 1; s++)
   {
      localSegments.push (new GPolyline.fromEncoded(trackData[s]));
   }
   tracks.push(localSegments);
}

function handleLineInteraction(line)
{  // Allow the user to interact with the polyline
   var c = currColor;  // note the characteristics of the current polyline, so that they can be restored
   var w = currWeight;
   var o = currOpacity;
   var n = trackData[currTrackSegment].name;
   var p = trackData[currTrackSegment].page;
   var d = trackData[currTrackSegment].description;
   var l = trackData[currTrackSegment].length;
   var g = trackData[currTrackSegment].grade;
   var t = trackData[currTrackSegment].conditions;

   var message = '<a href="' + p + '">' + n + ':</a>' + '<br/><div class="infoDescription">' + d + '</div>';
   var summary = 
         '<div class="summary">'
       + '&nbsp;Track: ' + n + '&nbsp;' + '<br />'
       + '&nbsp;Grade: ' + g + '&nbsp;' + '<br />'
       + '&nbsp;Length: ' + l + '&nbsp;' + '<br />'
       + '&nbsp;Type: ' + t + '&nbsp;</div>'
       ; // uses &nbsp; to provide padding around the text  (using css would be better)

   GEvent.addListener
   (  // Create an infowindow that appears when the current track is clicked
      line, "click", function(latlng)
      {
         i = map.openInfoWindowHtml(latlng, message);  // Open infoWindow at click point
         line.setStrokeStyle({color:"#ffff00", weight: 4, opacity: 1});
      }
   );
   GEvent.addListener
   (  // change polyline when mouse points at it
      line, "mouseover", function()
      {  
         line.setStrokeStyle({color:"#ffff00", weight: 4, opacity: 1});
         document.getElementById("currTrackSelection").innerHTML = summary;
      }
   );
   GEvent.addListener
   (  // restore polyline when mouse moves away
      line, "mouseout", function()
      {  
         line.setStrokeStyle({color:c, weight: w, opacity: o});
         document.getElementById("currTrackSelection").innerHTML = '';
      }
   );
   return line;
}

function resetMap()
{  // Restore the map to the default settings.
   map.closeInfoWindow();
   map.setCenter(maplatlng, mapZoom, mapType);
}
