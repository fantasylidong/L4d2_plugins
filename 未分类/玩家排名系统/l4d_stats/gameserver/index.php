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
require_once 'GameQ.php';
use GeoIp2\Database\Reader;
$geoip = new Reader('../_source/GeoLite2-Country.mmdb');
include("../_source/common.php");
$tpl = new Template("" . $templatefiles['gameserver_layout.tpl']);
setcommontemplatevariables($tpl);
$result = mysql_query("SELECT * FROM " . $mysql_tableprefix . "players WHERE lastontime >= '" . intval(time() - 300) . "' ORDER BY " . $TOTALPOINTS . " DESC");
$playercount = number_format(mysql_num_rows($result));
setcommontemplatevariables($tpl);
$tpl->set("title", "- Gameserver");
$tpl->set("page_heading", "Who's Online Now? (" . $playercount . ")" );
if (mysql_error()) { $output = "MySQL Error: " . mysql_error() . ""; }
else {
	$arr_online = array();
	$stats = new Template("" . $templatefiles['gameserver_output.tpl']);
	$i = 1;
	while ($row = mysql_fetch_array($result)) {
	if ($row['lastontime'] > time()) $row['lastontime'] = time();
	$lastgamemode = "Unknown";
	switch ($row['lastgamemode']) {
		case 0: $lastgamemode = "Coop";
		break;
		case 1: $lastgamemode = "Versus";
		break;
		case 2: $lastgamemode = "Realism";
		break;
		case 3: $lastgamemode = "Survival";
		break;
		case 4: $lastgamemode = "Scavenge";
		break;
		case 5: $lastgamemode = "Realism&nbsp;Versus";
		break;
		case 6: $lastgamemode = "Mutation";
		break;
	}
	$player_ip = $row['ip'];
	$country_record = $geoip->country($row['ip']);
	$playername = ($showplayerflags ? "" : "")  . htmlentities($row['name'], ENT_COMPAT, "UTF-8") . "";
	$line = "<tr onclick=\"window.location='../ranking/player.php?steamid=" . $row['steamid']."'\" style=\"cursor:pointer\"><td data-title=\"Gamemode:\">" . $lastgamemode . "</td>";
	$line .= "<td data-title=\"Player:\">" . $playername . "</td><td data-title=\"Points:\">" . gettotalpoints($row) . "</td><td data-title=\"Country:\"><img width=\"40\" height=\"20\" src=\"../_source/images/flags/" . strtolower($country_record->country->isoCode) . ".gif\" alt=\"" . strtolower($country_record->country->isoCode) . "\"></td><td data-title=\"Playtime:\">" . gettotalplaytime($row) . "</td></tr>";
	$arr_online[] = $line;
}
if (count($arr_online) == 0) $arr_online[] = "<tr><th colspan=\"5\" class=\"text-center\">Currently there are no Players online.</th></tr>";
	$stats->set("online", $arr_online);
	$output = $stats->fetch("" . $templatefiles['gameserver_output.tpl']);
}
$tpl->set('body', trim($output));
echo $tpl->fetch("" . $templatefiles['gameserver_layout.tpl']);

$servers = array(
	'Server1' => array('left4dead2', ''.$server1_ip.'', ''.$server1_port.''),
	'Server2' => array('left4dead2', ''.$server2_ip.'', ''.$server2_port.''),
	'Server3' => array('left4dead2', ''.$server3_ip.'', ''.$server3_port.''),
	'Server4' => array('left4dead2', ''.$server4_ip.'', ''.$server4_port.''),
	'Server5' => array('left4dead2', ''.$server5_ip.'', ''.$server5_port.''),
	'Server6' => array('left4dead2', ''.$server6_ip.'', ''.$server6_port.''),
	'Server7' => array('left4dead2', ''.$server7_ip.'', ''.$server7_port.''),
	'Server8' => array('left4dead2', ''.$server8_ip.'', ''.$server8_port.''),
	'Server9' => array('left4dead2', ''.$server9_ip.'', ''.$server9_port.''),
	'Server10' => array('left4dead2', ''.$server10_ip.'', ''.$server10_port.''),
	'Server11' => array('left4dead2', ''.$server11_ip.'', ''.$server11_port.''),
	'Server12' => array('left4dead2', ''.$server12_ip.'', ''.$server12_port.''),
	'Server13' => array('left4dead2', ''.$server13_ip.'', ''.$server13_port.''),
	'Server14' => array('left4dead2', ''.$server14_ip.'', ''.$server14_port.''),
	'Server15' => array('left4dead2', ''.$server15_ip.'', ''.$server15_port.''),
);

$gq = new GameQ();
$gq->addServers($servers);
$gq->setOption('timeout', 300);
$gq->setFilter('normalise');
$results = $gq->requestData();

