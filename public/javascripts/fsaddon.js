// Adds a full screen toggle control to a Google Map
// Adapted from original source: http://www.barattalo.it/2009/11/13/full-screen-gcontrol-for-google-maps/

var mapFullScreen = false;  // Current map display mode

function FullScreenControl()
{
}

FullScreenControl.prototype = new GControl();

FullScreenControl.prototype.initialize = function(map)
{
   var originalWidth;
   var originalHeight;

   var iconContainer = document.createElement('div');      // set up initial full screen toggle icon
   var img = document.createElement('img');
   iconContainer.appendChild(img);
   img.src = '/images/icon-enlarge.png';
   img.title = 'Full screen';
  
   GEvent.addDomListener(img, 'click', function()          // Listen for click on the full screen toggle icon
   {
      var mapNode = this.parentNode.parentNode;
      var winW = 0, winH = 0;                              // Get current window size, depending on browser
      if (parseInt(navigator.appVersion) > 3)
      {
         if (navigator.appName=="Netscape")
         {
            winW = window.innerWidth;
            winH = window.innerHeight;
         }
         if (navigator.appName.indexOf("Microsoft") != -1)
         {
            winW = document.body.offsetWidth;
            winH = document.body.offsetHeight;
         }
      }
      map.savePosition();  // save the current map view, for restoration after changing the map's size
      if(mapFullScreen)
      {  // Revert to normal map display
				 if (document.getElementById("currTrackSelection") != null) {
           document.getElementById("currTrackSelection").style.position = "relative";  // Re-position track mouseover information display
				 }
				 if (document.getElementById("labelContainer") != null) {
           document.getElementById("labelContainer").style.position = "absolute";
				 }
         $(mapNode.id).style.width = originalWidth + "px";                           // Restore the map to its original size and position
         $(mapNode.id).style.height = originalHeight + "px";
         $(mapNode.id).style.position = "relative";
         document.getElementsByTagName("body").item(0).style.overflow = "auto";      // Restore vertical scroll bar
         map.checkResize();                                                          // Force the map to resize to new container
         this.src = '/images/icon-enlarge.png';                                      // Change the full screen toggle icon
         img.title = 'Full screen';
         mapFullScreen = false;                                                      // Note the current map display mode
      }
      else
      {  // Switch to full screen map display
         originalWidth = parseInt(document.getElementById("map").offsetWidth) - 2;   // Note the original map size, so it can be restored later
         originalHeight = parseInt(document.getElementById("map").offsetHeight) - 2; // Though need to subtract the border width
				 if (document.getElementById("currTrackSelection") != null) {
           document.getElementById("currTrackSelection").style.position = "relative";  // Re-position track mouseover information display
				 }
				 if (document.getElementById("labelContainer") != null) {
           document.getElementById("labelContainer").style.position = "absolute";
				 }
         $(mapNode.id).style.position = "absolute";                                  // Switch to full screen map
         $(mapNode.id).style.width = "100%";
         $(mapNode.id).style.height = "100%";
         document.getElementsByTagName("body").item(0).style.overflow = "hidden";    // Hide vertical scroll bar, to keep map fixed in position
         $(mapNode.id).scrollTo();                                                   // Scroll to the saved view position
         map.checkResize();                                                          // Force the map to resize to new container
         this.src = '/images/icon-reduce.png';                                       // Change the full screen toggle icon
         img.title = 'Normal size';
         mapFullScreen = true;                                                       // Note the current map display mode
      }
      map.returnToSavedPosition();                                                   // Restore the map's position after resizing
   });
   map.getContainer().appendChild(iconContainer);
   return iconContainer;
}

FullScreenControl.prototype.getDefaultPosition = function()
{  // Position the resizing control icon
   return new GControlPosition(G_ANCHOR_TOP_LEFT, new GSize(24, 300));               // Icon position is hard coded below Google's zoom control
}
