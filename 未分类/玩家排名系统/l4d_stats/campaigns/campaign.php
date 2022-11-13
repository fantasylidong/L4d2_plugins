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

require_once("../_source/geoip2.phar");
use GeoIp2\Database\Reader;
$geoip = new Reader('../_source/GeoLite2-Country.mmdb');
include("../_source/common.php");
$tpl = new Template("" . $templatefiles['campaign_layout.tpl']);
if (strstr($_GET['id'], "/")) exit;
$campaign = mysql_real_escape_string($_GET['id']);
if (strstr($_GET['type'], "/")) exit;
$type = strtolower($_GET['type']);
if ($type == "coop" || $type == "versus" || $type == "realism" || $type == "survival" || $type == "scavenge" || $type == "realismversus" || $type == "mutations") {
	$typelabel = "";
	if ($type == "coop") $typelabel = "(Coop)";
	else if ($type == "versus" && $team == "") $typelabel = "(Versus)";
	else if ($type == "scavenge" && $team == "") $typelabel = "(Scavenge)";
	else if ($type == "realism" && $team == "") $typelabel = "(Realism)";
	else if ($type == "survival" && $team == "") $typelabel = "(Survival)";
	else if ($type == "realismversus" && $team == "") $typelabel = "(Realism&nbsp;Versus)";
	else if ($type == "versus" && $team == "survivors") $typelabel = "Versus : Survivors";
	else if ($type == "versus" && $team == "infected") $typelabel = "Versus : Infected";
	else if ($type == "scavenge" && $team == "survivors") $typelabel = "Scavenge : Survivors";
	else if ($type == "scavenge" && $team == "infected") $typelabel = "Scavenge : Infected";
	else if ($type == "realismversus" && $team == "survivors") $typelabel = "Realism&nbsp;Versus : Survivors";
	else if ($type == "realismversus" && $team == "infected") $typelabel = "Realism&nbsp;Versus : Infected";
	else if ($type == "mutations" && $team == "") $typelabel = "(Mutations)";
	else $team = "";
	$disptype = ucfirst($type);
	setcommontemplatevariables($tpl);
	$tpl->set("title", "- Campaign: " . $title ."" . $typelabel . "");
	$tpl->set("page_heading"," " . $title ." ");
	$disptype = ucfirst($type);
	if ($type == "coop") { $campaigns = $coop_campaigns; $query_where = " and gamemode = 0"; }
	else if ($type == "versus") { $campaigns = $versus_campaigns; $query_where = " and gamemode = 1"; }
	else if ($type == "realism") { $campaigns = $versus_campaigns; $query_where = " and gamemode = 2"; }
	else if ($type == "survival") { $campaigns = $versus_campaigns; $query_where = " and gamemode = 3"; }
	else if ($type == "scavenge") { $campaigns = $versus_campaigns; $query_where = " and gamemode = 4"; }
	else if ($type == "realismversus") { $campaigns = $versus_campaigns; $query_where = " and gamemode = 5"; }
	else if ($type == "mutations") { $campaigns = $versus_campaigns; $query_where = " and gamemode = 6"; }
	setcommontemplatevariables($tpl);
	$title = $campaigns[$campaign];
	if ($title . "" == "") {
	    $tpl->set("title", "Invalid Campaign"); // Window title
	    $tpl->set("page_heading", "Invalid Campaign"); // Page header
	    $output = "<meta http-equiv=\"refresh\" content=\"3; URL=index.php?type=coop\"><center>You will be forwarded ...</center>";
	    $tpl->set("body", trim($output));
	    $tpl->set("top10", $top10);
	    echo $tpl->fetch("" . $templatefiles['campaign_layout.tpl']);
	    exit;
	}
	$tpl->set("gm","" . $disptype . "");
	$tpl->set("gm2","" . $typelabel . "");
	$tpl->set("page_heading"," " . $title ." ");
	$totalkills = 0;
	$query = "SELECT * FROM " . $mysql_tableprefix . "maps";
	if (strlen($campaign) > 0) $query .= " WHERE name LIKE '" . $campaign . "%' and custom = 0";
	else $query .= " WHERE custom = 1";
	$query .= $query_where;
	$query .= " ORDER BY name ASC";
	$result = mysql_query($query);
	while ($row = mysql_fetch_array($result)) {
		$playtime = array($row['playtime_nor'], $row['playtime_adv'], $row['playtime_exp'], $row['playtime_nor'] + $row['playtime_adv'] + $row['playtime_exp']);
		$points = array($row['points_nor'], $row['points_adv'], $row['points_exp'], $row['points_nor'] + $row['points_adv'] + $row['points_exp']);
		$stats = new Template("" . $templatefiles['campaigns_page.tpl']);
		$stats->set("page_subject", $row['name']);
		$map = new Template("" . $templatefiles["campaign_detailed_" . $type . ".tpl"]);
		$playtime_arr = array(formatage($playtime[0] * 60), formatage($playtime[1] * 60), formatage($playtime[2] * 60), formatage($playtime[3] * 60));
		$points_arr = array(number_format($points[0]), number_format($points[1]), number_format($points[2]), number_format($points[3]));
		$points_infected_arr = array(number_format($row['points_infected_nor']), number_format($row['points_infected_adv']), number_format($row['points_infected_exp']), number_format($row['points_infected_nor'] + $row['points_infected_adv'] + $row['points_infected_exp']));
		$kills_arr = array(number_format($row['kills_nor']), number_format($row['kills_adv']), number_format($row['kills_exp']), number_format($row['kills_nor'] + $row['kills_adv'] + $row['kills_exp']));
		$survivor_kills_arr = array(number_format($row['survivor_kills_nor']), number_format($row['survivor_kills_adv']), number_format($row['survivor_kills_exp']), number_format($row['survivor_kills_nor'] + $row['survivor_kills_adv'] + $row['survivor_kills_exp']));
		$infected_win_arr = array(number_format($row['infected_win_nor']), number_format($row['infected_win_adv']), number_format($row['infected_win_exp']), number_format($row['infected_win_nor'] + $row['infected_win_adv'] + $row['infected_win_exp']));
		$restarts_arr = array(number_format($row['restarts_nor']), number_format($row['restarts_adv']), number_format($row['restarts_exp']), number_format($row['restarts_nor'] + $row['restarts_adv'] + $row['restarts_exp']));
		$ppm_arr = array(number_format(getppm($points[0], $playtime[0]), 2), number_format(getppm($points[1], $playtime[1]), 2), number_format(getppm($points[2], $playtime[2]), 2), number_format(getppm($points[3], $playtime[3]), 2));
		$totalkills = $totalkills + ($row['kills_nor'] + $row['kills_adv'] + $row['kills_exp']);
		$map->set("playtime", $playtime_arr);
		$map->set("infected_win", $infected_win_arr);
		$map->set("points", $points_arr);
		$map->set("ppm", $ppm_arr);
		$map->set("points_infected", $points_infected_arr);
		$map->set("kills", $kills_arr);
		$map->set("survivor_kills", $survivor_kills_arr);
		$map->set("restarts", $restarts_arr);
		$body = $map->fetch("" . $templatefiles["campaign_detailed_" . $type . ".tpl"]);
		$stats->set("page_body", $body);
		$output = $stats->fetch("" . $templatefiles['campaigns_page.tpl']);
	}
	$campaignpop = getpopulation($totalkills, $population_file, False);
	if ($totalkills > $population_minkills) {
		$campaigninfo = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span>In this Campaign were more Infected destroyed than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $campaignpop[0] . "&btnI=1\">" . $campaignpop[0] . "</a> - Population: " . number_format($campaignpop[1]) . " Humans.</span><span><small>That is almost more than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $campaignpop[2] . "&btnI=1\">" . $campaignpop[2] . "</a> - Population: " . number_format($campaignpop[3]) . " Humans!</small></span></div></div><br />";
	}
	if ($totalkills < $population_minkills) {
		$campaigninfo = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span>Fewer Infected destroyed than the Population of the smallest town in USA.</span></div></div><br />";
	}
	$output = trim($campaigninfo . $output);
}
else {
	$tpl->set("title", "- Campaigns"); // Window title
	$tpl->set("page_heading", "Campaigns"); // Page header
	setcommontemplatevariables($tpl);
	$output = "<meta http-equiv=\"refresh\" content=\"3; URL=index.php?type=coop\"><br /><center>You will be forwarded ...</center>";
}

$tpl->set("body", $output);
echo $tpl->fetch("" . $templatefiles['campaign_layout.tpl']);

?>