function print_results($results) {
	foreach ($results as $id => $data) {
		$fh = fopen('cache/'.$id.'.txt', 'w');
		fclose($fh);
		print_table($data, $id);
	}
}

function print_table($data, $id) {
	$gqs = array('gq_online', 'gq_address', 'gq_port', 'gq_prot', 'gq_type');
	foreach ($data as $key => $val) {
        	if (is_array($val)) continue;
        	$cls = empty($cls) ? ' class="uneven"' : '';
        	if (substr($key, 0, 1) == 'gq_') {
			$kcls = (in_array($key, $gqs)) ? 'always' : 'normalise';
			$key = sprintf("%s", $kcls, $key);
		}
		$old_key = read_server_key($id, $key);
		$old_val = read_server_val($id, $key);
		if ($old_key == null) {
			if ($key == "gq_online") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_online_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_hostname") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_hostname_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_numplayers") {
				if ($val == "") { }
				if (strcmp($val, '0')) {
					$fp = fopen('cache/'.$id.'_gq_numplayers_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
				else {
					$fp = fopen('cache/'.$id.'_gq_numplayers_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_maxplayers") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_maxplayers_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_mapname") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_mapname_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			$fp = fopen('cache/'.$id.'.txt', 'a');
			$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
			fwrite($fp, $data);
			fclose($fp);
		}
		if ($old_key == "") { }
		else if ($old_val != $val or $old_val == "") {
			$find_line = read_server_key($id, $old_key);
			if (strcmp($find_line, $key) == 0) {
				$line_check = '#' . $old_key . ': ' . $old_val . '';
				$DELETE = $line_check;
				$data = file('cache/'.$id.'.txt');
				$out = array();
				foreach($data as $line) {
					if(trim($line) != $DELETE) {
						$out[] = $line;
					}
				}
				$fp = fopen('cache/'.$id.'.txt', 'w+');
				flock($fp, LOCK_EX);
				foreach($out as $line) {
					fwrite($fp, $line);
				}
				flock($fp, LOCK_UN);
				fclose($fp);
			}
			if ($key == "gq_online") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_online_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_hostname") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_hostname_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_numplayers") {
				if ($val == "") { }
				if (strcmp($val, '0')) {
					$fp = fopen('cache/'.$id.'_gq_numplayers_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
				else {
					$fp = fopen('cache/'.$id.'_gq_numplayers_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_maxplayers") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_maxplayers_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
			if ($key == "gq_mapname") {
				if ($val == "") { }
				else {
					$fp = fopen('cache/'.$id.'_gq_mapname_tmp.txt', 'w');
					$data = '#' . $key . ': ' . $val . '' . PHP_EOL . '';
					fwrite($fp, $data);
					fclose($fp);
				}
			}
		}
	}
}

function read_server_key($id, $anything) {
	$lines = file('cache/'.$id.'.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = str_replace('' . PHP_EOL . '', '', $response);
	$cl = explode("#", $response);
	$cl = $cl[1];
	$cl = explode(":", $cl);
	$cl = $cl[0];
	return $cl;
}

function read_server_val($id, $anything) {
	$lines = file('cache/'.$id.'.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = substr(strstr("$response", " "), 1);
	$response = str_replace('' . PHP_EOL . '', '', $response);
	return $response;
}

function read_server_val_tmp_online($id, $anything) {
	$lines = file('cache/'.$id.'_gq_online_tmp.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = substr(strstr("$response", " "), 1);
	$response = str_replace('' . PHP_EOL . '', '', $response);
	return $response;
}


function read_server_val_tmp_hostname($id, $anything) {
	$lines = file('cache/'.$id.'_gq_hostname_tmp.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = substr(strstr("$response", " "), 1);
	$response = str_replace('' . PHP_EOL . '', '', $response);
	return $response;
}

function read_server_val_tmp_gq_numplayers($id, $anything) {
	$lines = file('cache/'.$id.'_gq_numplayers_tmp.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = substr(strstr("$response", " "), 1);
	$response = str_replace('' . PHP_EOL . '', '', $response);
	return $response;
}

function read_server_val_tmp_gq_maxplayers($id, $anything) {
	$lines = file('cache/'.$id.'_gq_maxplayers_tmp.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = substr(strstr("$response", " "), 1);
	$response = str_replace('' . PHP_EOL . '', '', $response);
	return $response;
}

function read_server_val_tmp_gq_mapname($id, $anything) {
	$lines = file('cache/'.$id.'_gq_mapname_tmp.txt');
	foreach($lines as $line) {
		$cl = explode("#", $line);
		$cl = $cl[1];
		$cl = explode(":", $cl);
		$cl = $cl[0];
		if (strcmp($cl, $anything) == 0) {
			$response = $line;
		}
	}
	$response = substr(strstr("$response", " "), 1);
	$response = str_replace('' . PHP_EOL . '', '', $response);
	return $response;
}

print_results($results);

?>