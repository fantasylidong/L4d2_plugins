<!doctype html>
<html lang="en">
	<head>
		<title><?php echo $site_name;?> | <?php echo $site_game;?> - <?php echo $page_heading;?></title>
	<?php include('../_source/header.php');?>
	<div class="row py-4 d-flex align-items-center">
		<div class="col-md-8 col-lg-8 text-left text-md-left mb-4 mb-md-0">
			<h1 class="text-left"><small><?php echo $page_heading;?></small></h1>
			<small><i class="fa fa-sitemap"></i>&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_url;?>"><?php echo $site_name;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>"><?php echo $site_game;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="#"><?php echo $page_heading;?></a></small>
		</div>
		<div class="col-md-4 col-lg-4 text-center text-md-right">
			<form method="post" action="search.php">
				<div class="input-group">
					<input type="search" placeholder="Player Name or Steam ID" aria-describedby="button-addon5" class="form-control rounded-0 w-50 search" name="search">&nbsp;&nbsp;&nbsp;
					<button id="button-addon5" type="submit" class="btn btn-main2 rounded-0" ><i class="fa fa-search"></i></button>
				</div>
			</form>
		</div>
	</div>
	<div class="bg-main" style="height: 5px;"></div><br /><br />
	<?php if ($top3_site == "enabled"): ?>
		<div class="content-top text-center text-md-left" style="background-color: #f2f2f2;">
			<div class="row">
				<div class="col-md-4">
					<div class="card mb-4 bg-main box-animated rounded-0 steamprofile_avatar_top_legendary" onclick="window.location='<?php foreach ($top1_href as $text): ?><?php echo $text;?><?php endforeach; ?>'" style="cursor:pointer">
						<div class="card-body rounded-0 text-center">
							<?php foreach ($top1 as $text): ?><?php echo $text;?><?php endforeach; ?>
						</div>
					</div>
				</div>
				<div class="col-md-4">
					<div class="card mb-4 bg-main box-animated rounded-0 steamprofile_avatar_top_epic" onclick="window.location='<?php foreach ($top2_href as $text): ?><?php echo $text;?><?php endforeach; ?>'" style="cursor:pointer">
						<div class="card-body rounded-0 text-center">
							<?php foreach ($top2 as $text): ?><?php echo $text;?><?php endforeach; ?>
						</div>
					</div>
				</div>
				<div class="col-md-4">
					<div class="card mb-4 bg-main box-animated rounded-0 steamprofile_avatar_top_rare" onclick="window.location='<?php foreach ($top3_href as $text): ?><?php echo $text;?><?php endforeach; ?>'" style="cursor:pointer">
						<div class="card-body rounded-0 text-center">
							<?php foreach ($top3 as $text): ?><?php echo $text;?><?php endforeach; ?>
						</div>
					</div>
				</div>
			</div>
		</div>
		<br />
	<?php endif; ?>
	<?php echo $body;?>
	<div class="text-right text-md-right">
		<div class="row d-flex align-items-right">
			<div class="col-md-2 col-lg-2 text-center text-md-left my-auto">
				<small>Page: <?php echo $page_now;?> / <?php echo $page_max;?></small>
			</div>
			<div class="col-md-10 col-lg-10 text-center text-md-right">
				<?php echo $page_pagination;?>
			</div>
		</div>
	</div>
</br>
</div>
<?php include('../_source/footer.php');?>