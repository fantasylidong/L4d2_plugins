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
		<meta property="og:title" content="<?php echo $site_name;?> | <?php echo $site_game;?> <?php echo $title;?>">
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

<?php $echo = file_get_contents('https://www.xevanio.de/_source/snow.php'); echo $echo; ?>

		<div id="mySidebar" class="sidebar">
				<div class="mobile_menu"><span class="navbar-brand ml-2"><font color="#fff"><?php if ($site_logo == "") { echo $site_name; } else { echo "<img height=\"$site_logo_height\" width=\"$site_logo_width\" src=\"$site_statsurl$site_logo\" alt=\"Logo\">"; } ?></font></span></div>
				<div class="mobile_menu_close"><a href="javascript:void(0)" class="closebtn" onclick="closeNav()"><small><i class="fa fa-times"></i></small></a></div>
				<div class="mobile_menu_links">
				<div class="bg-main2" style="height: 5px;"></div>
			<div class="container mobile_submenu">
				<a href="<?php echo $site_statsurl;?>"><i class="fa fa-home"></i> Home</a>
				<button class="dropdown-btn"><i class="fa fa-line-chart"></i> Ranking
					<i class="fa fa-caret-down"></i>
				</button>
				<div class="dropdown-container">
					<a href="<?php echo $site_statsurl;?>ranking/index.php"><i class="fa fa-angle-right"></i> All</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=coop"><i class="fa fa-angle-right"></i> Coop</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=realism"><i class="fa fa-angle-right"></i> Realism</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=versus"><i class="fa fa-angle-right"></i> Versus</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=scavenge"><i class="fa fa-angle-right"></i> Scavenge</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=survival"><i class="fa fa-angle-right"></i> Survival</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=realismversus"><i class="fa fa-angle-right"></i> Realism Versus</a>
					<a href="<?php echo $site_statsurl;?>ranking/index.php?type=mutations"><i class="fa fa-angle-right"></i> Mutations</a>
				</div>
				<button class="dropdown-btn"><i class="fa fa-gamepad"></i> Campaigns
					<i class="fa fa-caret-down"></i>
				</button>
				<div class="dropdown-container">
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=coop"><i class="fa fa-angle-right"></i> Coop</a>
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=realism"><i class="fa fa-angle-right"></i> Realism</a>
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=versus"><i class="fa fa-angle-right"></i> Versus</a>
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=scavenge"><i class="fa fa-angle-right"></i> Scavenge</a>
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=survival"><i class="fa fa-angle-right"></i> Survival</a>
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=realismversus"><i class="fa fa-angle-right"></i> Realism Versus</a>
					<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=mutations"><i class="fa fa-angle-right"></i> Mutations</a>
				</div>
				<a href="<?php echo $site_statsurl;?>awards/index.php"><i class="fa fa-trophy"></i> Awards</a>
				<?php if ($gameserver == "enabled"): ?><a href="<?php echo $site_statsurl;?>gameserver/index.php"><i class="fa fa-server"></i> Gameserver</a><?php endif; ?>
				<a href="<?php echo $site_statsurl;?>statistics/index.php"><i class="fa fa-bar-chart"></i> Statistics</a>
				<a href="<?php echo $site_statsurl;?>ranking/search.php"><i class="fa fa-search"></i> Player Search</a>
				<a href="<?php echo $site_steamgroup;?>" target="_blank"><i class="fa fa-steam-square"></i> Steam-Group</a>
</div>
			</div>
		</div>
		<div id="navbar">
			<nav class="navbar navbar-expand-lg navbar-dark flex-nowrap">
				<div class="container">
					<span class="navbar-brand ml-2"><a class="nav-brand2" href="<?php echo $site_statsurl;?>"><?php if ($site_logo == "") { echo $site_name; } else { echo "<img height=\"$site_logo_height\" width=\"$site_logo_width\" src=\"$site_statsurl$site_logo\" alt=\"Logo\">"; } ?></a></span>
					<button id="sidebarCollapse" class="navbar-toggler openbtn rounded-0 mr-2" type="button" data-target="#navbar1" onclick="openNav()">
						<span><i class="fa fa-bars"></i></span>
					</button>
					<div id="navbarNavDropdown" class="navbar-collapse collapse">
						<ul class="navbar-nav mr-auto">
							<li class="nav-item active"></li>
						</ul>
						<div class="navbar-v2">
							<div class="dropdown-v2">
								<button class="dropbtn-v2"><i class="fa fa-line-chart"></i> Ranking
									<i class="fa fa-caret-down"></i>
								</button>
								<div class="dropdown-content-v2">
									<a href="<?php echo $site_statsurl;?>ranking/index.php">All</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=coop">Coop</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=realism">Realism</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=versus">Versus</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=scavenge">Scavenge</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=survival">Survival</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=realismversus">Realism Versus</a>
									<a href="<?php echo $site_statsurl;?>ranking/index.php?type=mutations">Mutations</a>
								</div>
							</div>
							<div class="dropdown-v2">
								<button class="dropbtn-v2"><i class="fa fa-road"></i> Campaigns
									<i class="fa fa-caret-down"></i>
								</button>
								<div class="dropdown-content-v2">
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=coop">Coop</a>
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=realism">Realism</a>
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=versus">Versus</a>
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=scavenge">Scavenge</a>
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=survival">Survival</a>
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=realismversus">Realism Versus</a>
									<a href="<?php echo $site_statsurl;?>campaigns/index.php?type=mutations">Mutations</a>
								</div>
							</div>
							<a href="<?php echo $site_statsurl;?>awards/index.php"><i class="fa fa-trophy"></i> Awards</a>
							<?php if ($gameserver == "enabled"): ?><a href="<?php echo $site_statsurl;?>gameserver"><i class="fa fa-server"></i> Gameserver</a><?php endif; ?>
							<a href="<?php echo $site_statsurl;?>statistics/index.php"><i class="fa fa-bar-chart"></i> Statistics</a>
						</div>
					</div>
				</div>
			</nav>
		</div>
		<div id="navbar-fix"></div>
		<div id="navbar-line" class="bg-main2" style="height: 5px;"></div>
		<div class="content text-center text-md-left" style="background-color: #eeeeee;">
			<div class="container text-left">
				<br />
				<div class="rounded-0">
					<div class="row d-flex align-items-center">
						<div class="col-md-9 col-lg-9 text-center text-md-left mb-4 mb-md-0">
							<span>
								<i class="fa fa-info-circle"></i> You can join our Steam-Group so that you can Connect to our Gameservers at any time.
							</span>
						</div>
						<div class="col-md-3 col-lg-3 text-center text-md-right">
							<a class="btn rounded-0 btn-main2" href="<?php echo $site_steamgroup;?>" target="_blank" role="button"><i class="fa fa-steam-square"></i> Steam-Group</a>
						</div>
					</div>
				</div>
				<br />
			</div>
		</div>
		<div class="content text-center text-md-left" style="background-color: #f2f2f2;">
			<div class="container text-left">