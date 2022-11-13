<?php

/****************************************************************************

   LEFT 4 DEAD (2) PLAYER STATISTICS ©2019-2020 PRIMEAS.DE
   BASED ON THE PLUGIN FROM MUUKIS MODIFIED BY FOXHOUND FOR SOURCEMOD

 - https://forums.alliedmods.net/showthread.php?p=2678290#post2678290
 - https://www.primeas.de/

****************************************************************************/

require_once("mysql.php");
include("_config.php");
include("class_template.php");
$game_version = 2;

function php4_scandir($dir, $listDirectories=false, $skipDots=true)
{
	$dirArray = array();
	if ($handle = opendir($dir))
	{
		while (false !== ($file = readdir($handle)))
		{
			if ((($file == "." || $file == ".." || $file ==":") && !$skipDots) || ($file != "." && $file != ".." || $file !=":"))
			{
				if (!$listDirectories && is_dir($file)) 
					continue;
				array_push($dirArray, basename($file));
			}
		}
		closedir($handle);
	}
	return $dirArray;
}

function getfriendid($pszAuthID)
{
	$iServer = "0";
	$iAuthID = "0";
	$szAuthID = $pszAuthID;
	$szTmp = strtok($szAuthID, ":");
	while(($szTmp = strtok(":")) !== false)
	{
		$szTmp2 = strtok(":");
		if($szTmp2 !== false)
		{
			$iServer = $szTmp;
			$iAuthID = $szTmp2;
		}
	}
	if($iAuthID == "0")
		return "0";
	$i64friendID = bcmul($iAuthID, "2");
	$i64friendID = bcadd($i64friendID, bcadd("76561197960265728", $iServer));
	return $i64friendID;
}

function formatage($date) {
	$nametable = array(" Seconds", " Minutes", " Hours", " Days", " Weeks", " Months", " Years");
	$agetable = array("60", "60", "24", "7", "4", "12", "10");
	$ndx = 0;
	while ($date > $agetable[$ndx]) {
		$date = $date / $agetable[$ndx];
		$ndx++;
		next($agetable);
	}
	return number_format($date, 2).$nametable[$ndx];
}

function getpopulation($population, $file) {
	$cityarr = array();
	$page = fopen($file, "r");
	while (($data = fgetcsv($page, 1000, ",")) !== FALSE) {
		if ((strstr($data[0], "County") || strstr($data[0], "Combined")) && $cityonly)
			continue;

		$cityarr[$data[1]] = $data[2];
	}
	fclose($page);
	asort($cityarr, SORT_NUMERIC);
	$returncity = "";
	$returncity2 = "";
	foreach ($cityarr as $city => $pop) {
		if ($population > $pop)
			$returncity = $city;
		else {
			$returncity2 = $city;
			break;
		}
	}
	$return = array($returncity,
					$cityarr[$returncity],
					$returncity2,
					$cityarr[$returncity2]);
	return $return;
}

function gettotalpointsraw($row)
{
	$totalpoints = 0;
	if ($GLOBALS['game_version'] != 1)
		$totalpoints = $row['points'] + $row['points_realism'] + $row['points_survivors'] + $row['points_infected'] + $row['points_survival'] + $row['points_scavenge_survivors'] + $row['points_scavenge_infected'] + $row['points_realism_survivors'] + $row['points_realism_infected'] + $row['points_mutations'];
	else
		$totalpoints = $row['points'] + $row['points_survivors'] + $row['points_infected'] + $row['points_survival'];
	return $totalpoints;
}

function gettotalpoints($row)
{
	return number_format(gettotalpointsraw($row));
}

function gettotalplaytimecalc($row)
{
	if ($GLOBALS['game_version'] != 1)
		return $row['playtime'] + $row['playtime_realism'] + $row['playtime_versus'] + $row['playtime_survival'] + $row['playtime_scavenge'] + $row['playtime_realismversus'] + $row['playtime_mutations'];
	else
		return $row['playtime'] + $row['playtime_versus'] + $row['playtime_survival'];
}

function gettotalplaytime($row)
{
	return getplaytime(gettotalplaytimecalc($row));
}

function getplaytime($minutes)
{
	return formatage($minutes * 60) . " (" . number_format($minutes) . " min)";
}

function getppm($__points, $__playtime)
{
	if ($__points != 0 && $__playtime != 0)
		return $__points / $__playtime;
	return 0.0;
}

