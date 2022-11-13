<?php foreach ($arr_achievements as $achievement): ?><?php echo $achievement;?><?php endforeach;?>
<br />
<div class="card rounded-0">
	<div class="no-more-tables">
		<table class="table">
			<thead class="content-table-noborder bg-main">
				<tr>
					<td rowspan="2">Campaign</td>
					<td rowspan="2">Playtime</td>
					<td rowspan="2">Rounds Lost</td>
					<td colspan="2">Points</td>
					<td colspan="2">Destroyed</td>
				</tr>
				<tr>
					<td><img src="../_source/images/icon_infected.png" alt="infected"></td>
					<td><img src="../_source/images/icon_survivors.png" alt="survivors"></td>
					<td><img src="../_source/images/icon_infected.png" alt="infected"></td>
					<td><img src="../_source/images/icon_survivors.png" alt="survivors"></td>
				</tr>
			</thead>
			<tbody>
				<?php foreach ($maps as $map): ?><?php echo $map;?><?php endforeach; ?>
			</tbody>
		</table>
	</div>
</div>
<br />