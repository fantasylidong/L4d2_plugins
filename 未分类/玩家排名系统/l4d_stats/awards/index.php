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
function addordinalnumbersuffix($num) {
 	if (!in_array(($num % 100), array(11,12,13))) {
		switch ($num % 10) {
			case 1: return  '1st';
			case 2: return  '2nd';
			case 3: return  '3rd';
			case 4: return  '4th';
			case 5: return  '5th';
		}
	}
	return $num . '';
}
include("../_source/common.php");
$tpl = new Template("./" . $templatefiles['awards_layout.tpl']);
include("./" . $award_file);
if ($game_version != 1) include("./" . $award_l4d2_file);
$awardarr = array("kills" => $award_kills,
	"headshots" => $award_headshots,
	"versus_kills_survivors + scavenge_kills_survivors + realism_kills_survivors" => $award_killsurvivor,
	"kill_infected" => $award_killinfected,
	"melee_kills" => $award_melee_kills,
	"kill_hunter" => $award_killhunter,
	"kill_smoker" => $award_killsmoker,
	"kill_boomer" => $award_killboomer,
	"award_pills" => $award_pills,
	"award_medkit" => $award_medkit,
	"award_hunter" => $award_hunter,
	"award_smoker" => $award_smoker,
	"award_protect" => $award_protect,
	"award_revive" => $award_revive,
	"award_rescue" => $award_rescue,
	"award_campaigns" => $award_campaigns,
	"award_tankkill" => $award_tankkill,
	"award_tankkillnodeaths" => $award_tankkillnodeaths,
	"award_allinsafehouse" => $award_allinsafehouse,
	"award_friendlyfire" => $award_friendlyfire,
	"award_teamkill" => $award_teamkill,
	"award_fincap" => $award_fincap,
	"award_left4dead" => $award_left4dead,
	"award_letinsafehouse" => $award_letinsafehouse,
	"award_witchdisturb" => $award_witchdisturb,
	"award_pounce_nice" => $award_pounce_nice,
	"award_pounce_perfect" => $award_pounce_perfect,
	"award_perfect_blindness" => $award_perfect_blindness,
	"award_infected_win" => $award_infected_win,
	"award_bulldozer" => $award_bulldozer,
	"award_survivor_down" => $award_survivor_down,
	"award_ledgegrab" => $award_ledgegrab,
	"award_witchcrowned" => $award_witchcrowned,
	"infected_tanksniper" => $infected_tanksniper
);
if ($game_version != 1)
{
	$awardarr["kill_spitter"] = $award_killspitter;
	$awardarr["kill_jockey"] = $award_killjockey;
	$awardarr["kill_charger"] = $award_killcharger;
	$awardarr["award_adrenaline"] = $award_adrenaline;
	$awardarr["award_defib"] = $award_defib;
	$awardarr["award_jockey"] = $award_jockey;
	$awardarr["award_charger"] = $award_charger;
	$awardarr["award_matador"] = $award_matador;
	$awardarr["award_scatteringram"] = $award_scatteringram;
}
if ($cachedate < time() - (60*$award_cache_refresh)) {
	$real_playtime_sql = $TOTALPLAYTIME;
	$real_playtime = "real_playtime";
	$real_points_sql = $TOTALPOINTS;
	$real_points = "real_points";
	$extrasql = ", " . $real_points_sql . " as " . $real_points . ", " . $real_playtime_sql . " as " . $real_playtime;
	if ((int)$award_display_players <= 0) { $award_display_players = 1; }
	$query = "SELECT *" . $extrasql . " FROM " . $mysql_tableprefix . "players WHERE (" . $real_playtime_sql . ") >= " . $award_minplaytime . " ORDER BY (" . $real_points . " / " . $real_playtime . ") DESC LIMIT " . $award_display_players;
	$result = mysql_query($query);
	if ($result && mysql_num_rows($result) > 0)
	{
		$i = 0;
		while ($row = mysql_fetch_array($result))
		{
			if ($i++ == 0)
			{
				$table_body = "<div class=\"card mb-3 w-100 rounded-0 py-3\"><div class=\"row no-gutters\"><div class=\"col-md-4 d-flex justify-content-center align-items-center\"><img class=\"img-border\" width=\"125\" height=\"125\" src=\"../_source/images/awards_01.jpg\" alt=\"awards\"></div><div class=\"col w-100\"><div class=\"card-body\">" . sprintf($award_ppm, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), number_format($row[$real_points] / $row[$real_playtime], 2)) ;
			}
			else
			{
				$table_body .= "<br />" . sprintf($award_second, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), addordinalnumbersuffix($i), number_format($row[$real_points] / $row[$real_playtime], 2)) . "";
			}
		}
		$table_body .= "</div></div></div></div><br />";
	}
	$query = "SELECT *" . $extrasql . " FROM " . $mysql_tableprefix . "players WHERE (" . $real_playtime_sql . ") >= " . $award_minplaytime . " ORDER BY " . $real_playtime . " DESC LIMIT " . $award_display_players;
	$result = mysql_query($query);
	if ($result && mysql_num_rows($result) > 0)
	{
		$i = 0;
		while ($row = mysql_fetch_array($result))
		{
			if ($i++ == 0)
			{
				$table_body .= "<div class=\"card mb-3 w-100 primeas-box rounded-0 py-3\"><div class=\"row no-gutters\"><div class=\"col-md-4 d-flex justify-content-center align-items-center\"><img class=\"img-border\" width=\"125\" height=\"125\" src=\"../_source/images/awards_02.jpg\" alt=\"awards\"></div><div class=\"col w-100\"><div class=\"card-body\">" . sprintf($award_time, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), formatage($row[$real_playtime] * 60));
			}
			else
			{
				$table_body .= "<br />" . sprintf($award_second, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), addordinalnumbersuffix($i), formatage($row[$real_playtime] * 60)) . "";
			}
		}
		$table_body .= "</div></div></div></div><br />";
	}
	$headshotratiosql = $real_playtime_sql . " >= " . $award_minplaytime . " AND " . $real_points_sql . " >= " . $award_minpoints . " AND kills >= " . $award_minkills . " AND headshots >= " . $award_minheadshots;
	$query = "SELECT *" . $extrasql . " FROM " . $mysql_tableprefix . "players WHERE " . $headshotratiosql . " ORDER BY (headshots/kills) DESC LIMIT " . $award_display_players;
	$result = mysql_query($query);
	if ($result && mysql_num_rows($result) > 0)
	{
		$i = 0;
		while ($row = mysql_fetch_array($result))
		{
			if (!($row['headshots'] && $row['kills']))
			{
				break;
			}

			if ($i++ == 0)
			{
				$table_body .= "<div class=\"card mb-3 w-100 primeas-box rounded-0 py-3\"><div class=\"row no-gutters\"><div class=\"col-md-4 d-flex justify-content-center align-items-center\"><img class=\"img-border\" width=\"125\" height=\"125\" src=\"../_source/images/awards_03.jpg\" alt=\"awards\"></div><div class=\"col w-100\"><div class=\"card-body\">" . sprintf($award_ratio, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), number_format($row['headshots'] / $row['kills'], 4) * 100);
			}
			else
			{
				$table_body .= "<br />" . sprintf($award_second, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), addordinalnumbersuffix($i), (number_format($row['headshots'] / $row['kills'], 4) * 100) . "&#37;") . "";
			}
		}
		$table_body .= "</div></div></div></div><br />";
	}
	foreach ($awardarr as $award => $awardstring) {
		$queryresult = array();
		$awardsql = ($award !== "award_teamkill" || $award !== "award_friendlyfire") ? " WHERE " . $real_playtime_sql . " >= " . $award_minplaytime . " AND " . $real_points_sql . " >= " . $award_minpointstotal : "";
		$query = "SELECT name, steamid, ip, " . $award . " AS queryvalue" . $extrasql . " FROM " . $mysql_tableprefix . "players " . $awardsql . " ORDER BY " . $award . " DESC LIMIT " . $award_display_players;
		$result = mysql_query($query);
		if ($result && mysql_num_rows($result) > 0)
		{
			$i = 0;
			while ($row = mysql_fetch_array($result))
			{
				if ($i++ == 0)
				{
					$table_body .= "<div class=\"card mb-3 w-100 primeas-box rounded-0 py-3\"><div class=\"row no-gutters\"><div class=\"col-md-4 d-flex justify-content-center align-items-center\"><img class=\"img-border\" width=\"125\" height=\"125\" src=\"../_source/images/awards_all.jpg\" alt=\"awards\"></div><div class=\"col w-100\"><div class=\"card-body\">" . sprintf($awardstring, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), number_format($row['queryvalue']));
				}
				else
				{
					$table_body .= "<br />" . sprintf($award_second, "player.php?steamid=" . $row['steamid'], htmlentities($row['name'], ENT_COMPAT, "UTF-8"), addordinalnumbersuffix($i), number_format($row['queryvalue'])) . "";
				}
			}
		$table_body .= "</div></div></div></div><br />";
		}
	}
	$stats = new Template("./" . $templatefiles['awards_output.tpl']);
	$stats->set("awards_date", date($lastonlineformat, time()));
	$stats->set("awards_body", $table_body);
	$award_output = $stats->fetch("./" . $templatefiles['awards_output.tpl']);
	file_put_contents("./awards_cache.html", trim($award_output));
}
setcommontemplatevariables($tpl);
$tpl->set("title", "- Awards");
$tpl->set("page_heading", "Awards");
$output = file_get_contents("./awards_cache.html");
$tpl->set('body', trim($output));
echo $tpl->fetch("./" . $templatefiles['awards_layout.tpl']);

?>