function getserversettingsvalue($name)
{
	global $mysql_tableprefix;
	$q = "SELECT svalue FROM " . $mysql_tableprefix . "server_settings WHERE sname = '" . mysql_real_escape_string($name) . "'";
	$res = mysql_query($q);
	if ($res && mysql_num_rows($res) == 1 && ($r = mysql_fetch_array($res)))
		return $r['svalue'];
	return "";
}

function setcommontemplatevariables($template)
{
	global $carousel_spieler, $site_welcome_intro,$youtube_title, $yt_movie1_embed,$yt_movie1_title,$yt_movie2_embed,$yt_movie2_title,$yt_movie3_embed,$yt_movie3_title,$yt_movie4_embed,$yt_movie4_title,$yt_movie5_embed,$yt_movie5_title,$yt_movie6_embed,$yt_movie6_title,$yt_movie7_embed,$yt_movie7_title,$yt_movie8_embed,$yt_movie8_title,$yt_movie9_embed,$yt_movie9_title,$yt_movie10_embed,$yt_movie10_title,$yt_movie11_embed,$yt_movie11_title,$yt_movie12_embed,$yt_movie12_title,$yt_movie13_embed,$yt_movie13_title,$yt_movie14_embed,$yt_movie14_title,$yt_movie15_embed,$yt_movie15_title, $carousel_infected_kills, $carousel_headshots,$gameserver, $top3_site, $top3_glow, $site_name, $server1_ip, $server1_port,$server2_ip, $server2_port,$server3_ip, $server3_port,$server4_ip, $server4_port,$server5_ip, $server5_port,$server6_ip, $server6_port,$server7_ip, $server7_port,$server8_ip, $server8_port,$server9_ip, $server9_port,$server10_ip, $server10_port,$server11_ip, $server11_port,$server12_ip, $server12_port,$server13_ip, $server13_port,$server14_ip,$server14_port,$server15_ip, $server15_port, $site_logo, $site_logo_height, $site_logo_width, $youtube, $site_movie, $site_url, $site_style, $site_description, $site_keywords, $site_statsurl, $site_game, $site_steamgroup, $site_welcome, $playercount, $realismlink, $realismversuslink, $mutationslink, $scavengelink, $realismcmblink, $realismversuscmblink, $mutationscmblink, $scavengecmblink, $timedmapslink, $templatefiles;
	$template->set("site_name", $site_name);
	$template->set("site_game", $site_game);
	$template->set("site_url", $site_url);
	$template->set("site_welcome_intro", $site_welcome_intro);
	$template->set("top3_site", $top3_site);
	$template->set("top3_glow", $top3_glow);
	$template->set("yt_movie1_embed", $yt_movie1_embed);
	$template->set("yt_movie1_title", $yt_movie1_title);
	$template->set("yt_movie2_embed", $yt_movie2_embed);
	$template->set("yt_movie2_title", $yt_movie2_title);
	$template->set("yt_movie3_embed", $yt_movie3_embed);
	$template->set("yt_movie3_title", $yt_movie3_title);
	$template->set("yt_movie4_embed", $yt_movie4_embed);
	$template->set("yt_movie4_title", $yt_movie4_title);
	$template->set("yt_movie5_embed", $yt_movie5_embed);
	$template->set("yt_movie5_title", $yt_movie5_title);
	$template->set("yt_movie6_embed", $yt_movie6_embed);
	$template->set("yt_movie6_title", $yt_movie6_title);
	$template->set("yt_movie7_embed", $yt_movie7_embed);
	$template->set("yt_movie7_title", $yt_movie7_title);
	$template->set("yt_movie8_embed", $yt_movie8_embed);
	$template->set("yt_movie8_title", $yt_movie8_title);
	$template->set("yt_movie9_embed", $yt_movie9_embed);
	$template->set("yt_movie9_title", $yt_movie9_title);
	$template->set("yt_movie10_embed", $yt_movie10_embed);
	$template->set("yt_movie10_title", $yt_movie10_title);
	$template->set("yt_movie11_embed", $yt_movie11_embed);
	$template->set("yt_movie11_title", $yt_movie11_title);
	$template->set("yt_movie12_embed", $yt_movie12_embed);
	$template->set("yt_movie12_title", $yt_movie12_title);
	$template->set("yt_movie13_embed", $yt_movie13_embed);
	$template->set("yt_movie13_title", $yt_movie13_title);
	$template->set("yt_movie14_embed", $yt_movie14_embed);
	$template->set("yt_movie14_title", $yt_movie14_title);
	$template->set("yt_movie15_embed", $yt_movie15_embed);
	$template->set("yt_movie15_title", $yt_movie15_title);
	$template->set("gameserver", $gameserver);
	$template->set("server1_ip", $server1_ip);
	$template->set("server1_port", $server1_port);
	$template->set("server2_ip", $server2_ip);
	$template->set("server2_port", $server2_port);
	$template->set("server3_ip", $server3_ip);
	$template->set("server3_port", $server3_port);
	$template->set("server4_ip", $server4_ip);
	$template->set("server4_port", $server4_port);
	$template->set("server5_ip", $server5_ip);
	$template->set("server5_port", $server5_port);
	$template->set("server6_ip", $server6_ip);
	$template->set("server6_port", $server6_port);
	$template->set("server7_ip", $server7_ip);
	$template->set("server7_port", $server7_port);
	$template->set("server8_ip", $server8_ip);
	$template->set("server8_port", $server8_port);
	$template->set("server9_ip", $server9_ip);
	$template->set("server9_port", $server9_port);
	$template->set("server10_ip", $server10_ip);
	$template->set("server10_port", $server10_port);
	$template->set("server11_ip", $server11_ip);
	$template->set("server11_port", $server11_port);
	$template->set("server12_ip", $server12_ip);
	$template->set("server12_port", $server12_port);
	$template->set("server13_ip", $server13_ip);
	$template->set("server13_port", $server13_port);
	$template->set("server14_ip", $server14_ip);
	$template->set("server14_port", $server14_port);
	$template->set("server15_ip", $server15_ip);
	$template->set("server15_port", $server15_port);
	$template->set("site_logo", $site_logo);
	$template->set("site_logo_height", $site_logo_height);
	$template->set("site_logo_width", $site_logo_width);
	$template->set("youtube", $youtube);
	$template->set("youtube_title", $youtube_title);
	$template->set("site_style", $site_style);
	$template->set("site_movie", $site_movie);
	$template->set("site_description", $site_description);
	$template->set("site_keywords", $site_keywords);
	$template->set("site_statsurl", $site_statsurl);
	$template->set("site_steamgroup", $site_steamgroup);
	$template->set("site_welcome", $site_welcome);
	$template->set("carousel_spieler", $carousel_spieler);
	$template->set("carousel_infected_kills", $carousel_infected_kills);
	$template->set("carousel_headshots", $carousel_headshots);
	$template->set("realismlink", $realismlink);
	$template->set("realismversuslink", $realismversuslink);
	$template->set("mutationslink", $mutationslink);
	$template->set("scavengelink", $scavengelink);
	$template->set("realismcmblink", $realismcmblink);
	$template->set("realismversuscmblink", $realismversuscmblink);
	$template->set("mutationscmblink", $mutationscmblink);
	$template->set("scavengecmblink", $scavengecmblink);
	$template->set("timedmapslink", $timedmapslink);
}

