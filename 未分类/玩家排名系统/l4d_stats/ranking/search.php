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
$tpl = new Template("" . $templatefiles['search_layout.tpl']);
$searchstring = mysql_real_escape_string($_POST['search']);
if ($searchstring."" == "") $searchstring = md5("nostring");
setcommontemplatevariables($tpl);
$tpl->set("title", "- Player Search");
$tpl->set("page_heading", "Player Search");
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players WHERE name LIKE '%" . $searchstring . "%' OR steamid LIKE '%" . $searchstring . "%' ORDER BY points + points_survivors + points_infected DESC LIMIT 100");
if (mysql_error()) { $output = "<p><b>MySQL Error:</b> " . mysql_error() . "</p>"; }
else {
	$arr_online = array();
	$stats = new Template("" . $templatefiles['search_output.tpl']);
	$i = 1;
	while ($row = mysql_fetch_array($result)) {
		$line = createtablerowtooltip($row, $i);
		$country_record = $geoip->country($row['ip']);
		$line .= "<tr onclick=\"window.location='player.php?steamid=" . $row['steamid']."'\" style=\"cursor:pointer\"><td data-title=\"Rank:\">" . number_format($i) . "</td><td data-title=\"Player:\">" . htmlentities($row['name'], ENT_COMPAT, "UTF-8") . "</a></td>";
		$line .= "<td data-title=\"Points:\">" . gettotalpoints($row) . "</td><td data-title=\"Country:\"><img width=\"40\" height=\"20\" src=\"../_source/images/flags/" . strtolower($country_record->country->isoCode) . ".gif\" alt=\"" . strtolower($country_record->country->isoCode) . "\"></td><td data-title=\"Playtime:\">" . gettotalplaytime($row) . "</td>";
	        $line .= "<td data-title=\"Last Online:\">" . formatage(time() - $row['lastontime']) . " ago</td></tr>\n";
    		$i++;
   		 $arr_online[] = $line;
  	}
	if (mysql_num_rows($result) == 0) $arr_online[] = "<th colspan=\"6\" class=\"text-center\">No Player found.</th>";
	$stats->set("online", $arr_online);
	$output = $stats->fetch("" . $templatefiles['search_output.tpl']);
}

$tpl->set('body', trim($output));
echo $tpl->fetch("" . $templatefiles['search_layout.tpl']);

?>