<?php foreach ($arr_achievements as $achievement): ?><?php echo $achievement;?><?php endforeach;?>
<br />
<div class="card-deck">
	<div class="card rounded-0">
		<div class="card-body">
			<h5 class="card-title">Information</h5>
			<table class="table content-table-noborder text-left">
				<tr>
					<td class="w-50">Steam Name:</td>
					<td class="w-50"><?php echo $player_name;?></td>
				</tr>
				<tr>
					<td class="w-50" style="vertical-align:middle;">Steam Avatar:</td>
					<td class="w-50"><?php echo"<div class=\"steamprofile\" title=" . $player_steamid . "></div>";?></td>
				</tr>
				<tr onclick="window.open('http://steamcommunity.com/profiles/<?php echo $player_url;?>','_blank','');" style="cursor:pointer">
					<td class="w-50">Steam ID:</td>
					<td class="w-50"><?php echo $player_steamid;?></td>
				</tr>
				<tr>
					<td class="w-50">Playtime:</td>
					<td class="w-50"><?php echo $player_playtime;?></td>
				</tr>
				<tr>
					<td class="w-50">Last Online:</td>
					<td class="w-50"><?php echo $player_lastonline;?></td>
				</tr>
			</table>
		</div>
	</div>
	<br /><br />
	<div class="card rounded-0">
		<div class="card-body">
			<h5 class="card-title">Statistics</h5>
				<table class="table content-table-noborder text-left">
					<tr>
						<td class="w-50">Rank:</td>
						<td class="w-50"><?php echo $player_rank;?></td>
					</tr>
					<tr>
						<td class="w-50">Points:</td>
						<td class="w-50"><?php echo $player_points;?></td>
					</tr>
					<tr>
						<td class="w-50">Points per Minute:</td>
						<td class="w-50"><?php echo $player_ppm;?></td>
					</tr>
					<tr>
						<td class="w-50">Infected destroyed:</td>
						<td class="w-50"><?php echo $infected_killed;?></td>
					</tr>
					<tr>
						<td class="w-50">Survivors destroyed:</td>
						<td class="w-50"><?php echo $survivors_killed;?></td>
					</tr>
					<tr>
						<td class="w-50">Headshots:</td>
						<td class="w-50"><?php echo $player_headshots;?></td>
					</tr>
					<tr>
						<td class="w-50">Headshot Ratio:</td>
						<td class="w-50"><?php echo $player_ratio;?> %</td>
					</tr>
					<tr onclick="window.location='timedmaps.php?steamid=<?php echo $player_steamid;?>'" style="cursor:pointer">
						<td class="w-50">Timed Rounds:</td>
						<td class="w-50"><?php echo $player_timedmaps;?></td>
					</tr>
				</table>
			</div>
		</div>
	</div>
	<br /><br />
	<div class="card-deck">
		<div class="card rounded-0">
			<div class="card-body">
				<h5 class="card-title">Teamplayer Demerits</h5>
					<table class="table content-table-noborder text-left">
						<?php foreach ($arr_demerits as $title => $arr): ?>
							<tr>
								<td class="w-50"><?php echo $title;?></td>
								<td class="w-50"><?php echo number_format($arr[0]);?></td>
							</tr>
						<?php endforeach;?>
					</table>
				</div>
			</div>
			<br /><br />
			<div class="card rounded-0">
				<div class="card-body">
					<h5 class="card-title">Points per Minute as Infected</h5>
					<table class="table content-table-noborder text-left">
						<tr>
							<td class="w-50">Smoker:</td>
							<td class="w-50"><?php echo $player_avg_smoker;?></td>
						</tr>
						<tr>
							<td class="w-50">Boomer:</td>
							<td class="w-50"><?php echo $player_avg_boomer;?></td>
						</tr>
						<tr>
							<td class="w-50">Hunter:</td>
							<td class="w-50"><?php echo $player_avg_hunter;?></td>
						</tr>
						<?php echo $l4d2_special_infected;?>
						<tr>
							<td class="w-50">Tank:</td>
							<td class="w-50"><?php echo $player_avg_tank;?></td>
						</tr>
					</table>
				</div>
			</div>
		</div>
		<br /><br />
		<div class="card rounded-0">
			<div class="card-body">
				<h5 class="card-title text-left">Awards as Survivor</h5>
				<table class="table content-table-noborder text-left">
					<?php foreach ($arr_survivor_awards as $award => $arr): ?>
						<tr>
							<td class="w-50"><?php echo $award;?></td>
							<td class="w-50"><?php echo number_format($arr[0]);?></td>
						</tr>
					<?php endforeach;?>
				</table>
			</div>
		</div>
		<br /><br />
		<div class="card rounded-0">
			<div class="card-body">
				<h5 class="card-title text-left">Awards as Infected</h5>
				<table class="table content-table-noborder text-left">
					<?php foreach ($arr_infected_awards as $title => $arr): ?>
						<tr>
							<td class="w-50"><?php echo $title;?></td>
							<td class="w-50"><?php echo number_format($arr[0]);?></td>
						</tr>
					<?php endforeach;?>
				</table>
			</div>
		</div>