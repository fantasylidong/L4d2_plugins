<!doctype html>
<html lang="en">
	<head>
		<title><?php echo $site_name;?> | <?php echo $site_game;?> - <?php echo $page_heading;?></title>
	<?php include('../_source/header.php');?>
	<div class="row py-4 d-flex align-items-center">
		<div class="col-md-8 col-lg-8 text-left text-md-left mb-4 mb-md-0">
			<h1 class="text-left"><small><?php echo $page_heading;?></small></h1>
			<small><i class="fa fa-sitemap"></i>&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_url;?>"><?php echo $site_name;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>"><?php echo $site_game;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>ranking/search.php"><?php echo $page_heading;?></a></small>
		</div>
		<div class="col-md-4 col-lg-4 text-center text-md-right">
			<form method="post" action="search.php">
				<div class="input-group">
					<input type="search" placeholder="Player or Steam ID" aria-describedby="button-addon5" class="form-control rounded-0 w-50 search" name="search">&nbsp;&nbsp;&nbsp;
					<button id="button-addon5" type="submit" class="btn btn-main2 rounded-0" ><i class="fa fa-search"></i></button>
				</div>
			</form>
		</div>
	</div>
	<div class="bg-main" style="height: 5px;"></div>
	<br /><br />
	<?php echo $body;?>
	<br /><br />
</div>
<?php include('../_source/footer.php');?>