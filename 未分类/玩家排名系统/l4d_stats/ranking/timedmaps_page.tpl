<div class="card rounded-0">
	<br />
	<div class="row">
		<div class="col-sm-6 text-uppercase text-center my-auto">
			<h5 class="card-title"><?php echo $page_subject;?></h5>
		</div>
		<div class="col-sm-6 text-center my-auto">
			<img class="img-border" src="../_source/images/campaign/<?php echo $page_subject = str_replace(" ", "", $page_subject); ?>.jpg" alt="<?php echo $page_subject;?>">
		</div>
	</div>
	<br />
	<?php echo $page_body;?>
</div>
<br /><br />

