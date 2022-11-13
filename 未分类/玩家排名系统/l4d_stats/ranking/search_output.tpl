<div class="card rounded-0">
	<div class="no-more-tables">
		<table class="table">
			<thead class="content-table-noborder bg-main">
				<tr>
					<td>Result</td>
					<td>Player</td>
					<td>Points</td>
					<td>Country</td>
					<td>Playtime</td>
					<td>Last Online</td>
				</tr>
			</thead>
			<tbody>
				<?php foreach ($online as $player): ?><?php echo $player; ?><?php endforeach; ?>
			</tbody>
		</table>
	</div>
</div>