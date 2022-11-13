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
$tpl = new Template("" . $templatefiles['player_layout.tpl']);
if (strstr($_GET['steamid'], "/")) exit;
$id = mysql_real_escape_string($_GET['steamid']);
setcommontemplatevariables($tpl);
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players WHERE steamid = '" . $id . "'");
$row = mysql_fetch_array($result);
$totalpoints = $row['points'] + $row['points_survival'] + $row['points_survivors'] + $row['points_infected'] + ($game_version != 1 ? $row['points_realism'] + $row['points_scavenge_survivors'] + $row['points_scavenge_infected'] + $row['points_realism_survivors'] + $row['points_realism_infected'] + $row['points_mutations'] : 0);
$rankrow = mysql_fetch_array(mysql_query("SELECT COUNT(*) AS rank FROM " . $mysql_tableprefix . "players WHERE points + points_survival + points_survivors + points_infected" . ($game_version != 1 ? " + points_realism + points_scavenge_survivors + points_scavenge_infected + points_realism_survivors + points_realism_infected + points_mutations" : "") . " >= '" . $totalpoints . "'"));
$rank = $rankrow['rank'];
$arr_kills = array();
$arr_kills['Common Infected'] = array($row['kill_infected'], "Common Infected killed");
$arr_kills['Hunters'] = array($row['kill_hunter'], "Hunters killed");
$arr_kills['Smokers'] = array($row['kill_smoker'], "Smokers killed");
$arr_kills['Boomers'] = array($row['kill_boomer'], "Boomers killed");
$arr_kills['Spitters'] = array($row['kill_spitter'], "Spitters killed");
$arr_kills['Jockeys'] = array($row['kill_jockey'], "Jockeys killed");
$arr_kills['Chargers'] = array($row['kill_charger'], "Chargers killed");
$arr_survivor_awards = array();
$arr_survivor_awards['Campaigns Completed:'] = array($row['award_campaigns'], "Campaigns Completed");
$arr_survivor_awards['Safe Houses Reached with All Survivors:'] = array($row['award_allinsafehouse'], "Safe Houses Reached with No Deaths");
$arr_survivor_awards['Gas Canisters Poured:'] = array($row['award_gascans_poured'], "Successfully poured Gas Canisters");
$arr_survivor_awards['Ammo Upgrades Deployed:'] = array($row['award_upgrades_added'], "Ammo Upgrades Deployed");
$arr_survivor_awards['Adrenalines Given:'] = array($row['award_adrenaline'], "Adrenalines given to another Survivor");
$arr_survivor_awards['Pills Given:'] = array($row['award_pills'], "Pills given to another Survivor");
$arr_survivor_awards['Medkits Given:'] = array($row['award_medkit'], "Healed another Survivor");
$arr_survivor_awards['Revived Friendlies:'] = array($row['award_revive'], "Helped Incapacitated Survivors");
$arr_survivor_awards['Defibrillators Used:'] = array($row['award_defib'], "Dead Survivors brought back to life");
$arr_survivor_awards['Rescued Friendlies:'] = array($row['award_rescue'], "Rescued Survivors from rescue rooms");
$arr_survivor_awards['Protected Friendlies:'] = array($row['award_protect'], "Protected another Survivor from a common Infected");
$arr_survivor_awards['Saved Friendlies from Smokers:'] = array($row['award_smoker'], "Saved a Survivor from Smokers");
$arr_survivor_awards['Saved Friendlies from Hunters:'] = array($row['award_hunter'], "Saved a Survivor from Hunters");
$arr_survivor_awards['Saved Friendlies from Chargers:'] = array($row['award_charger'], "Saved a Survivor from Chargers");
$arr_survivor_awards['Saved Friendlies from Jockeys:'] = array($row['award_jockey'], "Saved a Survivor from Jockeys");
$arr_survivor_awards['Leveled Charges:'] = array($row['award_matador'], "Killed a Charging Charger with a melee weapon");
$arr_survivor_awards['Tanks Killed with Team:'] = array($row['award_tankkill'], "Killed Tanks");
$arr_survivor_awards['Tanks Killed with No Deaths:'] = array($row['award_tankkillnodeaths'], "Killed Tanks with No Deaths");
$arr_survivor_awards['Crowned Witches:'] = array($row['award_witchcrowned'], "Successfully Crowned Witches");
$arr_infected_awards = array();
$arr_infected_awards['All Survivors Dead:'] = array($row['award_infected_win'], "All Survivors dead");
$arr_infected_awards['Survivors Incapacitated:'] = array($row['award_survivor_down'], "Survivors incapacitated");
$arr_infected_awards['Perfect Blindness:'] = array($row['award_perfect_blindness'], "All Survivors blinded");
$arr_infected_awards['Death From Above:'] = array($row['award_pounce_perfect'], "Perfect Hunter pounces");
$arr_infected_awards['Pain From Above:'] = array($row['award_pounce_nice'], "Very good Hunter pounces");
$arr_infected_awards['Bulldozer:'] = array($row['award_bulldozer'], "Dealing massive damage to Survivor");
$arr_infected_awards['Scattering Ram:'] = array($row['award_scatteringram'], "Charged a Scattering Ram at a group of survivors");
$arr_demerits = array();
$arr_demerits['Friendly Fire Incidents:'] = array($row['award_friendlyfire'], "Survivors harmed");
$arr_demerits['Teammates Killed:'] = array($row['award_teamkill'], "Survivors killed");
$arr_demerits['Incapacitated Friendlies:'] = array($row['award_fincap'], "Survivors incapacitated");
$arr_demerits['Friendlies Left For Dead:'] = array($row['award_left4dead'], "Survivors left to die");
$arr_demerits['Infected Let In Safe Room:'] = array($row['award_letinsafehouse'], "Infected let in safe room");
$arr_demerits['Witches Disturbed:'] = array($row['award_witchdisturb'], "Witches disturbed");
if (mysql_num_rows($result) > 0) {
	$playername = htmlentities($row['name'], ENT_COMPAT, "UTF-8");
	$playername2 = $playername;
	$timesrow = mysql_fetch_array(mysql_query("SELECT COUNT(*) AS times FROM " . $mysql_tableprefix . "timedmaps WHERE steamid = '" . $id . "'"));
	$times = $timesrow['times'];
	$tpl->set("title", "Player: " . $playername);
	$tpl->set("page_heading", "Player: " . $playername);
	$stats = new Template("" . $templatefiles['player_output.tpl']);
	$stats->set("player_name", $playername);
	$stats->set("player_steamid", $row['steamid']);
	$stats->set("player_timedmaps", $times . "");
	if (function_exists(bcadd)) $stats->set("player_url", getfriendid($row['steamid']) );
	else $stats->set("player_url", "<b>ERROR</b>");
	$stats->set("player_lastonline", date($lastonlineformat, $row['lastontime'] + ($dbtimemod * 3600)) . " (" . formatage(time() - $row['lastontime'] + ($dbtimemod * 3600)) . " ago)");
	$stats->set("player_playtime", gettotalplaytime($row));
	if ($game_version != 1){
		$stats->set("player_playtime_realism", "&nbsp;&nbsp;Realism: " . getplaytime($row['playtime_realism']) . "<br>&nbsp;&nbsp;Mutations: " . getplaytime($row['playtime_mutations']) . "<br>");
		$stats->set("player_playtime_scavenge", "<br>&nbsp;&nbsp;Scavenge: " . getplaytime($row['playtime_scavenge']) . "<br>&nbsp;&nbsp;Realism&nbsp;Versus: " . getplaytime($row['playtime_realismversus']));}
	else {
		$stats->set("player_playtime_realism", "");
		$stats->set("player_playtime_scavenge", "");}
	$stats->set("player_playtime_coop", getplaytime($row['playtime']));
	$stats->set("player_playtime_versus", getplaytime($row['playtime_versus']));
	$stats->set("player_playtime_survival", getplaytime($row['playtime_survival']));
	$stats->set("player_rank", $rank);
	$stats->set("player_points", number_format($totalpoints));
	$stats->set("player_points_coop", number_format($row['points']));
	if ($game_version != 1){
		$stats->set("player_points_realism", "Realism: " . number_format($row['points_realism']) . "<br>Mutations: " . number_format($row['points_mutations']) . "<br>");
		$stats->set("player_points_scavenge", "<br><b>Scavenge: " . number_format($row['points_scavenge_infected'] + $row['points_scavenge_survivors']) . "</b><br>&nbsp;&nbsp;Survivors: " . number_format($row['points_scavenge_survivors']) . "<br>&nbsp;&nbsp;Infected: " . number_format($row['points_scavenge_infected']) . "<br><b>Realism&nbsp;Versus: " . number_format($row['points_realism_infected'] + $row['points_realism_survivors']) . "</b><br>&nbsp;&nbsp;Survivors: " . number_format($row['points_realism_survivors']) . "<br>&nbsp;&nbsp;Infected: " . number_format($row['points_realism_infected']));}
	else {
		$stats->set("player_points_realism", "");
		$stats->set("player_points_scavenge", "");}
	$stats->set("player_points_versus", number_format($row['points_infected'] + $row['points_survivors']));
	$stats->set("player_points_versus_sur", number_format($row['points_survivors']));
	$stats->set("player_points_versus_inf", number_format($row['points_infected']));
	$stats->set("player_points_survival", number_format($row['points_survival']));
	if ($row['infected_spawn_1'] == 0 || $row['infected_smoker_damage'] == 0) $stats->set("player_avg_smoker", "0");
	else $stats->set("player_avg_smoker", number_format($row['infected_smoker_damage'] / $row['infected_spawn_1'], 2));
	if ($row['infected_boomer_vomits'] == 0 || $row['infected_boomer_blinded'] == 0) $stats->set("player_avg_boomer", "0");
	else $stats->set("player_avg_boomer", number_format($row['infected_boomer_blinded'] / $row['infected_boomer_vomits'], 2));
	if ($row['infected_hunter_pounce_counter'] == 0 || $row['infected_hunter_pounce_dmg'] == 0) $stats->set("player_avg_hunter", "0");
	else $stats->set("player_avg_hunter", number_format($row['infected_hunter_pounce_dmg'] / $row['infected_hunter_pounce_counter'], 2));
	if ($row['infected_spawn_8'] == 0 || $row['infected_tank_damage'] == 0) $stats->set("player_avg_tank", "0");
	else $stats->set("player_avg_tank", number_format($row['infected_tank_damage'] / $row['infected_spawn_8'], 2));
	$stats->set("player_spawn_smoker", number_format($row['infected_spawn_1']));
	$stats->set("player_smoker_damage", number_format($row['infected_smoker_damage']));
	$stats->set("player_spawn_boomer", number_format($row['infected_spawn_2']));
	$stats->set("player_boomer_vomits", number_format($row['infected_boomer_vomits']));
	$stats->set("player_boomer_blinded", number_format($row['infected_boomer_blinded']));
	$stats->set("player_spawn_hunter", number_format($row['infected_spawn_3']));
	$stats->set("player_hunter_pounces", number_format($row['infected_hunter_pounce_counter']));
	$stats->set("player_hunter_damage", number_format($row['infected_hunter_pounce_dmg']));
	$stats->set("player_spawn_tank", number_format($row['infected_spawn_8']));
	$stats->set("player_tank_damage", number_format($row['infected_tank_damage']));
	if ($game_version != 1){
		$avg_spitter = "0";
		if ($row['infected_spawn_4'] > 0 && $row['infected_spitter_damage'] > 0)
			$avg_spitter = number_format($row['infected_spitter_damage'] / $row['infected_spawn_4'], 2);
		$avg_jockey = "0";
		if ($row['infected_spawn_5'] > 0 && $row['infected_jockey_damage'] > 0)
			$avg_jockey = number_format($row['infected_jockey_damage'] / $row['infected_spawn_5'], 2);
		$avg_charger = "0";
		if ($row['infected_spawn_6'] > 0 && $row['infected_charger_damage'] > 0)
			$avg_charger = number_format($row['infected_charger_damage'] / $row['infected_spawn_6'], 2);
		$l4d2_special_infected = "";
		$l4d2_special_infected .= "<tr><td class=\"td50\">Charger:</td><td class=\"td50\">" . $avg_charger . "</td></tr>";
		$l4d2_special_infected .= "<tr><td class=\"td50\">Spitter:</td><td class=\"td50\">" . $avg_spitter . "</td></tr>";
		$l4d2_special_infected .= "<tr><td class=\"td50\">Jockey:</td><td class=\"td50\">" . $avg_jockey . "</td></tr>";
		$stats->set("l4d2_special_infected", $l4d2_special_infected);
	}
	else { $stats->set("l4d2_special_infected", ""); }
	if ($row['kills'] == 0 || $row['headshots'] == 0) $stats->set("player_ratio", "0");
	else $stats->set("player_ratio", number_format($row['headshots'] / $row['kills'], 4) * 100);
	$totalplaytime = gettotalplaytimecalc($row);
	$stats->set("player_ppm", number_format(getppm($totalpoints, $totalplaytime), 2));
	$stats->set("player_ppm_coop", number_format(getppm($row['points'], $row['playtime']), 2));
	if ($game_version != 1){
		$stats->set("player_ppm_realism", "Realism: " . number_format(getppm($row['points_realism'], $row['playtime_realism']), 2) . "<br>Mutations: " . number_format(getppm($row['points_mutations'], $row['playtime_mutations']), 2) . "<br>");
		$stats->set("player_ppm_scavenge", "<br>Scavenge: " . number_format(getppm($row['points_scavenge_infected'] + $row['points_scavenge_survivors'], $row['playtime_scavenge']), 2) . "<br>Realism&nbsp;Versus: " . number_format(getppm($row['points_realism_infected'] + $row['points_realism_survivors'], $row['playtime_realismversus']), 2));}
	else {$stats->set("player_ppm_realism", "");$stats->set("player_ppm_scavenge", "");}
	$stats->set("player_ppm_versus", number_format(getppm($row['points_infected'] + $row['points_survivors'], $row['playtime_versus']), 2));
	$stats->set("player_ppm_survival", number_format(getppm($row['points_survival'], $row['playtime_survival']), 2));
	$stats->set("infected_killed", number_format($row['kills']));
	$stats->set("melee_kills", number_format($row['melee_kills']));
	$stats->set("survivors_killed", number_format($row['versus_kills_survivors'] + $row['scavenge_kills_survivors'] + $row['realism_kills_survivors'] + $row['mutations_kills_survivors']));
	$stats->set("survivors_killed_versus", number_format($row['versus_kills_survivors']));
	if ($game_version != 1)
		$stats->set("survivors_killed_scavenge", "<br>Scavenge: " . number_format($row['scavenge_kills_survivors']) . "<br>Realism&nbsp;Versus: " . number_format($row['realism_kills_survivors']) . "<br>Mutations: " . number_format($row['mutations_kills_survivors']));
	else {$stats->set("survivors_killed_scavenge", "");}
	$stats->set("player_headshots", number_format($row['headshots']));
	$arr_achievements = array();
	if ($row['kills'] > $population_minkills) {
		$popkills = getpopulation($row['kills'], $population_file, $population_cities);
		$arr_achievements[] = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span><span class=\"alink-link2\">" . $playername . "</span> destroyed more Infected than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $popkills[0] . "&btnI=1\" target=\"_blank\">" . $popkills[0] . "</a> - Population: " . number_format($popkills[1]) . " Humans.</span><span><small>That is almost more than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $popkills[2] . "&btnI=1\" target=\"_blank\">" . $popkills[2] . "</a> - Population: " . number_format($popkills[3]) . " Humans!</small></span></div></div><br />\n";}
	if (count($arr_achievements) == 0)
		$arr_achievements[] = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span><span class=\"alink-link2\">" . $playername . "</span> destroyed fewer Infected than the Population of the smallest town in USA.</span></div></div><br />\n";
	$stats->set("arr_kills", $arr_kills);
	$stats->set("arr_survivor_awards", $arr_survivor_awards);
	$stats->set("arr_infected_awards", $arr_infected_awards);
	$stats->set("arr_demerits", $arr_demerits);
	$stats->set("arr_achievements", $arr_achievements);
	$totalpop = getpopulation($totals['kills'], $population_file, False);
	$stats->set("totalpop", $totalpop);
	$output = $stats->fetch("" . $templatefiles['player_output.tpl']);}
	else {
		$tpl->set("title", "Player: Unknow");
		$tpl->set("page_heading", "Player: Unknow");
		$output = "<meta http-equiv=\"refresh\" content=\"3; URL=index.php?type=coop\"><br /><center>Player not found. You will be forwarded ...</center>";
	}
$tpl->set('body', trim($output));
echo $tpl->fetch("" . $templatefiles['player_layout.tpl']);

?>