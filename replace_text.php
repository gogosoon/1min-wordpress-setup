<?php

function replace_function(){
$content = file_get_contents("templates/DB.conf");
$replace_value = file_get_contents("out.txt");
$content = str_replace("{SECRET_KEY}", $replace_value, $content);
file_put_contents("templates/DB.conf", $content);
}

