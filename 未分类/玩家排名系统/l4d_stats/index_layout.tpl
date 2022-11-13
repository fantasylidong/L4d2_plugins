<!doctype html>
<html lang="en">
	<head>
		<title><?php echo $site_name;?> | <?php echo $site_game;?></title>
	<?php include('_source/header.php');?>
	<br />
	<div class="row d-flex align-items-center">
		<div class="col-md-12 col-lg-12 text-left text-md-left mb-12 mb-md-0">
			<h1 class="text-left"><small><?php echo $site_name;?></small></h1>
			<small><i class="fa fa-sitemap"></i>&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_url;?>"><?php echo $site_name;?></a>&nbsp;&nbsp;/&nbsp;&nbsp;<a class="alink-main" href="<?php echo $site_statsurl;?>"><?php echo $site_game;?></a></small>
						<br /><br /><div class="bg-main" style="height: 5px;"></div>
					</div>
				</div>
				<br /><br />
				<div class="content-top text-center text-md-left" style="background-color: #f2f2f2;">
					<div class="row">
						<div class="col-md-4">
							<div class="card mb-4 bg-main box-animated rounded-0">
								<div class="card-body rounded-0 text-center">
									<img src="_source/images/icon_survivors.png" alt="survivors">
									<h4 class="timer count-title count-number" data-to="<?php foreach ($carousel_spieler as $title => $value): ?><?php echo ($value);?><?php endforeach; ?>" data-speed="2400">&nbsp; </h4><br />
									Players Participated
								</div>
							</div>
						</div>
						<div class="col-md-4">
							<div class="card mb-4 bg-main box-animated rounded-0">
								<div class="card-body rounded-0 text-center">
									<img src="_source/images/icon_infected.png" alt="infected">
									<h4 class="timer count-title count-number" data-to="<?php foreach ($carousel_infected_kills as $title => $value): ?><?php echo ($value);?><?php endforeach; ?>" data-speed="2400">&nbsp; </h4><br />
									Infected Destroyed
								</div>
							</div>
						</div>
						<div class="col-md-4">
							<div class="card mb-4 bg-main box-animated rounded-0">
								<div class="card-body rounded-0 text-center">
									<img src="_source/images/icon_headshot.png" alt="headshot">
									<h4 class="timer count-title count-number" data-to="<?php foreach ($carousel_headshots as $title => $value): ?><?php echo ($value);?><?php endforeach; ?>" data-speed="2400">&nbsp; </h4><br />
									Headshots Scored
								</div>
							</div>
						</div>
					</div>
				</div>
				<br />
				<?php if ($site_welcome_intro == "") {
					echo "<div class=\"card rounded-0\"><div class=\"card-body\"><div class=\"row d-flex align-items-top\"><div class=\"w-100 px-3 text-left text-md-left\"><h5 class=\"card-title\">Welcome</h5>$site_welcome</div></div></div></div>"; }
					else { echo "<div class=\"card rounded-0\"><div class=\"card-body\"><div class=\"row d-flex align-items-top\"><div class=\"w-50 px-3 text-left text-md-left\"><h5 class=\"card-title\">Welcome</h5>$site_welcome</div><div class=\"w-50 px-3 text-right text-md-right\"><video playsinline=\"playsinline\" autoplay=\"autoplay\" muted=\"muted\" loop=\"loop\" width=\"100%\"><source src=\"$site_welcome_intro\" type=\"video/mp4\"></video></div></div></div></div>"; }
				?>
				<br /><br />
				<?php if ($youtube == "enabled"): ?><?php include('_source/youtube.php');?><?php endif; ?>
				<?php if ($gameserver == "disabled"): ?><div class="card rounded-0"><div class="no-more-tables"><h5>&nbsp;<br />&nbsp;&nbsp;&nbsp; <?php echo $page_heading;?><br /><br /></h5><?php echo $body;?></div></div><br /><br /><?php endif; ?>
			</div>
<?php include('_source/footer.php');?>