function createtablerowtooltip($row, $i)
{
	$points = $row['points'];
	$totalpoints = gettotalpoints($row);
	$points_coop = number_format($points);
	$points_realism = number_format($row['points_realism']);
	$points_versus = number_format($row['points_survivors'] + $row['points_infected']);
	$points_versus_sur = number_format($row['points_survivors']);
	$points_versus_inf = number_format($row['points_infected']);
	$points_survival = number_format($row['points_survival']);
	$points_scavenge = number_format($row['points_scavenge_survivors'] + $row['points_scavenge_infected']);
	$points_scavenge_sur = number_format($row['points_scavenge_survivors']);
	$points_scavenge_inf = number_format($row['points_scavenge_infected']);
	$points_realismversus = number_format($row['points_realism_survivors'] + $row['points_realism_infected']);
	$points_realismversus_sur = number_format($row['points_realism_survivors']);
	$points_realismversus_inf = number_format($row['points_realism_infected']);
	$points_mutations = number_format($row['points_mutations']);
	$totalplaytime = gettotalplaytime($row);
	$playtime_coop = getplaytime($row['playtime']);
	$playtime_realism = getplaytime($row['playtime_realism']);
	$playtime_versus = getplaytime($row['playtime_versus']);
	$playtime_survival = getplaytime($row['playtime_survival']);
	$playtime_scavenge = getplaytime($row['playtime_scavenge']);
	$playtime_realismversus = getplaytime($row['playtime_realismversus']);
	$playtime_mutations = getplaytime($row['playtime_mutations']);
	$ppm_coop = number_format(getppm($points, $row['playtime']), 2);
	$ppm_versus = number_format(getppm($row['points_survivors'] + $row['points_infected'], $row['playtime_versus']), 2);
	$ppm_survival = number_format(getppm($row['points_survival'], $row['playtime_survival']), 2);
	$ppm_realism = number_format(getppm($row['points_realism'], $row['playtime_realism']), 2);
	$ppm_scavenge = number_format(getppm($row['points_scavenge_survivors'] + $row['points_scavenge_infected'], $row['playtime_scavenge']), 2);
	$ppm_realismversus = number_format(getppm($row['points_realism_survivors'] + $row['points_realism_infected'], $row['playtime_realismversus']), 2);
	$ppm_mutations = number_format(getppm($row['points_mutations'], $row['playtime_mutations']), 2);
}

