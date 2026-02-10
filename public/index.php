<?php
// Entry point principal del sistema legacy

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../src/Utils/helpers.php';

// Configuración legacy
define('APP_NAME', 'Legacy Monolith System');
define('APP_VERSION', '1.0.0');

?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo APP_NAME; ?></title>
    <link rel="stylesheet" href="css/styles.css">
</head>
<body>
    <div id="app">
        <h1><?php echo APP_NAME; ?></h1>
        <p>Sistema monolito legacy con linting inteligente</p>
        <div id="content"></div>
    </div>

    <!-- Scripts legacy con PHP -->
    <script src="js/legacy.js"></script>
    <script src="js/app.js"></script>
    <script src="js/modern.js"></script>

    <script>
        // Inicialización
        if (typeof window.globalInit === 'function') {
            window.globalInit();
        }
    </script>
</body>
</html>
