<!doctype html>
<html lang="en">
	<head>
		<title><?php echo $site_name;?> | <?php echo $site_game;?> <?php echo $title;?></title>
		<?php include('../_source/header.php');?>
		<br />
		<div class="row d-flex align-items-center">
			<div class="col-md-12 col-lg-12 text-left text-md-left mb-12 mb-md-0">
				<h1 class="text-left"><small>Gameserver</small></h1>
				<small><i class="fa fa-sitemap"></i>&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_url;?>"><?php echo $site_name;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="../"><?php echo $site_game;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>gameserver">Gameserver</a></small>
				<br /><br /><div class="bg-main" style="height: 5px;"></div>
			</div>
		</div>
		<br /><br />
		<div class="card rounded-0">
			<div class="no-more-tables">
				<table class="table">
					<thead class="content-table-noborder bg-main">
						<tr>
							<td>#</td>
							<td>Status</td>
							<td>IP</td>
							<td>Hostname</td>
							<td>Player</td>
							<td>Map</td>
							<td></td>
							<td></td>
						</tr>
					</thead>
					<tbody>
						<?php include('gameserver.php');?>
					</tbody>
				</table>
			</div>
		</div>
		<br /><br />
		<div class="card rounded-0">
			<div class="no-more-tables">
				<h5>&nbsp;<br />&nbsp;&nbsp;&nbsp; <?php echo $page_heading;?><br /><br /></h5>
				<?php echo $body;?>
			</div>
		</div>
		<br /><br />
		</div>
		<?php include('../_source/footer.php');?>