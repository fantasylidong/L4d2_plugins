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

require_once("_source/geoip2.phar");
use GeoIp2\Database\Reader;
$geoip = new Reader('_source/GeoLite2-Country.mmdb');
include("_source/common.php");
$tpl = new Template("" . $templatefiles['index_layout.tpl']);
setcommontemplatevariables($tpl);
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players WHERE lastontime >= '" . intval(time() - 300) . "' ORDER BY " . $TOTALPOINTS . " DESC");
$playercount = number_format(mysql_num_rows($result));
setcommontemplatevariables($tpl);
$tpl->set("title", ""); // Window title
$tpl->set("page_heading", "Who's Online Now? (" . $playercount . ")" );
if (mysql_error()) { $output = "<p><b>MySQL Error:</b> " . mysql_error() . "</p>"; }
else {
	$arr_online = array();
	$stats = new Template("" . $templatefiles['index_output.tpl']);
	$i = 1;
	while ($row = mysql_fetch_array($result)) {
		if ($row['lastontime'] > time()) $row['lastontime'] = time();
		$lastgamemode = "Unknown";
		switch ($row['lastgamemode']) {
			case 0: $lastgamemode = "Coop"; break;
			case 1: $lastgamemode = "Versus"; break;
			case 2: $lastgamemode = "Realism"; break;
			case 3: $lastgamemode = "Survival"; break;
			case 4: $lastgamemode = "Scavenge"; break;
			case 5: $lastgamemode = "Realism&nbsp;Versus"; break;
			case 6: $lastgamemode = "Mutation"; break;
		}
		$player_ip = $row['ip'];
		$country_record = $geoip->country($row['ip']);
		$playername = ($showplayerflags ? "" : "")  . htmlentities($row['name'], ENT_COMPAT, "UTF-8") . "";
		$line = createtablerowtooltip($row, $i);
		$line .= "<tr onclick=\"window.location='./ranking/player.php?steamid=" . $row['steamid']."'\" style=\"cursor:pointer\"><td data-title=\"Gamemode:\">" . $lastgamemode . "</td>";
		$line .= "<td data-title=\"Player:\">" . $playername . "</td><td data-title=\"Points:\">" . gettotalpoints($row) . "</td><td data-title=\"Country:\"><img width=\"40\" height=\"20\" src=\"_source/images/flags/" . strtolower($country_record->country->isoCode) . ".gif\" alt=\"" . strtolower($country_record->country->isoCode) . "\"></td><td data-title=\"Playtime:\">" . gettotalplaytime($row) . "</td></tr>";
		$arr_online[] = $line;
		$i++;
	}
	if (count($arr_online) == 0) $arr_online[] = "<tr><th colspan=\"5\" class=\"text-center\">Currently there are no Players online.</th></tr>";
	$stats->set("online", $arr_online);
	$output = $stats->fetch("" . $templatefiles['index_output.tpl']);
}

$tpl->set('body', trim($output));
echo $tpl->fetch("" . $templatefiles['index_layout.tpl']);

?>