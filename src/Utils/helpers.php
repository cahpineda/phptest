<?php
// Funciones globales legacy - simula código antiguo del monolito

function sanitize_input($data) {
    return htmlspecialchars(strip_tags(trim($data)));
}

function format_date($timestamp){
    return date('Y-m-d H:i:s',$timestamp);
}

// Función sin usar que podría causar warnings
function old_debug_function($var){
    echo "<pre>";
    print_r($var);
    echo "</pre>";
}

function validate_email($email)
{
    return filter_var($email,FILTER_VALIDATE_EMAIL);
}

// Función legacy con SQL directo
function get_user_by_email($email,$db){
    $query="SELECT * FROM users WHERE email='$email'";
    return $db->query($query);
}
