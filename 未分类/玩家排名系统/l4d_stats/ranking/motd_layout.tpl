<!doctype html>
<html lang="en">
	<head>
		<title><?php echo $site_name;?> | <?php echo $site_game;?> - MOTD: <?php echo $page_heading;?></title>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
		<meta name="robots" content="index,follow">
		<meta name="revisit-after" content="7 days">
		<meta name="description" content="<?php echo $site_description;?>">
		<meta name="keywords" content="<?php echo $site_keywords;?>">
		<meta name="url" content="<?php echo $site_statsurl;?>">
		<meta name="copyright" content="<?php echo $site_name;?> | <?php echo $site_url;?>">
		<meta name="design" content="CUSTOM PLAYER STATS V1.4B121 MODERN TEMPLATE © 2019-2020 XEVANIO.DE">
		<meta name="plugin" content="COPYRIGHT © 2010 MUUKIS FOR SOURCEMOD">
		<meta property="og:title" content="<?php echo $site_name;?> | <?php echo $site_game;?> - <?php echo $title;?>">
		<meta property="og:description" content="<?php echo $site_description;?>">
		<meta property="og:url" content="<?php echo $site_statsurl;?>">
		<meta property="og:site_name" content="<?php echo $site_name;?>">
		<meta property="og:image" content="<?php echo $site_statsurl;?>_source/images/favicon.png">
		<link rel="shortcut icon" href="<?php echo $site_statsurl;?>_source/images/favicon.ico">
		<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css" />
		<link rel="stylesheet" href="<?php echo $site_statsurl;?>_source/css/bootstrap.min.css" />
		<link rel="stylesheet" href="<?php echo $site_statsurl;?>_source/css/<?php echo $site_style;?>.css" />
		<script src="<?php echo $site_statsurl;?>_source/js/jquery.js"></script>
		<script src="<?php echo $site_statsurl;?>_source/js/steamprofile.js"></script>
		<script src="<?php echo $site_statsurl;?>_source/js/popper.min.js"></script>
		<script src="<?php echo $site_statsurl;?>_source/js/bootstrap.min.js"></script>
		<script src="<?php echo $site_statsurl;?>_source/js/site.js"></script>
	</head>
	<body>

				<div class="motd text-left px-3 d-flex align-items-center">
					<div class="px-3 w-50 text-left text-md-left">
						<span class="navbar-brand ml-2"><a class="nav-brand2" href="<?php echo $site_statsurl;?>"><?php if ($site_logo == "") { echo $site_name; } else { echo "<img height=\"$site_logo_height\" width=\"$site_logo_width\" src=\"$site_statsurl$site_logo\" alt=\"Logo\">"; } ?></a></span>
					</div>
					<div class="px-3 w-50 text-left text-md-left">
<br /><br />Players Participated: <font class="alink-link2"><?php foreach ($carousel_spieler as $title => $value): ?><?php echo number_format($value);?><?php endforeach; ?></font><br />
		Infected Destroyed: <font class="alink-link2"><?php foreach ($carousel_infected_kills as $title => $value): ?><?php echo number_format($value);?><?php endforeach; ?></font><br />
		Headshots Scored: <font class="alink-link2"><?php foreach ($carousel_headshots as $title => $value): ?><?php echo number_format($value);?><?php endforeach; ?></font>
		<br /><br />
					</div>
				</div>


	<div id="navbar-line" class="bg-main2" style="height: 5px;"></div>
	<div class="content text-center text-md-left px-3" style="background-color: #eeeeee;">
		<br />
		<div class="rounded-0">
			<div class="d-flex align-items-right">
				<div class="col-12 text-right text-md-right">
					<a class="btn rounded-0 btn-main" href="<?php echo $site_statsurl;?>ranking" target="_blank" role="button"><i class="fa fa-bar-chart"></i> Full Player Statistics</a>
					<a class="btn rounded-0 btn-main" href="<?php echo $site_steamgroup;?>" target="_blank" role="button"><i class="fa fa-steam-square"></i> Steam-Group</a>
				</div>
			</div>
		</div>
		<br />
	</div>
	<div class="content text-left px-3" style="background-color: #f2f2f2;">
		<div class="d-flex align-items-left">
			<div class="col-md-12 col-lg-12 text-left text-md-left">
				<h1 class="text-left"><small>Top25 <?php echo $page_heading;?></small></h1><br />
				<?php if ($top3_site == "enabled"): ?>
					<div class="content-top text-center text-md-left" style="background-color: #f2f2f2;">
						<div class="row">
							<div class="col-4">
								<div class="card bg-main box-animated rounded-0 steamprofile_avatar_top_legendary" onclick="window.open('<?php foreach ($top1_href as $text): ?><?php echo $text;?><?php endforeach; ?>')" style="cursor:pointer">
									<div class="card-body rounded-0 text-center">
										<?php foreach ($top1 as $text): ?><?php echo $text;?><?php endforeach; ?>
									</div>
								</div>
							</div>
							<div class="col-4">
								<div class="card bg-main box-animated rounded-0 steamprofile_avatar_top_epic" onclick="window.open('<?php foreach ($top2_href as $text): ?><?php echo $text;?><?php endforeach; ?>')" style="cursor:pointer">
									<div class="card-body rounded-0 text-center">
										<?php foreach ($top2 as $text): ?><?php echo $text;?><?php endforeach; ?>
									</div>
								</div>
							</div>
							<div class="col-4">
								<div class="card bg-main box-animated rounded-0 steamprofile_avatar_top_rare" onclick="window.open('<?php foreach ($top3_href as $text): ?><?php echo $text;?><?php endforeach; ?>')" style="cursor:pointer">
									<div class="card-body rounded-0 text-center">
										<?php foreach ($top3 as $text): ?><?php echo $text;?><?php endforeach; ?>
									</div>
								</div>
							</div>
						</div>
					</div>
					<br />
					<?php if ($top3_glow == "enabled"): ?><i class="fa fa-info-circle"></i> Top 3 Reward: Fight for the Top 3 Position. You get unique Glow Rewards on our Server!<br /><br /><?php endif; ?>
				<?php endif; ?>
			</div>
		</div>
		<?php echo $body;?>
	</div>
	<div class="bg-main2" style="height: 5px;"></div>
	<footer class="footer page-footer bg-main px-3">
		<div class="container text-left text-md-left">
			<div class="row py-4 d-flex align-items-center">
				<div class="col-md-12 col-lg-12 text-right text-md-right">
					<span class="copyright text-uppercase">
							Custom Player Stats v1.4B121 Modern Template © 2019-<?php echo date( "Y"); ?> <a class="alink-main2" href="https://www.xevanio.de/" target="_blank">XEVANIO.DE</a><br />
							Copyright &copy; 2010 <a class="alink-main2" href="http://forums.alliedmods.net/member.php?u=52082" target="_blank">muukis</a> for <a class="alink-main2" href="https://forums.alliedmods.net/showthread.php?p=2678290#post2678290" target="_blank">SourceMod</a>
					</span>
				</div>
			</div>
		</div>
	</footer>
	</body>
</html>