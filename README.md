# Eprints export plugin for publisher / event location data on Google Maps


Requirements
-
* Soton Eprints package for Perl.



Overview
-


Basic data is extracted from eprints objects such as a title, author names and date, and a marker is placed in Google Maps on the location of the publisher / event.

The ECS eprints database didn't to seem to contain actual geolocation data in the form of latitude and longitude for any object in the database, so I opted for Publisher / Event Location data instead.

Single document and multiple document exports are handled differently, explained in the following section.



Technical aspects:


The output of the plugin is in HTML which contains Javascript code for the Google Maps API calls. In the Javascript part, the Google Maps interface is initialized, then locations are geocoded and placed

on the map as markers. The markers pop up info windows when clicked which display information on the eprints documents.



In output_dataobj (the function for the export of a single eprints object) the information is fetched and stored in scalars which are then passed as arguments in the Javascript calls to Google maps functions.

A marker is shown on the map, unless the location is not found which would display an appropriate error message.



In output_list (for the export of a list of objects) the following data structure had to be used to store the objects per location:

Several objects might have the same location, therefore the documents had to be stored according to the location and only one marker would be placed on the map per location.

For that reason, a hash was used with locations as keys and references to arrays as values. Each element in the array referred to holds a reference to an actual document.

A document is represented by a hash holding the info on the document.

Only objects with location data are added to that data structure. The interface informs the user of how many documents from the search result contain location data as well.

When clicking on a location which has more than 1 document, the info will be shown in the same window, separated by a separator string.



Notice: Google Maps has a query limit (of about 11 geocode calls) in a given timeframe, therefore after that limit markers will start showing in the map gradually with a short delay.



Screenshot link: http://farm7.static.flickr.com/6238/6305744443_93051980d6_b.jpg

