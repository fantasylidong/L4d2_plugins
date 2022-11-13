<table class="table">
	<thead class="content-table-noborder bg-main">
		<tr>
			<td>Gamemode</td>
			<td>Player</td>
			<td>Points</td>
			<td>Country</td>
			<td>Playtime</td>
		</tr>
	</thead>
	<tbody>
		<?php foreach ($online as $player): ?><?php echo $player; ?><?php endforeach; ?>
	</tbody>
</table>