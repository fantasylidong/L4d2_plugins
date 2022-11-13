<div class="no-more-tables">
	<table class="table">
		<thead class="content-table-noborder bg-main">
			<tr>
				<td rowspan="2">Difficulty</td>
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
			<tr>
				<td>Normal</td>
				<td><?php echo $playtime[0];?></td>
				<td><?php echo $infected_win[0];?></td>
				<td><?php echo $points_infected[0];?></td>
				<td><?php echo $points[0];?></td>
				<td><?php echo $kills[0];?></td>
				<td><?php echo $survivor_kills[0];?></td>
			</tr>
			<tr>
				<td>Advanced</td>
				<td><?php echo $playtime[1];?></td>
				<td><?php echo $infected_win[1];?></td>
				<td><?php echo $points_infected[1];?></td>
				<td><?php echo $points[1];?></td>
				<td><?php echo $kills[1];?></td>
				<td><?php echo $survivor_kills[1];?></td>
			</tr>
			<tr>
				<td>Expert</td>
				<td><?php echo $playtime[2];?></td>
				<td><?php echo $infected_win[2];?></td>
				<td><?php echo $points_infected[2];?></td>
				<td><?php echo $points[2];?></td>
				<td><?php echo $kills[2];?></td>
				<td><?php echo $survivor_kills[2];?></td>
			</tr>
			<tr>
				<td class="alink-link2">Total:</td>
				<td class="alink-link2"><?php echo $playtime[3];?></td>
				<td class="alink-link2"><?php echo $infected_win[3];?></td>
				<td class="alink-link2"><?php echo $points_infected[3];?></td>
				<td class="alink-link2"><?php echo $points[3];?></td>
				<td class="alink-link2"><?php echo $kills[3];?></td>
				<td class="alink-link2"><?php echo $survivor_kills[3];?></td>
			</tr>
		</tbody>
	</table>
</div>