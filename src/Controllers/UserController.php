<?php
// Este archivo simula código legacy con problemas de estilo

class UserController
{

    private $db;

    function __construct($database)
    {
        $this->db = $database;
    }

    // Método legacy con mal formato
    public function getUser($id)
    {
        $query = "SELECT * FROM users WHERE id=" . $id;
        $result = $this->db->query($query);
        return $result;
    }

    public function createUser($data)
    {
        // Código legacy mezclado con nuevo
        $name = $data['name'];
        $email = $data['email'];

        if (empty($name) || empty($email)) {
            return false;
        }

        $query = "INSERT INTO users (name, email) VALUES ('{$name}', '{$email}')";
        return $this->db->execute($query);
    }

    // Función global estilo legacy (mala práctica)
    public function updateUserStatus($userId, $status)
    {
        $this->db->execute("UPDATE users SET status='$status' WHERE id=$userId");
    }
}
