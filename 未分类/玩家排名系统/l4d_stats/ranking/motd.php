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
$tpl = new Template("" . $templatefiles['motd_layout.tpl']);
if (strstr($_GET['page'], "/")) exit;
$page = $_GET['page'];
if (strstr($_GET['type'], "/")) exit;
$type = strtolower($_GET['type']);
if (strstr($_GET['team'], "/")) exit;
$team = strtolower($_GET['team']);
$query = "";
if($type == "" || $type == "coop" || $type == "realism" || $type == "versus" || $type == "survival" || $type == "scavenge" || $type == "realismversus" || $type == "mutations"){
	$typelabel = "";
	if ($type == "coop") $typelabel = "(Coop)";
	else if ($type == "versus" && $team == "") $typelabel = "(Versus)";
	else if ($type == "scavenge" && $team == "") $typelabel = "(Scavenge)";
	else if ($type == "realism" && $team == "") $typelabel = "(Realism)";
	else if ($type == "survival" && $team == "") $typelabel = "(Survival)";
	else if ($type == "realismversus" && $team == "") $typelabel = "(Realism&nbsp;Versus)";
	else if ($type == "versus" && $team == "survivors") $typelabel = " - Versus : Survivors)";
	else if ($type == "versus" && $team == "infected") $typelabel = " - Versus : Infected";
	else if ($type == "scavenge" && $team == "survivors") $typelabel = " - Scavenge : Survivors";
	else if ($type == "scavenge" && $team == "infected") $typelabel = " - Scavenge : Infected";
	else if ($type == "realismversus" && $team == "survivors") $typelabel = " - Realism&nbsp;Versus : Survivors";
	else if ($type == "realismversus" && $team == "infected") $typelabel = " - Realism&nbsp;Versus : Infected";
	else if ($type == "mutations" && $team == "") $typelabel = "(Mutations)";
	else $team = "";
	setcommontemplatevariables($tpl);
	$tpl->set("title", "MOTD");
	$tpl->set("page_heading", "" . $typelabel);
	$sort = "";
	$playtime = "";
	if ($type == "coop"){$playtime = "playtime";$sort = "points";}
	else if ($type == "realism"){$playtime = "playtime_realism";$sort = "points_realism";}
	else if ($type == "survival"){$playtime = "playtime_survival";$sort = "points_survival";}
	else if ($type == "versus"){$playtime = "playtime_versus";if ($team == "survivors") $sort = "points_survivors";else if ($team == "infected") $sort = "points_infected";else $sort = "points_survivors + points_infected";}
	else if ($type == "scavenge"){$playtime = "playtime_scavenge";if ($team == "survivors") $sort = "points_scavenge_survivors";else if ($team == "infected") $sort = "points_scavenge_infected";else $sort = "points_scavenge_survivors + points_scavenge_infected";}
	else if ($type == "realismversus"){$playtime = "playtime_realismversus";if ($team == "survivors") $sort = "points_realism_survivors";else if ($team == "infected") $sort = "points_realism_infected";else $sort = "points_realism_survivors + points_realism_infected";}
	else if ($type == "mutations"){$playtime = "playtime_mutations";$sort = "points_mutations";}
	else{$playtime = $TOTALPLAYTIME;$sort = $TOTALPOINTS;}
	$query = "SELECT COUNT(*) as players_count FROM " . $mysql_tableprefix . "players WHERE " . $playtime . " > 0";
	$result = mysql_query($query);
	if (mysql_error()) {$output = "<p><b>MySQL Error:</b> " . mysql_error() . "</p>";}
	 else {
		$row = mysql_fetch_array($result);
		$arr_players = array();
		$stats = new Template("" . $templatefiles['motd_output.tpl']);
		$page_current = intval($page);
		$page_perpage = 25;
		$page_maxpages = ceil($row['players_count'] / $page_perpage) - 1;
		$page_nextpage = (intval($page_current + 1) > $page_maxpages) ? "0" : intval($page_current + 1);
		$page_prevpage = intval($page_current - 1);
		if ($page_prevpage < 0) $page_prevpage = $page_maxpages;
		if ($page_prevpage < 1) $page_prevpage = 0;
		$extra = ($type != "" ? "type=" . $type . "&" . (($type == "versus" || $type == "scavenge" || $type == "realismversus") && $team != "" ? "team=" . $team . "&" : "") : "");
		$stats->set("page_prev", "playerlist.php?" . $extra . "page=" . $page_prevpage);
		$stats->set("page_current", $page_current + 1);
		$stats->set("page_total", $page_maxpages + 1);
		$stats->set("page_next", "playerlist.php?" . $extra . "page=" . $page_nextpage);
		if ($game_version != 1){
			$stats->set("teammode_separator", "<br />\n");
			$stats->set("realism_link", " | <a href=\"?type=realism\">Realism</a> | <a href=\"?type=mutations\">Mutations</a>");
			$stats->set("scavenge_link", " | <a href=\"?type=scavenge\">Scavenge</a> (<a href=\"?type=scavenge&team=survivors\">Survivors</a> / <a href=\"?type=scavenge&team=infected\">Infected</a>)<br>\n" . "<a href=\"?type=realismversus\">Realism&nbsp;Versus</a> (<a href=\"?type=realismversus&team=survivors\">Survivors</a> / <a href=\"?type=realismversus&team=infected\">Infected</a>)");}
		else {$stats->set("teammode_separator", " | ");$stats->set("realism_link", "");$stats->set("scavenge_link", "");}
		if ($row['players_count'] > 0) {
			$query = "SELECT *, " . $sort . " as real_points, " . $playtime . " as real_playtime FROM " . $mysql_tableprefix . "players where " . $playtime . " > 0 ORDER BY " . $sort . " DESC LIMIT ". intval($page_current * $page_perpage) .",". $page_perpage;
			$result = mysql_query($query);
			if (mysql_error()) {$arr_players[] = "<p><b>MySQL Error:</b> " . mysql_error() . "</p>\n";}
			else {
				$i = ($page_current !== 0) ? 1 + intval($page_current * 25) : 1;
				while ($row = mysql_fetch_array($result)) {
					$country_record = $geoip->country($row['ip']);
					$line = createtablerowtooltip($row, $i);
					$line .= "<tr onclick=\"window.open='player.php?steamid=" . $row['steamid']."'\" style=\"cursor:pointer\"><tr onclick=\"window.open('".$site_statsurl."ranking/player.php?steamid=" . $row['steamid']."','_blank','');\" style=\"cursor:pointer\"><td data-title=\"Rank:\">" . number_format($i) . "</td><td data-title=\"Player:\">" . htmlentities($row['name'], ENT_COMPAT, "UTF-8") . "</td>";
					$line .= "<td data-title=\"Points:\">" . number_format($row['real_points']) . "</td>";
					$line .= "<td data-title=\"Country:\">" . ($showplayerflags ? "<img width=\"40\" height=\"20\" src=\"../_source/images/flags/" . strtolower($country_record->country->isoCode) . ".gif\" alt=\"" . strtolower($country_record->country->isoCode) . "\">" : "") . "</td>";
					$line .= "<td data-title=\"Playtime:\">" . formatage($row['real_playtime'] * 60) . "</td>";
					$line .= "<td data-title=\"Last Online:\">" . formatage(time() - $row['lastontime']) . " ago</td></tr>";
					$arr_players[] = $line;
					$i++;
				}
			}
		}
		else { $arr_players[] = "<th colspan=\"6\" class=\"text-center\">No Players found.</th>"; }
		$stats->set("players", $arr_players);
		$output = $stats->fetch("" . $templatefiles['motd_output.tpl']);
		}
	}
