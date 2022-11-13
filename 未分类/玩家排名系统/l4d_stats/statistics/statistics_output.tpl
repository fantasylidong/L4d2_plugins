<?php foreach ($arr_achievements as $achievement): ?><?php echo $achievement;?><?php endforeach;?>
<br />
<div class="card-deck">
	<div class="card rounded-0">
		<div class="card-body">
			<h5 class="card-title">Information</h5>
			<table class="table content-table-noborder text-left">
				<tr>
					<td class="w-50">Players:</td>
					<td class="w-50"><?php echo $players;?></td>
				</tr>
				<tr>
					<td class="w-50">Points:</td>
					<td class="w-50"><?php echo $points;?></td>
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
					<td class="w-50"><?php echo $headshots;?></td>
				</tr>
				<tr>
					<td class="w-50">Headshot Ratio:</td>
					<td class="w-50"><?php echo $ratio;?> %</td>
				</tr>
				<tr>
					<td class="w-50">Points per Minute:</td>
					<td class="w-50"><?php echo $player_ppm;?></td>
				</tr>
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
					<td class="w-50"><?php echo $avg_smoker;?></td>
				</tr>
				<tr>
					<td class="w-50">Boomer:</td>
					<td class="w-50"><?php echo $avg_boomer;?></td>
				</tr>
				<tr>
					<td class="w-50">Hunter:</td>
					<td class="w-50"><?php echo $avg_hunter;?></td>
				</tr>
				<?php echo $l4d2_special_infected;?>
				<tr>
					<td class="w-50">Tank:</td>
					<td class="w-50"><?php echo $avg_tank;?></td>
				</tr>
			</table>
		</div>
	</div>
</div>
<br /><br />
<div class="card rounded-0">
	<div class="card-body">
		<h5 class="card-title text-left">Infected Destroyed</h5>
		<table class="table content-table-noborder text-left">
			<?php foreach ($arr_kills as $type => $kills): ?>
				<tr>
					<td class="w-50"><?php echo $type;?></td>
					<td class="w-50"><?php echo number_format($kills);?></td>
				</tr>
				<?php endforeach;?>
		</table>
	</div>
</div>
<br /><br />
<div class="card rounded-0">
	<div class="card-body">
		<h5 class="card-title text-left">Demerits</h5>
		<table class="table content-table-noborder text-left">
			<?php foreach ($arr_demerits as $demerit => $count): ?>
			<tr>
				<td class="w-50"><?php echo $demerit;?></td>
				<td class="w-50"><?php echo number_format($count);?></td>
			</tr>
			<?php endforeach;?>
		</table>
	</div>
</div>
<br /><br />
<div class="card rounded-0">
	<div class="card-body">
		<h5 class="card-title text-left">Awards as Survivor</h5>
		<table class="table content-table-noborder text-left">
			<?php foreach ($arr_survivor_awards as $award => $count): ?>
			<tr>
				<td class="w-50"><?php echo $award;?></td>
				<td class="w-50"><?php echo number_format($count);?></td>
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
			<?php foreach ($arr_infected_awards as $award => $count): ?>
			<tr>
				<td class="w-50"><?php echo $award;?></td>
				<td class="w-50"><?php echo number_format($count);?></td>
			</tr>
			<?php endforeach;?>
		</table>
	</div>
</div>
<br /><br />
<div class="card rounded-0">
	<div class="card-body">
		<h5 class="card-title text-left">Playtime</h5>
		<table class="table content-table-noborder text-left">
			<tr>
				<td class="w-50">Total:</td>
				<td class="w-50"><?php echo $totalplaytime;?></td>
			</tr>
			<?php foreach ($arr_maps as $map): ?>
			<tr>
				<td class="w-50"><?php echo $map['gamemodename'];?>:</td>
				<td class="w-50"><?php echo $map['totalplaytime'];?></td>
			</tr>
			<?php endforeach;?>
		</table>
	</div>
</div>