function parseplayersummary($profilexml) { return parseplayerprofile($profilexml, "/profile/summary"); }
function parseplayerheadline($profilexml) { return parseplayerprofile($profilexml, "/profile/headline"); }
function parseplayername($profilexml) { return parseplayerprofile($profilexml, "/profile/steamID"); }
function parseplayerhoursplayed2wk($profilexml) { return parseplayerprofile($profilexml, "/profile/hoursPlayed2Wk"); }
function parseplayersteamrating($profilexml) { return parseplayerprofile($profilexml, "/profile/steamRating"); }
function parseplayermembersince($profilexml) { return parseplayerprofile($profilexml, "/profile/memberSince"); }
function parseplayerprivacystate($profilexml) { return parseplayerprofile($profilexml, "/profile/privacyState"); }
function parseplayerprofile($profilexml, $xpathnode)
{
	$arr = $profilexml->xpath($xpathnode);
	if (!$arr || count($arr) != 1)
		return "";
	return "" . $arr[0];
}

$TOTALPOINTS = "points + points_survivors + points_infected + points_survival" . ($game_version != 1 ? " + points_realism + points_scavenge_survivors + points_scavenge_infected + points_realism_survivors + points_realism_infected + points_mutations" : "");
$TOTALPLAYTIME = "playtime + playtime_versus + playtime_survival" . ($game_version != 1 ? " + playtime_realism + playtime_scavenge + playtime_realismversus + playtime_mutations" : "");

if (!function_exists('file_put_contents')) {
	function file_put_contents($filename, $data) {
		$f = @fopen($filename, 'w');
		if (!$f) {
			return false;
		} else {
			$bytes = fwrite($f, $data);
			fclose($f);
			return $bytes;
		}
	}
}

$con_main = mysql_connect($mysql_server, $mysql_user, $mysql_password);
mysql_select_db($mysql_db, $con_main);
mysql_query("SET NAMES 'utf8'", $con_main);

$coop_campaigns = array();
$versus_campaigns = array();
$realism_campaigns = array();
$survival_campaigns = array();
$scavenge_campaigns = array();
$realismversus_campaigns = array();
$mutations_campaigns = array();

