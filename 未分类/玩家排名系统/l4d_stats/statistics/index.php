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
$tpl = new Template("" . $templatefiles['statistics_layout.tpl']);
setcommontemplatevariables($tpl);
$players_sql = "
SELECT COUNT(*) AS total_players,
	SUM(award_adrenaline) AS award_adrenaline,
	SUM(award_allinsafehouse) AS award_allinsafehouse,
	SUM(award_bulldozer) AS award_bulldozer,
	SUM(award_campaigns) AS award_campaigns,
	SUM(award_charger) AS award_charger,
	SUM(award_fincap) AS award_fincap,
	SUM(award_friendlyfire) AS award_friendlyfire,
	SUM(award_gascans_poured) AS award_gascans_poured,
	SUM(award_hunter) AS award_hunter,
	SUM(award_infected_win) AS award_infected_win,
	SUM(award_jockey) AS award_jockey,
	SUM(award_ledgegrab) AS award_ledgegrab,
	SUM(award_left4dead) AS award_left4dead,
	SUM(award_letinsafehouse) AS award_letinsafehouse,
	SUM(award_matador) AS award_matador,
	SUM(award_medkit) AS award_medkit,
	SUM(award_perfect_blindness) AS award_perfect_blindness,
	SUM(award_pills) AS award_pills,
	SUM(award_pounce_nice) AS award_pounce_nice,
	SUM(award_pounce_perfect) AS award_pounce_perfect,
	SUM(award_protect) AS award_protect,
	SUM(award_rescue) AS award_rescue,
	SUM(award_revive) AS award_revive,
	SUM(award_scatteringram) AS award_scatteringram,
	SUM(award_smoker) AS award_smoker,
	SUM(award_survivor_down) AS award_survivor_down,
	SUM(award_tankkill) AS award_tankkill,
	SUM(award_tankkillnodeaths) AS award_tankkillnodeaths,
	SUM(award_teamkill) AS award_teamkill,
	SUM(award_upgrades_added) AS award_upgrades_added,
	SUM(award_witchcrowned) AS award_witchcrowned,
	SUM(award_witchdisturb) AS award_witchdisturb,
	SUM(charger_impacts) AS charger_impacts,
	SUM(headshots) AS headshots,
	SUM(infected_boomer_blinded) AS infected_boomer_blinded,
	SUM(infected_boomer_vomits) AS infected_boomer_vomits,
	SUM(infected_charger_damage) AS infected_charger_damage,
	SUM(infected_hunter_pounce_counter) AS infected_hunter_pounce_counter,
	SUM(infected_hunter_pounce_dmg) AS infected_hunter_pounce_dmg,
	SUM(infected_jockey_damage) AS infected_jockey_damage,
	SUM(infected_jockey_ridetime) AS infected_jockey_ridetime,
	SUM(infected_smoker_damage) AS infected_smoker_damage,
	SUM(infected_spawn_1) AS infected_spawn_1,
	SUM(infected_spawn_2) AS infected_spawn_2,
	SUM(infected_spawn_3) AS infected_spawn_3,
	SUM(infected_spawn_4) AS infected_spawn_4,
	SUM(infected_spawn_5) AS infected_spawn_5,
	SUM(infected_spawn_6) AS infected_spawn_6,
	SUM(infected_spawn_8) AS infected_spawn_8,
	SUM(infected_spitter_damage) AS infected_spitter_damage,
	SUM(infected_tank_damage) AS infected_tank_damage,
	SUM(jockey_rides) AS jockey_rides,
	SUM(kill_boomer) AS kill_boomer,
	SUM(kill_charger) AS kill_charger,
	SUM(kill_hunter) AS kill_hunter,
	SUM(kill_infected) AS kill_infected,
	SUM(kill_jockey) AS kill_jockey,
	SUM(kill_smoker) AS kill_smoker,
	SUM(kill_spitter) AS kill_spitter,
	SUM(kills) AS kills,
	SUM(melee_kills) AS melee_kills,
	SUM(points) AS points,
	SUM(points_infected) AS points_infected,
	SUM(points_mutations) AS points_mutations,
	SUM(points_realism) AS points_realism,
	SUM(points_realism_infected) AS points_realism_infected,
	SUM(points_realism_survivors) AS points_realism_survivors,
	SUM(points_scavenge_infected) AS points_scavenge_infected,
	SUM(points_scavenge_survivors) AS points_scavenge_survivors,
	SUM(points_survival) AS points_survival,
	SUM(points_survivors) AS points_survivors,
	SUM(mutations_kills_survivors) AS mutations_kills_survivors,
	SUM(realism_kills_survivors) AS realism_kills_survivors,
	SUM(scavenge_kills_survivors) AS scavenge_kills_survivors,
	SUM(versus_kills_survivors) AS versus_kills_survivors
