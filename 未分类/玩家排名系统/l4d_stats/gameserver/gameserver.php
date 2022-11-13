<?php

/****************************************************************************

   LEFT 4 DEAD (2) PLAYER STATISTICS ©2019-2020 PRIMEAS.DE
   BASED ON THE PLUGIN FROM MUUKIS MODIFIED BY FOXHOUND FOR SOURCEMOD

 - https://forums.alliedmods.net/showthread.php?p=2678290#post2678290
 - https://www.primeas.de/

****************************************************************************/

if ($server1_ip == "") { }
else {
	$server = "Server1";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">1</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server1_ip:$server1_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server1_ip:$server1_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">1</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server1_ip:$server1_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server2_ip == "") { }
else {
	$server = "Server2";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">2</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server2_ip:$server2_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server2_ip:$server2_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">2</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server2_ip:$server2_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server3_ip == "") { }
else {
	$server = "Server3";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">3</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server3_ip:$server3_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server3_ip:$server3_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">3</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server3_ip:$server3_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server4_ip == "") { }
else {
	$server = "Server4";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">4</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server4_ip:$server4_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server4_ip:$server4_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">4</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server4_ip:$server4_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server5_ip == "") { }
else {
	$server = "Server5";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">5</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server5_ip:$server5_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server5_ip:$server5_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">5</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server5_ip:$server5_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server6_ip == "") { }
else {
	$server = "Server6";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">6</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server6_ip:$server6_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server6_ip:$server6_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">6</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server6_ip:$server6_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server7_ip == "") { }
else {
	$server = "Server7";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">7</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server7_ip:$server7_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server7_ip:$server7_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">7</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server7_ip:$server7_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server8_ip == "") { }
else {
	$server = "Server8";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">8</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server8_ip:$server8_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server8_ip:$server8_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">8</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server8_ip:$server8_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server9_ip == "") { }
else {
	$server = "Server9";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">9</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server9_ip:$server9_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server9_ip:$server9_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">9</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server9_ip:$server9_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server10_ip == "") { }
else {
	$server = "Server10";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">10</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server10_ip:$server10_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server10_ip:$server10_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">10</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server10_ip:$server10_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server11_ip == "") { }
else {
	$server = "Server11";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">11</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server11_ip:$server11_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server11_ip:$server11_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">11</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server11_ip:$server11_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server12_ip == "") { }
else {
	$server = "Server12";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">12</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server12_ip:$server12_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server12_ip:$server12_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">12</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server12_ip:$server12_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server13_ip == "") { }
else {
	$server = "Server13";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">13</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server13_ip:$server13_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server13_ip:$server13_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">13</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server13_ip:$server13_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server14_ip == "") { }
else {
	$server = "Server14";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">14</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server14_ip:$server14_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server14_ip:$server14_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">14</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server14_ip:$server14_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

if ($server15_ip == "") { }
else {
	$server = "Server15";
	$online = read_server_val_tmp_online($server, 'gq_online'); if ($online == 1) { $online = "Online"; } else { $online = "Offline"; };
	if ($online == "Online") {
		$hostname = read_server_val_tmp_hostname($server, 'gq_hostname');
		$numplayers = read_server_val_tmp_gq_numplayers($server, 'gq_numplayers');
		$maxplayers = read_server_val_tmp_gq_maxplayers($server, 'gq_maxplayers');
		$mapname = read_server_val_tmp_gq_mapname($server, 'gq_mapname');
		echo "<tr><td data-title=\"Server:\">15</td><td data-title=\"Status:\"><span style=\"color: green;\">Online</span></td><td data-title=\"IP:\">$server15_ip:$server15_port</td><td data-title=\"Hostname:\">$hostname</td><td data-title=\"Player:\">$numplayers / $maxplayers</td><td data-title=\"Map:\">$mapname</td><td class=\"text-left\" data-title=\"Settings:\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\" data-target=\"#$server\"><i class=\"fa fa-cogs\"></i></button></td><td class=\"text-left\" data-title=\"Connect:\" onclick=\"window.location='steam://connect/$server15_ip:$server15_port'\" style=\"cursor:pointer\" data-placement=\"bottom\"><button type=\"button\" data-toggle=\"modal\" class=\"btn btn-no\"><i class=\"fa fa-sign-in\"></i></button></td></tr>";
		echo "<div class=\"modal fade\" id=\"$server\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"exampleModalLongTitle\" aria-hidden=\"true\"><div class=\"modal-dialog\" role=\"document\"><div class=\"modal-content\"><div class=\"modal-header\"><h5 class=\"modal-title\" id=\"exampleModalLongTitle\">Settings ($server)</h5><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"false\">×</span></button></div><div class=\"modal-body\">";
		foreach(file("cache/$server.txt") as $line) { $line = str_replace("\n", '', $line); echo "$line<br />"; }
		echo "</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn rounded-0 btn-main2\" data-dismiss=\"modal\">Close</button></div></div></div></div>";
	}
	else { echo "<tr><td data-title=\"Server:\">15</td><td data-title=\"Status:\"><span style=\"color: red;\">Offline</span></td><td data-title=\"IP:\">$server15_ip:$server15_port</td><td data-title=\"Hostname:\">-</td><td data-title=\"Player:\">-</td><td data-title=\"Map:\">-</td><td data-title=\"Settings:\">-</td><td data-title=\"Connect:\">-</td></tr>"; }
}

?>