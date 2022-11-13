<?php

/****************************************************************************

   LEFT 4 DEAD (2) PLAYER STATISTICS ©2019-2020 PRIMEAS.DE
   BASED ON THE PLUGIN FROM MUUKIS MODIFIED BY FOXHOUND FOR SOURCEMOD

 - https://forums.alliedmods.net/showthread.php?p=2678290#post2678290
 - https://www.primeas.de/

****************************************************************************/

//ini_set('display_errors',1);
//error_reporting(E_ALL);
error_reporting(0);

$award_ppm = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is The Most Efficient Player with <b>%s Points Per Minute</b>.</h6>";
$award_time = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> has the most total playtime with <b>%s of Play</b>.</h6>";
$award_second = "<a class=\"alink-link2 text-left\" href=\"../ranking/%s\">%s</a> came in %s with <b>%s</b>.";
$award_kills = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is The Real Chicago Ted with <b>%s Total Kills</b>.</h6>";
$award_headshots = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> can Aim For The Top with <b>%s Headshots</b>.</h6>";
$award_ratio = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is The Headshot King with a <b>%s&#37; Headshot Ratio</b>.</h6>";
$award_melee_kills = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is The Martial Artist with <b>%s Total Melee Kills</b>.</h6>";
$award_killsurvivor = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> Masters The Life Of The Undead with <b>%s Survivor</b> kills.</h6>";
$award_killinfected = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> can Kill Anyone He Wants with <b>%s Common Infected</b> kills.</h6>";
$award_killhunter = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> Moves Like They Do with <b>%s Hunter</b> kills.</h6>";
$award_killsmoker = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is In The Non-Smoking Section with <b>%s Smoker</b> kills.</h6>";
$award_killboomer = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is a Weight Loss Trainer with <b>%s Boomer</b> kills.</h6>";
$award_killspitter = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> Don't Like Zombies Without Manners with <b>%s Spitter</b> kills.</h6>";
$award_killjockey = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> Likes To Be On Top with <b>%s Jockey</b> kills.</h6>";
$award_killcharger = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> Don't Like To Be Pushed Around with <b>%s Charger</b> kills.</h6>";
$award_pills = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> says The First Hit Is Free with <b>%s Pain Pills Given</b>.</h6>";
$award_medkit = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Wishing He Had A Medigun with <b>%s Medkits Used on Teammates</b>.</h6>";
$award_hunter = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Johnny On The Spot by <b>Saving %s Pounced Teammates From Hunters</b>.</h6>";
$award_smoker = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Into Anime, But Not Like That by <b>Saving %s Teammates From Smokers</b>.</h6>";
$award_jockey = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is The Freedom Fighter by <b>Saving %s Teammates From Jockeys</b>.</h6>";
$award_charger = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Giving Hell To Bullies <b>Saving %s Teammates From Chargers</b>.</h6>";
$award_protect = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Saving Your Ass with <b>%s Teammates Protected</b>.</h6>";
$award_revive = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is There When You Need Him by <b>Reviving %s Teammates</b>.</h6>";
$award_rescue = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Checking All The Closets with <b>%s Teammates Rescued</b>.</h6>";
$award_campaigns = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Getting Rescued... Again! with <b>%s Campaigns Completed</b>.</h6>";
$award_tankkill = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Bringing Down The House by <b>Team Assisting %s Tank Kills</b>.</h6>";
$award_tankkillnodeaths = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Bringing Superior Firepower by <b>Team Assisting %s Tank Kills, With No Deaths</b>.</h6>";
$award_allinsafehouse = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Leaving No Man Behind with <b>%s Safe Houses Reached With All Survivors</b>.</h6>";
$award_friendlyfire = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is A Terrible Friend with <b>%s Friendly Fire Incidents</b>.</h6>";
$award_teamkill = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Going To Be Banned, BRB with <b>%s Team Kills</b>.</h6>";
$award_fincap = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Not Very Friendly with <b>%s Team Incapacitations</b>.</h6>";
$award_left4dead = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> will Leave You For Dead by <b>Allowing %s Teammates To Die In Sight</b>.</h6>";
$award_letinsafehouse = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Turning Into One Of Them with <b>%s Infected Let In The Safe Room</b>.</h6>";
$award_witchdisturb = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Not A Lady Pleaser by <b>Disturbing %s Witches</b>.</h6>";
$award_pounce_nice = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Pain From Above with <b>%s Hunter Nice Pounces</b>.</h6>";
$award_pounce_perfect = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Death From Above with <b>%s Hunter Perfect Pounces</b>.</h6>";
$award_perfect_blindness = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is A Pain Painter causing <b>%s Times Perfect Blindness With A Boomer</b>.</h6>";
$award_infected_win = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is Driving Survivors In To Extinction with <b>%s Infected Victories</b>.</h6>";
$award_bulldozer = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is A Tank Bulldozer inflicting <b>Massive Damage %s Times To The Survivors</b>.</h6>";
$award_survivor_down = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> puts Survivors On Their Knees with <b>%s Incapacitations</b>.</h6>";
$award_ledgegrab = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> wants Survivors Of The Map causing <b>%s Survivors Grabbing On The Ledge</b>.</h6>";
$award_matador = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is The Matador with <b>%s Leveled Charges</b>.</h6>";
$award_witchcrowned = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> Knows How To Handle Women with <b>%s Crowned Witches</b>.</h6>";
$infected_tanksniper = "<h6><a class=\"alink-link2\" href=\"../ranking/%s\">%s</a> is A Tank Sniper hitting <b>%s Survivors With A Rock</b>.</h6>";

?>
