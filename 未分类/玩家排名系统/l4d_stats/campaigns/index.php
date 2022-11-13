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
$tpl = new Template("" . $templatefiles['campaigns_layout.tpl']);
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
	$tpl->set("title", "- Campaigns (" . $disptype . ")");
	$tpl->set("page_heading", "Campaigns " . $typelabel . "");
	$maparr = array();
	$totals = array();
	if ($type == "coop"){ $campaigns = $coop_campaigns; $query_where = " AND gamemode = 0"; }
	else if ($type == "versus") { $campaigns = $versus_campaigns; $query_where = " AND gamemode = 1"; }
	else if ($type == "realism") { $campaigns = $realism_campaigns; $query_where = " AND gamemode = 2"; }
	else if ($type == "survival") { $campaigns = $survival_campaigns; $query_where = " AND gamemode = 3"; }
	else if ($type == "scavenge") { $campaigns = $scavenge_campaigns; $query_where = " AND gamemode = 4"; }
	else if ($type == "realismversus") { $campaigns = $realismversus_campaigns; $query_where = " AND gamemode = 5"; }
	else if ($type == "mutations") { $campaigns = $mutations_campaigns; $query_where = " AND gamemode = 6"; }
	foreach ($campaigns as $prefix => $title) {
		$query = "SELECT playtime_nor + playtime_adv + playtime_exp as playtime, points_nor + points_adv + points_exp as points, kills_nor + kills_adv + kills_exp as kills";
		if ($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations") $query .= ", restarts_nor + restarts_adv + restarts_exp as restarts";
		else if ($type == "versus" || $type == "scavenge" || $type == "realismversus") {
			$query .= ", infected_win_nor + infected_win_adv + infected_win_exp as infected_win";
			$query .= ", points_infected_nor + points_infected_adv + points_infected_exp as points_infected";
			$query .= ", survivor_kills_nor + survivor_kills_adv + survivor_kills_exp as kill_survivor";
		}
		$query .= " FROM " . $mysql_tableprefix . "maps";
		if (strlen($prefix) > 0) $query .= " WHERE LOWER(name) like '" . strtolower($prefix) . "%' and custom = 0";
		else $query .= " WHERE custom = 1 AND playtime_nor + playtime_adv + playtime_exp > 0";
		$query .= $query_where;
			$result = mysql_query($query) or die(mysql_error());
			if (mysql_num_rows($result) <= 0) continue;
			$playtime = 0;
			$points = 0;
			$points_infected = 0;
			$kills = 0;
			$kill_survivor = 0;
			$restarts = 0;
			$infected_win = 0;
			while ($row = mysql_fetch_array($result)) {
				$playtime += $row['playtime'];
				$points += $row['points'];
				$kills += $row['kills'];
				if ($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations")
					$restarts += $row['restarts'];
				else if ($type == "versus" || $type == "scavenge" || $type == "realismversus") {
					$points_infected += $row['points_infected'];
					$kill_survivor += $row['kill_survivor'];
					$infected_win += $row['infected_win'];
				}
			}
			$totals['playtime'] += $playtime;
			$totals['points'] += $points;
			$totals['kills'] += $kills;
			if ($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations")
				$totals['restarts'] += $restarts;
			else if ($type == "versus" || $type == "scavenge" || $type == "realismversus") {
				$totals['points_infected'] += $points_infected;
				$totals['kill_survivor'] += $kill_survivor;
				$totals['infected_win'] += $infected_win;
			}
			$maparr[] = $line . "<tr><td data-title=\"Campaign:\">" . $title . "</td><td data-title=\"Playtime:\">" . formatage($playtime * 60) . "</td>" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "<td data-title=\"Rounds Lost:\">" . number_format($infected_win) . "</td><td data-title=\"Points as Infected:\">" . number_format($points_infected) . "</td>" : "") . "<td data-title=\"Points as Survivor:\">" . number_format($points) . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "" : " (" . number_format(getppm($points, $playtime), 2) . ")") . "</td><td data-title=\"Infected destroyed:\">" . number_format($kills) . "</td>" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "<td data-title=\"Survivor destroyed:\">" . number_format($kill_survivor) . "</td>" : "") . (($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations") ? "<td data-title=\"Restarts:\">" . number_format($restarts) . "</td>" : "") . "</tr>";
			$i++;
	}
	$arr_achievements = array();
	if ($totals['kills'] > $population_minkills) {
		$popkills = getpopulation($totals['kills'], $population_file);
		$arr_achievements[] = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span>More Infected destroyed than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $popkills[0] . "&btnI=1\" target=\"_blank\">" . $popkills[0] . "</a> - Population: " . number_format($popkills[1]) . " Humans.</span><span><small>That is almost more than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $popkills[2] . "&btnI=1\" target=\"_blank\">" . $popkills[2] . "</a> - Population: " . number_format($popkills[3]) . " Humans!</small></span></div></div><br />\n";
	}
	if (count($arr_achievements) == 0) $arr_achievements[] = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span>Fewer Infected destroyed than the Population of the smallest town in USA.</span></div></div><br />";
	$line = ($i & 1) ? "" : "<tr>";
	$maparr[] = $line . "<tr><td class=\"alink-link2\">Total:</td><td class=\"alink-link2\">" . formatage($totals['playtime'] * 60) . "</td>" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "<td class=\"alink-link2\">" . number_format($totals['infected_win']) . "</td><td class=\"alink-link2\">" . number_format($totals['points_infected']) . "</b></td>" : "") . "<td class=\"alink-link2\">" . number_format($totals['points']) . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "" : " (" . number_format(getppm($totals['points'], $totals['playtime']), 2) . ")") . "</td><td class=\"alink-link2\">" . number_format($totals['kills']) . "</td>" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "<td class=\"alink-link2\">" . number_format($totals['kill_survivor']) . "</td>" : "") . (($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations") ? "<td class=\"alink-link2\">" . number_format($totals['restarts']) . "</td>" : "") . "</tr>";
	$stats = new Template("" . $templatefiles["campaigns_overview_" . $type . ".tpl"]);
	$stats->set("arr_achievements", $arr_achievements);
	$totalpop = getpopulation($totals['kills'], $population_file, False);
	$stats->set("totalpop", $totalpop);
	$stats->set("maps", $maparr);
	$output = $stats->fetch("" . $templatefiles["campaigns_overview_" . $type . ".tpl"]);
	foreach ($campaigns as $prefix => $title) {
		$stats = new Template("" . $templatefiles['campaigns_page.tpl']);
		$stats->set("page_subject", $title);
		$maps = new Template("campaigns_page_" . $type . ".tpl");
		$maparr = array();
		$query = "SELECT name, playtime_nor + playtime_adv + playtime_exp as playtime, points_nor + points_adv + points_exp as points, kills_nor + kills_adv + kills_exp as kills";
		if ($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations") $query .= ", restarts_nor + restarts_adv + restarts_exp as restarts";
		else if ($type == "versus" || $type == "scavenge" || $type == "realismversus") {
			$query .= ", infected_win_nor + infected_win_adv + infected_win_exp as infected_win";
			$query .= ", points_infected_nor + points_infected_adv + points_infected_exp as points_infected";
			$query .= ", survivor_kills_nor + survivor_kills_adv + survivor_kills_exp as kill_survivor";
		}
		$query .= " FROM " . $mysql_tableprefix . "maps";
		if (strlen($prefix) > 0) $query .= " WHERE LOWER(name) like '" . strtolower($prefix) . "%' and custom = 0";
		else $query .= " WHERE custom = 1 AND playtime_nor + playtime_adv + playtime_exp > 0";
		$query .= $query_where;
		$query .= " ORDER BY name ASC";
		$result = mysql_query($query) or die(mysql_error());
		if (mysql_num_rows($result) <= 0) continue;
		$i = 1;
		while ($row = mysql_fetch_array($result)) {
				$line = ($i & 1) ? "<tr>" : "	<tr>";
				$maparr[] = $line . "<td data-title=\"Map:\">" . $row['name'] . "</td><td data-title=\"Playtime:\">" . formatage($row['playtime'] * 60) . "</td>" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "<td data-title=\"Rounds Lost:\">" . number_format($row['infected_win']) . "</td><td data-title=\"Points as Infected:\">" . number_format($row['points_infected']) . "</td>" : "") . "<td data-title=\"Points as Survivor:\">" . number_format($row['points']) . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "" : " (" . number_format(getppm($row['points'], $row['playtime']), 2) . ")") . "</td><td data-title=\"Infected destroyed:\">" . number_format($row['kills']) . "</td>" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") ? "<td data-title=\"Survivor destroyed:\">" . number_format($row['kill_survivor']) . "</td>" : "") . (($type == "coop" || $type == "realism" || $type == "survival" || $type == "mutations") ? "<td data-title=\"Restarts:\">" . number_format($row['restarts']) . "</td>" : "") . "</tr>\n";
				$i++;
		}
		$maps->set("maps", $maparr);
		$body = $maps->fetch("" . $templatefiles["campaigns_page_" . $type . ".tpl"]);
		$stats->set("page_body", $body);
		$stats->set("page_link", "<a class=\"alink-link2\" href=\"campaign.php?id=" . $prefix . "&type=" . $type . "\">View Full Statistics</a>");
		$output .= $stats->fetch("" . $templatefiles['campaigns_page.tpl']);
	}
}
else {
	$tpl->set("title", "Campaigns");
	$tpl->set("page_heading", "Campaigns");
	setcommontemplatevariables($tpl);
	$output = "<meta http-equiv=\"refresh\" content=\"3; URL=index.php?type=coop\"><br /><center>You will be forwarded ...</center>\n";
}
$tpl->set("body", trim($output));
echo $tpl->fetch("" . $templatefiles['campaigns_layout.tpl']);

?>