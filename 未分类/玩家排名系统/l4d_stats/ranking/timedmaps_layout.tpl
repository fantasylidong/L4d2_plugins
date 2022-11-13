<!doctype html>
<html lang="en">
	<head>
		<title><?php echo $site_name;?> | <?php echo $site_game;?> - Player: <?php echo $player_name;?> (<?php echo $page_heading;?>)</title>
	<?php include('../_source/header.php');?>
	<br />
	<div class="row d-flex align-items-center">
		<div class="col-md-12 col-lg-12 text-left text-md-left mb-12 mb-md-0">
			<h1 class="text-left"><small>Player: <?php echo $player_name;?> (Timed Rounds)</small></h1>
			<small><i class="fa fa-sitemap"></i>&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_url;?>"><?php echo $site_name;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>"><?php echo $site_game;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>ranking">Ranking</a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>ranking/player.php?steamid=<?php echo $steam_id;?>">Player: <?php echo $player_name;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="#"><?php echo $page_heading;?></a></small>
			<br /><br /><div class="bg-main" style="height: 5px;"></div>
		</div>
	</div>
	<br /><br />
	<?php echo $body;?>
</div>
<?php include('../_source/footer.php');?>