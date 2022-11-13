<?php

/****************************************************************************

   LEFT 4 DEAD (2) PLAYER STATISTICS ©2019-2020 PRIMEAS.DE
   BASED ON THE PLUGIN FROM MUUKIS MODIFIED BY FOXHOUND FOR SOURCEMOD

 - https://forums.alliedmods.net/showthread.php?p=2678290#post2678290
 - https://www.primeas.de/

****************************************************************************/

//ini_set('display_errors',1);
//error_reporting(E_ALL);
error_reporting(0);

?>

<script>
	$(document).ready(function () {
		$(".arrow-right").bind("click", function (event) {
			event.preventDefault();
			$(".vid-list-container").stop().animate({scrollLeft: "+=336"
			}, 750);
		});
		$(".arrow-left").bind("click", function (event) {
			event.preventDefault();
			$(".vid-list-container").stop().animate({
				scrollLeft: "-=336"
			}, 750);
   		 });
	});
</script>

<div class="card rounded-0">
	<div class="card-body">
	<h5 class="card-title"><?php echo $youtube_title; ?></h5>

<?php
echo "<div class=\"vid-container\"><iframe id=\"vid_frame\" src=\"https://www.youtube.com/embed/$yt_movie1_embed\" frameborder=\"0\" width=\"560\" height=\"315\"></iframe></div>";
echo "<div class=\"vid-list-container\"><div class=\"vid-list\">";
	if ($yt_movie1_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie1_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie1_embed/0.jpg\" alt=\"\"></div><div>$yt_movie1_title</div></div>"; }
	if ($yt_movie2_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie2_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie2_embed/0.jpg\" alt=\"\"></div><div>$yt_movie2_title</div></div>"; }
	if ($yt_movie3_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie3_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie3_embed/0.jpg\" alt=\"\"></div><div>$yt_movie3_title</div></div>"; }
	if ($yt_movie4_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie4_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie4_embed/0.jpg\" alt=\"\"></div><div>$yt_movie4_title</div></div>"; }
	if ($yt_movie5_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie5_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie5_embed/0.jpg\" alt=\"\"></div><div>$yt_movie5_title</div></div>"; }
	if ($yt_movie6_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie6_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie6_embed/0.jpg\" alt=\"\"></div><div>$yt_movie6_title</div></div>"; }
	if ($yt_movie7_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie7_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie7_embed/0.jpg\" alt=\"\"></div><div>$yt_movie7_title</div></div>"; }
	if ($yt_movie8_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie8_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie8_embed/0.jpg\" alt=\"\"></div><div>$yt_movie8_title</div></div>"; }
	if ($yt_movie9_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie9_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie9_embed/0.jpg\" alt=\"\"></div><div>$yt_movie9_title</div></div>"; }
	if ($yt_movie10_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie10_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie10_embed/0.jpg\" alt=\"\"></div><div>$yt_movie10_title</div></div>"; }
	if ($yt_movie11_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie11_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie11_embed/0.jpg\" alt=\"\"></div><div>$yt_movie11_title</div></div>"; }
	if ($yt_movie12_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie12_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie12_embed/0.jpg\" alt=\"\"></div><div>$yt_movie12_title</div></div>"; }
	if ($yt_movie13_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie13_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie13_embed/0.jpg\" alt=\"\"></div><div>$yt_movie13_title</div></div>"; }
	if ($yt_movie14_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie14_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie14_embed/0.jpg\" alt=\"\"></div><div>$yt_movie14_title</div></div>"; }
	if ($yt_movie15_embed == "") { }
	else { echo "<div class=\"vid-item box-animated\" onClick=\"document.getElementById('vid_frame').src='https://www.youtube.com/embed/$yt_movie15_embed?&autoplay=1'\" style=\"cursor:pointer\"><div class=\"thumb\"><img src=\"https://img.youtube.com/vi/$yt_movie15_embed/0.jpg\" alt=\"\"></div><div>$yt_movie15_title</div></div>"; }
?>

			</div>
		</div>
		<div class="arrows">
			<div class="btn rounded-0 btn-main arrow-left"><i class="fa fa-chevron-left fa-lg"></i></div>
			<div class="btn rounded-0 btn-main arrow-right"><i class="fa fa-chevron-right fa-lg"></i></div>
		</div>
	</div>
</div>
<br /><br />