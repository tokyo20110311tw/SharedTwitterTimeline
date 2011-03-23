/* Shared-Twitter-Timeline */

// source uri
var target_uri = "./perl/get.pl";

//-------------------------------

var callback = function(json) {
	$('#result').empty();
	$.each(json, function(i, item) {
		var xtext = item.text.replace(/(http:\/\/[\x21-\x7e]+)/gi, "<a href='$1'>$1</a>");
		var content = item.time + " / " + item.user + "<br />" + xtext;
		$('#result').append($("<li>").html(content));
	});
};

var xget = function() {
	$.ajax({
		url : target_uri,
		dataType :"jsonp",
		jsonp : "callback",
		success : function(data){}
	});
};

$(function(){
	xget();
	setInterval(xget,3000);
});