FROM " . $mysql_tableprefix . "players";
$result = mysql_query($players_sql) or die("Error: " . mysql_error());
$total = mysql_fetch_array($result);
$players = $total['total_players'];
$total_points = $total['points'];
$totalpoints_realism =  $total['points_realism'];
$totalpoints_mutations =  $total['points_mutations'];
$totalpoints_survival =  $total['points_survival'];
$totalpoints_survivors =  $total['points_survivors'];
$totalpoints_infected =  $total['points_infected'];
$totalpoints_scavenge_survivors =  $total['points_scavenge_survivors'];
$totalpoints_scavenge_infected =  $total['points_scavenge_infected'];
$totalpoints_realism_survivors =  $total['points_realism_survivors'];
$totalpoints_realism_infected =  $total['points_realism_infected'];
$totalpoints = $total_points + $totalpoints_survivors + $totalpoints_infected + $totalpoints_survival;
$totalpoints += $totalpoints_realism + $totalpoints_scavenge_survivors + $totalpoints_scavenge_infected + $totalpoints_realism_survivors + $totalpoints_realism_infected + $totalpoints_mutations;
$player_totalpoints = $totalpoints;
$arr_kills = array();
$arr_kills['Normal Infected:'] = $total['kill_infected'];
$arr_kills['Smokers:'] = $total['kill_smoker'];
$arr_kills['Boomers:'] = $total['kill_boomer'];
$arr_kills['Hunters:'] = $total['kill_hunter'];
if ($game_version != 1) { $arr_kills['Chargers:'] = $total['kill_charger']; $arr_kills['Spitters:'] = $total['kill_spitter']; $arr_kills['Jockeys:'] = $total['kill_jockey']; }
$arr_survivor_awards = array();
$arr_survivor_awards['Pills Given:'] = $total['award_pills'];
$arr_survivor_awards['Adrenalines Given:'] = $total['award_adrenaline'];
$arr_survivor_awards['Medkits Given:'] = $total['award_medkit'];
$arr_survivor_awards['Saved Friendlies from Hunters:'] = $total['award_hunter'];
$arr_survivor_awards['Saved Friendlies from Smokers:'] = $total['award_smoker'];
$arr_survivor_awards['Saved Friendlies from Jockeys:'] = $total['award_jockey'];
$arr_survivor_awards['Saved Friendlies from Chargers:'] = $total['award_charger'];
$arr_survivor_awards['Leveled Charges:'] = $total['award_matador'];
$arr_survivor_awards['Gas Canisters Poured:'] = $total['award_gascans_poured'];
$arr_survivor_awards['Ammo Upgrades Deployed:'] = $total['award_upgrades_added'];
$arr_survivor_awards['Crowned Witches:'] = $total['award_witchcrowned'];
$arr_survivor_awards['Protected Friendlies:'] = $total['award_protect'];
$arr_survivor_awards['Revived Friendlies:'] = $total['award_revive'];
$arr_survivor_awards['Rescued Friendlies:'] = $total['award_rescue'];
$arr_survivor_awards['Tanks Killed with Team:'] = $total['award_tankkill'];
$arr_survivor_awards['Tanks Killed with No Deaths:'] = $total['award_tankkillnodeaths'];
$arr_survivor_awards['Safe Houses Reached with All Survivors:'] = $total['award_allinsafehouse'];
$arr_survivor_awards['Campaigns Completed:'] = $total['award_campaigns'];
$arr_infected_awards = array();
$arr_infected_awards['All Survivors Dead:'] = $total['award_infected_win'];
$arr_infected_awards['Perfect Blindness:'] = $total['award_perfect_blindness'];
$arr_infected_awards['Perfect Pounce:'] = $total['award_pounce_perfect'];
$arr_infected_awards['Nice Pounce:'] = $total['award_pounce_nice'];
$arr_infected_awards['Bulldozer:'] = $total['award_bulldozer'];
$arr_infected_awards['Survivors Incapacitated:'] = $total['award_survivor_down'];
$arr_infected_awards['Caused Ledge Grab:'] = $total['award_ledgegrab'];
if ($game_version != 1) { $arr_infected_awards['Scattering Ram:'] = $total['award_scatteringram']; }
$arr_demerits = array();
$arr_demerits['Friendly Fire Incidents:'] = $total['award_friendlyfire'];
$arr_demerits['Incapacitated Friendlies:'] = $total['award_fincap'];
$arr_demerits['Teammates Killed:'] = $total['award_teamkill'];
$arr_demerits['Friendlies Left For Dead:'] = $total['award_left4dead'];
$arr_demerits['Infected Let In Safe Room:'] = $total['award_letinsafehouse'];
$arr_demerits['Witches Disturbed:'] = $total['award_witchdisturb'];
$tpl->set("title", "- Statistics");
$tpl->set("page_heading", "Statistics");
$stats = new Template("" . $templatefiles['statistics_output.tpl']);
$stats->set("players", number_format($players));
$stats->set("points", number_format($totalpoints));
$stats->set("infected_killed", number_format($total['kills']));
$stats->set("melee_kills", number_format($total['melee_kills']));
$stats->set("survivors_killed_versus", number_format($total['versus_kills_survivors']));
if ($game_version != 1) {$stats->set("survivors_killed_scavenge", "<br>Scavenge: " . number_format($total['scavenge_kills_survivors']) . "<br>Realism&nbsp;Versus: " . number_format($total['realism_kills_survivors']) . "<br>Mutations: " . number_format($total['mutations_kills_survivors'])); $stats->set("survivors_killed", number_format($total['versus_kills_survivors'] + $total['scavenge_kills_survivors'] + $total['realism_kills_survivors'] + $total['mutations_kills_survivors']));}
else { $stats->set("survivors_killed_scavenge", ""); $stats->set("survivors_killed", number_format($total['versus_kills_survivors']));}
$stats->set("headshots", number_format($total['headshots']));
if ($total['infected_spawn_1'] == 0 || $total['infected_smoker_damage'] == 0) $stats->set("avg_smoker", "0");
else $stats->set("avg_smoker", number_format($total['infected_smoker_damage'] / $total['infected_spawn_1'], 2));
if ($total['infected_boomer_vomits'] == 0 || $total['infected_boomer_blinded'] == 0) $stats->set("avg_boomer", "0");
else $stats->set("avg_boomer", number_format($total['infected_boomer_blinded'] / $total['infected_boomer_vomits'], 2));
if ($total['infected_hunter_pounce_counter'] == 0 || $total['infected_hunter_pounce_dmg'] == 0) $stats->set("avg_hunter", "0");
else $stats->set("avg_hunter", number_format($total['infected_hunter_pounce_dmg'] / $total['infected_hunter_pounce_counter'], 2));
if ($total['infected_spawn_8'] == 0 || $total['infected_tank_damage'] == 0) $stats->set("avg_tank", "0");
else $stats->set("avg_tank", number_format($total['infected_tank_damage'] / $total['infected_spawn_8'], 2));
$stats->set("spawn_smoker", number_format($total['infected_spawn_1']));
$stats->set("smoker_damage", number_format($total['infected_smoker_damage']));
$stats->set("spawn_boomer", number_format($total['infected_spawn_2']));
$stats->set("boomer_vomits", number_format($total['infected_boomer_vomits']));
$stats->set("boomer_blinded", number_format($total['infected_boomer_blinded']));
$stats->set("spawn_hunter", number_format($total['infected_spawn_3']));
$stats->set("hunter_pounces", number_format($total['infected_hunter_pounce_counter']));
$stats->set("hunter_damage", number_format($total['infected_hunter_pounce_dmg']));
$stats->set("spawn_tank", number_format($total['infected_spawn_8']));
$stats->set("tank_damage", number_format($total['infected_tank_damage']));
if ($game_version != 1) {
	$avg_spitter = "0";
	if ($total['infected_spawn_4'] > 0 && $total['infected_spitter_damage'] > 0) $avg_spitter = number_format($total['infected_spitter_damage'] / $total['infected_spawn_4'], 2);
	$avg_jockey = "0";
	if ($total['infected_spawn_5'] > 0 && $total['infected_jockey_damage'] > 0) $avg_jockey = number_format($total['infected_jockey_damage'] / $total['infected_spawn_5'], 2);
	$avg_charger = "0";
	if ($total['infected_spawn_6'] > 0 && $total['infected_charger_damage'] > 0) $avg_charger = number_format($total['infected_charger_damage'] / $total['infected_spawn_6'], 2);
	$l4d2_special_infected = "";
	$l4d2_special_infected .= "<tr><td>Charger:</td><td>" . $avg_charger . "</td></tr>";
	$l4d2_special_infected .= "<tr><td>Spitter:</td><td>" . $avg_spitter . "</td></tr>";
	$l4d2_special_infected .= "<tr><td>Jockey:</td><td>" . $avg_jockey . "</td></tr>";
	$stats->set("l4d2_special_infected", $l4d2_special_infected);
}
else $stats->set("l4d2_special_infected", "");
if ($total['kills'] == 0 || $total['headshots'] == 0) $stats->set("ratio", "0");
else $stats->set("ratio", number_format($total['headshots'] / $total['kills'], 4) * 100);
$maps_sql = "
SELECT gamemode, COUNT(*) AS total_maps, SUM(playtime_nor) AS _playtime_nor, SUM(playtime_adv) AS _playtime_adv, SUM(playtime_exp) AS _playtime_exp, SUM(points_nor) AS points_nor, SUM(points_adv) AS points_adv, SUM(points_exp) AS points_exp, SUM(points_infected_nor) AS points_infected_nor, SUM(points_infected_adv) AS points_infected_adv, SUM(points_infected_exp) AS points_infected_exp
FROM " . $mysql_tableprefix . "maps WHERE playtime_nor + playtime_adv + playtime_exp > 0 GROUP BY gamemode ORDER BY gamemode ";
$result = mysql_query($maps_sql) or die("Error: " . mysql_error());
$arr_maps = array();
$totalplaytime = 0;
$totalplaytime_nor = 0;
$totalplaytime_adv = 0;
$totalplaytime_exp = 0;
$totalpoints = 0;
$totalpoints_nor = 0;
$totalpoints_adv = 0;
$totalpoints_exp = 0;
$totalmaps = 0;
$arr_ppm_playtime = array();
while ($row = mysql_fetch_array($result)) {
	$gamemodename = "Unknown";
	$arr_vals = array();
	switch ($row['gamemode']) {
		case 0: $gamemodename = "Coop"; break;
		case 1: $gamemodename = "Versus"; break;
		case 2: if ($game_version == 1) continue 2; $gamemodename = "Realism"; break;
		case 3: $gamemodename = "Survival"; break;
		case 4: if ($game_version == 1) continue 2; $gamemodename = "Scavenge"; break;
		case 5: if ($game_version == 1) continue 2; $gamemodename = "Realism&nbsp;Versus"; break;
		case 6: if ($game_version == 1) continue 2; $gamemodename = "Mutations"; break;
	}
	$gmtotalplaytime = $row['_playtime_nor'] + $row['_playtime_adv'] + $row['_playtime_exp'];
	$gmtotalpoints = $row['points_nor'] + $row['points_infected_nor'] + $row['points_adv'] + $row['points_infected_adv'] + $row['points_exp'] + $row['points_infected_exp'];
	$arr_ppm_playtime[strtolower($gamemodename)] = $gmtotalplaytime;
	$arr_vals['gamemodename'] = $gamemodename;
	$arr_vals['totalmaps'] = $row['total_maps'];
	$arr_vals['totalplaytime_nor'] = getplaytime($row['_playtime_nor']);
	$arr_vals['totalplaytime_adv'] = getplaytime($row['_playtime_adv']);
	$arr_vals['totalplaytime_exp'] = getplaytime($row['_playtime_exp']);
	$arr_vals['totalplaytime'] = getplaytime($gmtotalplaytime);
	$arr_vals['totalpoints_nor'] = number_format($row['points_nor'] + $row['points_infected_nor']);
	$arr_vals['totalpoints_adv'] = number_format($row['points_adv'] + $row['points_infected_adv']);
	$arr_vals['totalpoints_exp'] = number_format($row['points_exp'] + $row['points_infected_exp']);
	$arr_vals['totalpoints'] = number_format($gmtotalpoints);
	$ppm = 0;
	if ($gmtotalpoints > 0 && $gmtotalplaytime > 0) $ppm = $gmtotalpoints / $gmtotalplaytime;
	$arr_vals['totalppm'] = number_format($ppm, 2);
	$ppm_nor = 0;
	if ($row['points_nor'] + $row['points_infected_nor'] > 0 && $row['_playtime_nor'] > 0) $ppm_nor = ($row['points_nor'] + $row['points_infected_nor']) / $row['_playtime_nor'];
	$ppm_adv = 0;
	if ($row['points_adv'] + $row['points_infected_adv'] > 0 && $row['_playtime_adv'] > 0) $ppm_adv = ($row['points_adv'] + $row['points_infected_adv']) / $row['_playtime_adv'];
	$ppm_exp = 0;
	if ($row['points_exp'] + $row['points_infected_exp'] > 0 && $row['_playtime_exp'] > 0) $ppm_exp = ($row['points_exp'] + $row['points_infected_exp']) / $row['_playtime_exp'];
	$arr_vals['totalppm_nor'] = number_format($ppm_nor, 2);
	$arr_vals['totalppm_adv'] = number_format($ppm_adv, 2);
	$arr_vals['totalppm_exp'] = number_format($ppm_exp, 2);
	$arr_maps[] = $arr_vals;
	$totalplaytime_nor += $row['_playtime_nor'];
	$totalplaytime_adv += $row['_playtime_adv'];
	$totalplaytime_exp += $row['_playtime_exp'];
	$totalplaytime += $gmtotalplaytime;
	$totalpoints_nor += $row['points_nor'] + $row['points_infected_nor'];
	$totalpoints_adv += $row['points_adv'] + $row['points_infected_adv'];
	$totalpoints_exp += $row['points_exp'] + $row['points_infected_exp'];
	$totalpoints += $gmtotalpoints;
	$totalmaps += $row['total_maps'];
}

