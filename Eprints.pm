package EPrints::Plugin::Export::Google_Maps_1;

use EPrints::Plugin::Export;
@ISA = ("EPrints::Plugin::Export");

use strict;

sub new {
	my ( $class, %opts ) = @_;

	my $self = $class->SUPER::new(%opts);

	$self->{name}    = "Google_Maps_1";
	$self->{accept}  = [ 'dataobj/eprint', 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix}  = ".html";
	$self->{mimetype} =
	  "text/html; charset=ISO-8859-1"; #Western European languages character set

	return $self;
}

#Export a single eprint object to Google Maps
#Fetches data and inputs it in Javascript part of API calls to Google Maps.
sub output_dataobj {
	my ( $plugin, $dataobj ) = @_;

	my $location  = $dataobj->get_value("event_location"); #Publisher Location
	my $title     = $dataobj->get_value("title"); #Title
	my $date = $dataobj->get_value("event_dates"); #Date
	my @names_arr = $dataobj->get_value("creators_name"); #Authors
	my @names     = ();

	foreach my $name ( @{ $names_arr[0] } ) {
		push( @names, $name->{given} . " " . $name->{family} );
	}
	
	#Get the author names and concatenate them in a single string
	my $names_str = join( ", ", @names );

=pod
The output is HTML which contains Javascript API calls to Google Maps.
Google Maps is initialized, and the location of the eprints object is geocoded to find a place on the map.
If it is found, a marker will be placed showing data on the object's Title, Authors, Date and the location, otherwise
a message will be shown notifying that the location could not be found.
=cut	
	return qq~<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
<style type="text/css">
  html { height: 100% }
  body { height: 100%; margin: 0; padding: 0 }
  #map_canvas { height: 100% }
</style>
<script type="text/javascript"
    src="http://maps.googleapis.com/maps/api/js?sensor=true">
</script>
<script type="text/javascript">
var map;
  function initialize() {
    var latlng = new google.maps.LatLng(50.90497, -1.40323);
    var myOptions = {
      zoom: 8,
      center: latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    map = new google.maps.Map(document.getElementById("map_canvas"),
        myOptions);
	
	codeAddress("$location");
  }

	function codeAddress(address) {
    var  geocoder = new google.maps.Geocoder();
    geocoder.geocode( { 'address': address}, function(results, status) {
      if (status == google.maps.GeocoderStatus.OK) {
        map.setCenter(results[0].geometry.location);
        var marker = new google.maps.Marker({
            map: map,
            position: results[0].geometry.location
        });
	var infoWindow = new google.maps.InfoWindow({content: "$location <br><br> $title <br><br> $names_str"});
	google.maps.event.addListener(marker, 'click', function() {
  infoWindow.open(map,marker);
});
      } else {
        alert("There is no available geolocation data for the document." + status);
      }
    });
  }

</script>
</head>
<body onload="initialize()">
  <div id="map_canvas" style="width:100%; height:100%"></div>
</body>
</html>~

}

#Same functionality as output_dataobj but places multiple markers on Google Maps for a list of results in the eprints search system.
#Uses a specific data structure to hold eprint objects per location.
sub output_list {
	my ( $plugin, %opts ) = @_;
	my @locations    = ();
	my @titles       = ();
	my $numOfObjects = 0;
	my $numOfLocDocs = 0;
	my %docs         = ()
	  ; # Hash where keys are publisher locations and values are (references to arrays of) documents published in that location
	  # Useful to have the documents stored per location for an easier and clearer processing and having more than one document data per marker on the map.
	foreach my $dataobj ( $opts{list}->get_records ) {
		my @names_arr = $dataobj->get_value("creators_name");
		my @names     = ();
		foreach my $name ( @{ $names_arr[0] } ) {
			push( @names, $name->{given} . " " . $name->{family} );
		}
		my $names_str = join( ", ", @names ); # As in output_dataobj
		
		#Hash that represents a single document. The data on the location, title, author names and date are stored.
		my %doc = ();
		$doc{"location"} = $dataobj->get_value("event_location");
		$doc{"names"}    = $names_str;
		$doc{"title"}    = $dataobj->get_value("title");
		$doc{"date"} = $dataobj->get_value("event_dates");
		
	
		if(length $doc{"location"} > 0){ #Checks whether a document's entry for location is empty or not. If it isn't, it's added to the hash.
			if ( !exists $docs{ $dataobj->get_value("event_location") } ) {
			$docs{ $dataobj->get_value("event_location") } = []
			  ; #If an entry (reference to array) for a specific location doesn't exist, create it.
		}
			$numOfLocDocs = $numOfLocDocs + 1; # Number of documents with location data.
				push( @{ $docs{ $dataobj->get_value("event_location") } }, \%doc )
		  ;     #Add a reference to a document according to its location.
		
		}
		$numOfObjects = $numOfObjects + 1; #Total number of documents in the search.
	}

	#The HTML output is split to allow for easier processing.
	my $output1 = <<"###";
	<!DOCTYPE html>
	
			<html>
			<head>
			<meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
			<style type="text/css">
			  html { height: 100% }
			  body { height: 100%; margin: 0; padding: 0 }
			  #map_canvas { height: 100% }
			  #search_results  {
						position:absolute;
						top:0;
						right:100px;
						width:200px;
					}
			</style>
			<script type="text/javascript"
			    src="http://maps.googleapis.com/maps/api/js?sensor=true">
			</script>
			<script type="text/javascript">
			var map;
			  function initialize() {
			    var latlng = new google.maps.LatLng(0, 0);
			    var myOptions = {
			      zoom: 2,
			      center: latlng,
			      mapTypeId: google.maps.MapTypeId.ROADMAP
			    };
			    map = new google.maps.Map(document.getElementById("map_canvas"),
				myOptions);
				
				
###

	my $index;
	my $codeAddressCall = '';
	my $output2         = '';
	my $count = 0;
 	my $numOfMarkers = keys(%docs); #Number of markers on the map (number of locations)

	#Generates the necessary function calls for the Javascript part.
	foreach my $location ( keys %docs ) {
		$index           = 0;
		$codeAddressCall = qq~codeAddress( "$location" , "Location: $location<br><br>~;
		foreach my $ref_doc ( @{ $docs{$location} } ) { #Goes through the array of documents for a specific location and fetches the references to the documents
			if ( $index > 0 ) {
				$codeAddressCall .=
				  '<br><br>=====================================<br><br>'; #Separator for multiple documents in one marker.
			}
			$codeAddressCall .=
			  qq~Title: $ref_doc->{"title"}<br><br>Authors: $ref_doc->{"names"}<br><br>Date: $ref_doc->{"date"}~;
			$index = $index + 1;
		}
		$codeAddressCall .= qq~");~;
		$output2 .= $codeAddressCall . <br> . <br>; #Function calls are appended to a string that will be joined with the other 2 HTML parts.
		$count = $count + 1;
	}

	my $output3 = <<"###";
}

function codeAddress(address, info) {
	var geocoder = new google . maps . Geocoder();
	  geocoder . geocode(
		{ 'address' : address },
		function( results, status ) {
			if ( status == google . maps . GeocoderStatus . OK )
			{
				var marker =
				    new google 
				  . maps
				  . Marker(
					{ map : map, position : results [0] . geometry . location }
				  );
				var infoWindow =
				    new google 
				  . maps
				  . InfoWindow(
					{ content : info} );
				google . maps . event . addListener( marker, 'click',
					function() {
						infoWindow . open( map, marker );
					}
				);
			}
		}
	  );
  }

  </script>  </head>
			<body onload="initialize()">
			  <div id="map_canvas" style="width:100%; height:100%"> </div> 
			  <div id="search_results"> Out of $numOfObjects documents in the search results $numOfLocDocs contained location data - $numOfMarkers markers. </div>
			  </body> 
			  </html>
###

	#Combines the split output parts for the final output.
	my $output = $output1 . $output2 . $output3;

	if ( defined $opts{fh} ) {
		print { $opts{fh} } $output;
		return;
	}

	return $output;

}

1;
