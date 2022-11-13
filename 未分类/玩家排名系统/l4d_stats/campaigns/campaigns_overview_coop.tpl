<?php foreach ($arr_achievements as $achievement): ?><?php echo $achievement;?><?php endforeach;?>
<br />
<div class="card rounded-0">
	<div class="no-more-tables">
		<table class="table">
			<thead class="content-table-noborder bg-main">
				<tr>
					<td>Campaign</td>
					<td>Playtime</td>
					<td>Points (PPM)</td>
					<td>Destroyed</td>
					<td>Restarts</td>
				</tr>
			</thead>
			<tbody>
				<?php foreach ($maps as $map): ?><?php echo $map;?><?php endforeach; ?>
			</tbody>
		</table>
	</div>
</div>
<br />