$stats->set("player_ppm", number_format(getppm($player_totalpoints, $totalplaytime), 2));
$stats->set("player_ppm_coop", number_format(getppm($total['points'], $arr_ppm_playtime['coop']), 2));
$stats->set("player_ppm_versus", number_format(getppm($total['points_infected'] + $total['points_survivors'], $arr_ppm_playtime['versus']), 2));
$stats->set("player_ppm_survival", number_format(getppm($total['points_survival'], $arr_ppm_playtime['survival']), 2));
$stats->set("totalplaytime_nor", getplaytime($totalplaytime_nor));
$stats->set("totalplaytime_adv", getplaytime($totalplaytime_adv));
$stats->set("totalplaytime_exp", getplaytime($totalplaytime_exp));
$stats->set("totalplaytime", getplaytime($totalplaytime));
$stats->set("totalpoints_nor", number_format($totalpoints_nor));
$stats->set("totalpoints_adv", number_format($totalpoints_adv));
$stats->set("totalpoints_exp", number_format($totalpoints_exp));
$stats->set("totalpoints", number_format($totalpoints));
$stats->set("totalmaps", number_format($totalmaps));
$ppm = 0;
if ($totalpoints > 0 && $totalplaytime > 0) $ppm = $totalpoints / $totalplaytime;
$ppm_nor = 0;
if ($totalpoints_nor > 0 && $totalplaytime_nor > 0) $ppm_nor = $totalpoints_nor / $totalplaytime_nor;
$ppm_adv = 0;
if ($totalpoints_adv > 0 && $totalplaytime_adv > 0) $ppm_adv = $totalpoints_adv / $totalplaytime_adv;
$ppm_exp = 0;
if ($totalpoints_exp > 0 && $totalplaytime_exp > 0) $ppm_exp = $totalpoints_exp / $totalplaytime_exp;
$stats->set("totalppm", number_format($ppm, 2));
$stats->set("totalppm_nor", number_format($ppm_nor, 2));
$stats->set("totalppm_adv", number_format($ppm_adv, 2));
$stats->set("totalppm_exp", number_format($ppm_exp, 2));
arsort($arr_survivor_awards);
arsort($arr_infected_awards);
$arr_achievements = array();
	if ($total['kill_infected'] > $population_minkills) {
		$popkills = getpopulation($total['kill_infected'], $population_file);
		$arr_achievements[] = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span>More Infected were destroyed than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $popkills[0] . "&btnI=1\" target=\"_blank\">" . $popkills[0] . "</a> - Population: " . number_format($popkills[1]) . " Humans.</span><span><small>That is almost more than the entire Population of <a class=\"alink-link2\" href=\"http://google.com/search?q=site:en.wikipedia.org+" . $popkills[2] . "&btnI=1\" target=\"_blank\">" . $popkills[2] . "</a> - Population: " . number_format($popkills[3]) . " Humans!</small></span></div></div><br />";
	}
	if (count($arr_achievements) == 0) $arr_achievements[] = "<div class=\"col-md-12 h-100\"><div class=\"card-body worldmap d-flex flex-column justify-content-center text-center\"><span>Fewer Infected were destroyed than the Population of the smallest town in USA.</span></div></div><br />";
$stats->set("arr_kills", $arr_kills);
$stats->set("arr_survivor_awards", $arr_survivor_awards);
$stats->set("arr_infected_awards", $arr_infected_awards);
$stats->set("arr_demerits", $arr_demerits);
$stats->set("arr_maps", $arr_maps);
$stats->set("arr_achievements", $arr_achievements);
$output = $stats->fetch("" . $templatefiles['statistics_output.tpl']);
$tpl->set('body', trim($output));
echo $tpl->fetch("" . $templatefiles['statistics_layout.tpl']);

?>