if ($game_version == 1)
{
	$coop_campaigns = array("l4d_hospital" => "No Mercy",
					   "l4d_airport" => "Dead Air",
					   "l4d_smalltown" => "Death Toll",
					   "l4d_farm" => "Blood Harvest",
					   "l4d_garage" => "Crash Course",
					   "" => "Custom Maps");

	$versus_campaigns = array("l4d_vs_hospital" => "No Mercy",
					   "l4d_vs_airport" => "Dead Air",
					   "l4d_vs_smalltown" => "Death Toll",
					   "l4d_vs_farm" => "Blood Harvest",
					   "l4d_garage" => "Crash Course",
					   "" => "Custom Maps");

	$survival_campaigns = array("l4d_sv_lighthouse" => "Lighthouse",
					   "l4d_hospital" => "No Mercy - Co-op",
					   "l4d_airport" => "Dead Air - Co-op",
					   "l4d_smalltown" => "Death Toll - Co-op",
					   "l4d_farm" => "Blood Harvest - Co-op",
						 "l4d_vs_hospital" => "No Mercy - Versus",
					   "l4d_vs_airport" => "Dead Air - Versus",
					   "l4d_vs_smalltown" => "Death Toll - Versus",
					   "l4d_vs_farm" => "Blood Harvest - Versus",
					   "l4d_garage" => "Crash Course",
					   "" => "Custom Maps");
}
else if ($game_version == 2)
{
	$coop_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");

	$versus_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");

	$survival_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");

	$scavenge_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");

	$realism_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");

	$realismversus_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");

	$mutations_campaigns = array("c1m" => "Dead Center",
					   "c2m" => "Dark Carnival",
					   "c3m" => "Swamp Fever",
					   "c4m" => "Hard Rain",
					   "c5m" => "The Parish",
					   "c6m" => "The Passing",
					   "c7m" => "The Sacrifice",
					   "c8m" => "No Mercy",
					   "c9m" => "Crash Course",
					   "c10m" => "Death Toll",
					   "c11m" => "Dead Air",
					   "c12m" => "Blood Harvest",
					   "c13m" => "Cold Stream",
					   "" => "Custom Maps");
}
else
{
	$coop_campaigns = array("l4d_hospital" => "No Mercy (L4D1)",
					   "l4d_airport" => "Dead Air (L4D1)",
					   "l4d_smalltown" => "Death Toll (L4D1)",
					   "l4d_farm" => "Blood Harvest (L4D1)",
					   "l4d_garage" => "Crash Course (L4D1)",
						 "c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps");

	$versus_campaigns = array("l4d_vs_hospital" => "No Mercy (L4D1)",
					   "l4d_vs_airport" => "Dead Air (L4D1)",
					   "l4d_vs_smalltown" => "Death Toll (L4D1)",
					   "l4d_vs_farm" => "Blood Harvest (L4D1)",
					   "l4d_garage" => "Crash Course (L4D1)",
					   "c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps");

	$survival_campaigns = array("l4d_sv_lighthouse" => "Lighthouse (L4D1)",
					   "l4d_hospital" => "No Mercy - Co-op (L4D1)",
					   "l4d_airport" => "Dead Air - Co-op (L4D1)",
					   "l4d_smalltown" => "Death Toll - Co-op (L4D1)",
					   "l4d_farm" => "Blood Harvest - Co-op (L4D1)",
						 "l4d_vs_hospital" => "No Mercy - Versus (L4D1)",
					   "l4d_vs_airport" => "Dead Air - Versus (L4D1)",
					   "l4d_vs_smalltown" => "Death Toll - Versus (L4D1)",
					   "l4d_vs_farm" => "Blood Harvest - Versus (L4D1)",
					   "l4d_garage" => "Crash Course (L4D1)",
					   "c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps");

	$scavenge_campaigns = array("c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps (L4D2)");

	$realism_campaigns = array("c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps (L4D2)");

	$realismversus_campaigns = array("c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps (L4D2)");

	$mutations_campaigns = array("c1m" => "Dead Center (L4D2)",
					   "c2m" => "Dark Carnival (L4D2)",
					   "c3m" => "Swamp Fever (L4D2)",
					   "c4m" => "Hard Rain (L4D2)",
					   "c5m" => "The Parish (L4D2)",
					   "c6m" => "The Passing (L4D2)",
					   "c7m" => "The Sacrifice (L4D2)",
					   "c8m" => "No Mercy (L4D2)",
					   "c9m" => "Crash Course (L4D2)",
					   "c10m" => "Death Toll (L4D2)",
					   "c11m" => "Dead Air (L4D2)",
					   "c12m" => "Blood Harvest (L4D2)",
					   "c13m" => "Cold Stream (L4D2)",
					   "" => "Custom Maps (L4D2)");
}

$site_name = htmlentities($site_name);
$game_locations = array();
$international = false;
$game_country_code_last = "NULL";


$realismlink = "";
$scavengelink = "";
$realismversuslink = "";
$mutationslink = "";
$realismcmblink = "";
$scavengecmblink = "";
$realismversuscmblink = "";
$mutationscmblink = "";

$carousel_spieler = array();
$result = mysql_query("SELECT COUNT(*) AS players_served, sum(kills) AS total_kills FROM " . $mysql_tableprefix . "players");
if ($result && $row = mysql_fetch_array($result)){$carousel_spieler[] = $row['players_served'];}

$carousel_infected_kills = array();
$result = mysql_query("SELECT COUNT(*) AS players_served, sum(kills) AS total_kills FROM " . $mysql_tableprefix . "players" );
if ($result && $row = mysql_fetch_array($result)){$carousel_infected_kills[] = $row['total_kills'];}

$carousel_headshots = array();
$result = mysql_query("SELECT COUNT(*) AS players_served, SUM(headshots) AS headshots FROM " . $mysql_tableprefix . "players" );
if ($result && $row = mysql_fetch_array($result)){$carousel_headshots[] = $row['headshots'];}

if ($site_template != "" && $site_template != "default") {
	$arr_templatefiles = php4_scandir("" . $site_template);
	foreach ($arr_templatefiles as $file)
	{
		if (!is_dir($file))
			$templatefiles[$file] = $site_template . "" . $file;
	}
}
?>