else {
	$tpl->set("title", "Ranking");
	$tpl->set("page_heading", "Ranking (INVALID)");
	$output = "<tr><td colspan=\"5\" class=\"text-center\">Gamemode not found.</td></tr>";
}
$tpl->set('body', trim($output));
$i = 1;
$top1 = array();
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players ORDER BY " . $TOTALPOINTS . " DESC LIMIT 1 OFFSET 0");
if ($result && mysql_num_rows($result) > 0) {
	while ($row = mysql_fetch_array($result)) {
		$name = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
		$avatarimg = "";
		$playerheadline = "";
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "") . "" . $name . "";
		if ($playerheadline) {$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td rowspan=\"2\">&nbsp;</td><td>" . $playername . "</td></tr><tr><td class=\"summary\">" . $playerheadline . "</td></tr></table>";}
		if ($avatarimg){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td>&nbsp;</td><td>" . $avatarimg . "</td>" . ($playerheadline ? "" : "<td>&nbsp;</td>") . "<td>" . $playername . "</td></tr></table>";}
		if (!$playerheadline && !$avatarimg){
		if ($top3_glow == "enabled") { $playername = "<div class=\"tablex\"><div class=\"cellx\"><div style=\"position:relative; overflow: hidden;\" class=\"text-left\">&nbsp;Player: " . $playername . "<div class=\"text-left\">&nbsp;Points: " . gettotalpoints($row) . "</div><div class=\"text-left\">&nbsp;Glow Reward: <font color=\"#feed77\">Legendary</font></div></div></div></div>"; }
		else { $playername = "<div class=\"tablex\"><div class=\"cellx\"><div style=\"position:relative; overflow: hidden;\" class=\"text-left\">&nbsp;Player: " . $playername . "<div class=\"text-left\">&nbsp;Points: " . gettotalpoints($row) . "</div></div></div></div>"; }}
		$top1[] = createtablerowtooltip($row, $i) . $playername . "";
		$i++;
	}
}
$i = 1;
$top1_href = array();
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players ORDER BY " . $TOTALPOINTS . " DESC LIMIT 1 OFFSET 0");
if ($result && mysql_num_rows($result) > 0){
	while ($row = mysql_fetch_array($result)) {
		$name = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
		$avatarimg = "";
		$playerheadline = "";
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "") . "player.php?steamid=" . $row['steamid'] . " ";
		if ($playerheadline){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td rowspan=\"2\">&nbsp;</td><td>" . $playername . "</td></tr><tr><td class=\"summary\">" . $playerheadline . "</td></tr></table>";}
		if ($avatarimg){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td>&nbsp;</td><td>" . $avatarimg . "</td>" . ($playerheadline ? "" : "<td>&nbsp;</td>") . "<td>" . $playername . "</td></tr></table>";}
		$top1_href[] = createtablerowtooltip($row, $i) . $playername . " ";
		$i++;
	}
}
$i = 1;
$top2 = array();
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players ORDER BY " . $TOTALPOINTS . " DESC LIMIT 1 OFFSET 1");
if ($result && mysql_num_rows($result) > 0){
	while ($row = mysql_fetch_array($result)) {
		$name = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
		$avatarimg = "";
		$playerheadline = "";
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "") . "" . $name . "";
		if ($playerheadline){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td rowspan=\"2\">&nbsp;</td><td>" . $playername . "</td></tr><tr><td class=\"summary\">" . $playerheadline . "</td></tr></table>";}
		if ($avatarimg){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td>&nbsp;</td><td>" . $avatarimg . "</td>" . ($playerheadline ? "" : "<td>&nbsp;</td>") . "<td>" . $playername . "</td></tr></table>";}
		if (!$playerheadline && !$avatarimg){
		if ($top3_glow == "enabled") { $playername = "<div class=\"tablex\"><div class=\"cellx\"><div style=\"position:relative; overflow: hidden;\" class=\"text-left\">&nbsp;Player: " . $playername . "<div class=\"text-left\">&nbsp;Points: " . gettotalpoints($row) . "</div><div class=\"text-left\">&nbsp;Glow Reward: <font color=\"#e300fd\">Epic</font></div></div></div></div>"; }
		else { $playername = "<div class=\"tablex\"><div class=\"cellx\"><div style=\"position:relative; overflow: hidden;\" class=\"text-left\">&nbsp;Player: " . $playername . "<div class=\"text-left\">&nbsp;Points: " . gettotalpoints($row) . "</div></div></div></div>"; }}
		$top2[] = createtablerowtooltip($row, $i) . $playername . "";
		$i++;
	}
}
$i = 1;
$top2_href = array();
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players ORDER BY " . $TOTALPOINTS . " DESC LIMIT 1 OFFSET 1");
if ($result && mysql_num_rows($result) > 0){
	while ($row = mysql_fetch_array($result)) {		
		$name = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
		$avatarimg = "";
		$playerheadline = "";
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "") . "player.php?steamid=" . $row['steamid'] . " ";
		if ($playerheadline){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td rowspan=\"2\">&nbsp;</td><td>" . $playername . "</td></tr><tr><td class=\"summary\">" . $playerheadline . "</td></tr></table>";}
		if ($avatarimg){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td>&nbsp;</td><td>" . $avatarimg . "</td>" . ($playerheadline ? "" : "<td>&nbsp;</td>") . "<td>" . $playername . "</td></tr></table>";}
		$top2_href[] = createtablerowtooltip($row, $i) . $playername . " ";
		$i++;
	}
}
$i = 1;
$top3 = array();
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players ORDER BY " . $TOTALPOINTS . " DESC LIMIT 1 OFFSET 2");
if ($result && mysql_num_rows($result) > 0) {
	while ($row = mysql_fetch_array($result)) {
		$name = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
		$avatarimg = "";
		$playerheadline = "";
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "") . "" . $name . "";
		if (!$playerheadline && !$avatarimg){
		if ($top3_glow == "enabled") { $playername = "<div class=\"tablex\"><div class=\"cellx\"><div style=\"position:relative; overflow: hidden;\" class=\"text-left\">&nbsp;Player: " . $playername . "<div class=\"text-left\">&nbsp;Points: " . gettotalpoints($row) . "</div><div class=\"text-left\">&nbsp;Glow Reward: <font color=\"#025bea\">Rare</font></div></div></div></div>"; }
		else { $playername = "<div class=\"tablex\"><div class=\"cellx\"><div style=\"position:relative; overflow: hidden;\" class=\"text-left\">&nbsp;Player: " . $playername . "<div class=\"text-left\">&nbsp;Points: " . gettotalpoints($row) . "</div></div></div></div>"; }}
		$top3[] = createtablerowtooltip($row, $i) . $playername . "";
		$i++;
	}
}
$i = 1;
$top3_href = array();
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players ORDER BY " . $TOTALPOINTS . " DESC LIMIT 1 OFFSET 2");
if ($result && mysql_num_rows($result) > 0){
	while ($row = mysql_fetch_array($result)) {
		$name = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
		$avatarimg = "";
		$playerheadline = "";
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "") . "player.php?steamid=" . $row['steamid'] . " ";
		if ($playerheadline){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td rowspan=\"2\">&nbsp;</td><td>" . $playername . "</td></tr><tr><td class=\"summary\">" . $playerheadline . "</td></tr></table>";}
		if ($avatarimg){$playername = "<table border=0 cellspacing=0 cellpadding=0 class=\"top10\"><tr><td>&nbsp;</td><td>" . $avatarimg . "</td>" . ($playerheadline ? "" : "<td>&nbsp;</td>") . "<td>" . $playername . "</td></tr></table>";}
		$top3_href[] = createtablerowtooltip($row, $i) . $playername . " ";
		$i++;
	}
}

$tpl->set("top1", $top1);
$tpl->set("top1_href", $top1_href);
$tpl->set("top2", $top2);
$tpl->set("top2_href", $top2_href);
$tpl->set("top3", $top3);
$tpl->set("top3_href", $top3_href);
echo $tpl->fetch("" . $templatefiles['motd_layout.tpl']);

?>
