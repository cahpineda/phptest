#!/usr/bin/env php
<?php
/**
 * Script de instalación automatizado
 * Instala dependencias sin necesidad de tener Composer instalado
 */

class Installer
{
    private $projectRoot;
    private $vendorDir;
    private $binDir;

    public function __construct()
    {
        $this->projectRoot = dirname(__DIR__);
        $this->vendorDir = $this->projectRoot . '/vendor';
        $this->binDir = $this->vendorDir . '/bin';
    }

    public function run(): void
    {
        echo "\n";
        echo "╔════════════════════════════════════════╗\n";
        echo "║  Instalador de Dependencias           ║\n";
        echo "╚════════════════════════════════════════╝\n";
        echo "\n";

        // Verificar si composer existe
        $composerExists = $this->commandExists('composer');

        if ($composerExists) {
            echo "✓ Composer detectado\n";
            echo "  Instalando dependencias PHP con Composer...\n\n";
            passthru('composer install', $exitCode);

            if ($exitCode !== 0) {
                echo "\n✗ Error instalando con Composer\n";
                echo "  Intentando instalación manual...\n\n";
                $this->installPhpCsManually();
            }
        } else {
            echo "ℹ Composer no detectado\n";
            echo "  Procediendo con instalación manual de PHPCS...\n\n";
            $this->installPhpCsManually();
        }

        // Instalar dependencias JavaScript
        echo "\n";
        $this->installJsDependencies();

        // Hacer ejecutable el script de linting
        chmod($this->projectRoot . '/scripts/lint.php', 0755);

        echo "\n";
        echo "╔════════════════════════════════════════╗\n";
        echo "║  Instalación Completada                ║\n";
        echo "╚════════════════════════════════════════╝\n";
        echo "\n";
        echo "Para ejecutar el linter:\n";
        echo "  php scripts/lint.php\n";
        echo "  npm run lint\n";
        echo "\n";
    }

    private function installPhpCsManually(): void
    {
        // Crear directorios
        if (!is_dir($this->vendorDir)) {
            mkdir($this->vendorDir, 0755, true);
        }
        if (!is_dir($this->binDir)) {
            mkdir($this->binDir, 0755, true);
        }

        $phpcsUrl = 'https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar';
        $phpcbfUrl = 'https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar';

        $phpcsPath = $this->binDir . '/phpcs';
        $phpcbfPath = $this->binDir . '/phpcbf';

        echo "  Descargando PHPCS...\n";
        $this->downloadFile($phpcsUrl, $phpcsPath);

        echo "  Descargando PHPCBF...\n";
        $this->downloadFile($phpcbfUrl, $phpcbfPath);

        chmod($phpcsPath, 0755);
        chmod($phpcbfPath, 0755);

        echo "  ✓ PHPCS instalado correctamente\n";
    }

    private function installJsDependencies(): void
    {
        if (!$this->commandExists('npm')) {
            echo "✗ npm no está instalado\n";
            echo "  Por favor instala Node.js/npm desde: https://nodejs.org/\n";
            return;
        }

        echo "✓ npm detectado\n";
        echo "  Instalando dependencias JavaScript...\n\n";

        passthru('npm install', $exitCode);

        if ($exitCode === 0) {
            echo "\n  ✓ Dependencias JavaScript instaladas\n";
        } else {
            echo "\n  ✗ Error instalando dependencias JavaScript\n";
        }
    }

    private function downloadFile(string $url, string $destination): void
    {
        // Intentar con curl primero
        if ($this->commandExists('curl')) {
            exec(sprintf(
                'curl -L %s -o %s 2>&1',
                escapeshellarg($url),
                escapeshellarg($destination)
            ), $output, $exitCode);

            if ($exitCode === 0 && file_exists($destination)) {
                return;
            }
        }

        // Intentar con wget
        if ($this->commandExists('wget')) {
            exec(sprintf(
                'wget %s -O %s 2>&1',
                escapeshellarg($url),
                escapeshellarg($destination)
            ), $output, $exitCode);

            if ($exitCode === 0 && file_exists($destination)) {
                return;
            }
        }

        // Usar file_get_contents como fallback
        echo "  Usando descarga PHP nativa...\n";
        $content = @file_get_contents($url);

        if ($content === false) {
            die("  ✗ Error: No se pudo descargar $url\n");
        }

        file_put_contents($destination, $content);
    }

    private function commandExists(string $command): bool
    {
        $whereIs = stripos(PHP_OS, 'WIN') === 0 ? 'where' : 'which';
        exec("$whereIs $command 2>&1", $output, $exitCode);
        return $exitCode === 0;
    }
}

// Ejecutar instalador
$installer = new Installer();
$installer->run();
