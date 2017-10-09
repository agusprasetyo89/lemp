<!DOCTYPE html>
<html lang="en">
  <head>
    <!-- Required meta tags -->
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

    <!-- Bootstrap CSS -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0-beta/css/bootstrap.min.css" integrity="sha384-/Y6pD6FV/Vv2HJnA6t+vslU6fwYXjCFtcEpHbNJ0lyAFsXTsjBbfaDjzALeQsN6M" crossorigin="anonymous">
  </head>
  <body>
         <a target="_blank" href="https://api.whatsapp.com/send?<?php echo (isset($_REQUEST["phone"])&&$_REQUEST["phone"]!=""?"phone=".$_REQUEST["phone"]."&":""); ?>text=<?php echo $_REQUEST["txt_msg"]; ?>" class="btn btn-<?php echo $_REQUEST["btn"]; ?>"><img src="http://3.bp.blogspot.com/-wqgRFXJ6wGs/Wdsko72y-YI/AAAAAAAAFYw/eQg5dKQveXscb4SYk0Sp-9ZP3wfrYJ7FwCK4BGAYYCw/s1600/1480520219570138315whatsapp_icon.hi.png" height="30">
         <?php echo $_REQUEST["txt_btn"]; ?></a>
  </body>
</html>
