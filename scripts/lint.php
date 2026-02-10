#!/usr/bin/env php
<?php
/**
 * Sistema de Linting Inteligente
 *
 * Este script detecta archivos modificados o en stage y ejecuta
 * los linters apropiados solo en esos archivos.
 *
 * Uso: php scripts/lint.php
 */

class LintRunner
{
    private $projectRoot;
    private $phpFiles = [];
    private $jsFiles = [];
    private $errors = [];
    private $warnings = [];

    public function __construct()
    {
        $this->projectRoot = dirname(__DIR__);
    }

    /**
     * Ejecuta el proceso completo de linting
     */
    public function run(): int
    {
        $this->printHeader();

        // Detectar archivos modificados
        $modifiedFiles = $this->getModifiedFiles();

        if (empty($modifiedFiles)) {
            $this->printInfo("✓ No hay archivos modificados para validar");
            return 0;
        }

        $this->printInfo("Archivos detectados: " . count($modifiedFiles));

        // Clasificar archivos por tipo
        $this->classifyFiles($modifiedFiles);

        // Mostrar archivos a validar
        $this->printFilesToLint();

        // Ejecutar linters
        $hasErrors = false;

        if (!empty($this->phpFiles)) {
            $hasErrors = $this->lintPhpFiles() || $hasErrors;
        }

        if (!empty($this->jsFiles)) {
            $hasErrors = $this->lintJsFiles() || $hasErrors;
        }

        // Mostrar resumen
        $this->printSummary($hasErrors);

        return $hasErrors ? 1 : 0;
    }

    /**
     * Obtiene la lista de archivos modificados desde git
     */
    private function getModifiedFiles(): array
    {
        $files = [];

        // Archivos modificados no staged
        exec('git diff --name-only --diff-filter=ACMR 2>/dev/null', $unstaged);

        // Archivos en stage
        exec('git diff --cached --name-only --diff-filter=ACMR 2>/dev/null', $staged);

        // Combinar y eliminar duplicados
        $files = array_unique(array_merge($unstaged, $staged));

        // Filtrar solo archivos que existen
        return array_filter($files, function ($file) {
            return file_exists($this->projectRoot . '/' . $file);
        });
    }

    /**
     * Clasifica archivos por extensión
     */
    private function classifyFiles(array $files): void
    {
        foreach ($files as $file) {
            $extension = pathinfo($file, PATHINFO_EXTENSION);

            if ($extension === 'php') {
                $this->phpFiles[] = $file;
            } elseif ($extension === 'js') {
                $this->jsFiles[] = $file;
            }
        }
    }

    /**
     * Ejecuta PHPCS en archivos PHP
     */
    private function lintPhpFiles(): bool
    {
        $this->printSection("Validando archivos PHP");

        $phpcsPath = $this->projectRoot . '/vendor/bin/phpcs';

        if (!file_exists($phpcsPath)) {
            $this->printError("PHPCS no está instalado. Ejecuta: composer install");
            return true;
        }

        $configPath = $this->projectRoot . '/config/phpcs.xml';
        $filesString = implode(' ', array_map(function ($file) {
            return escapeshellarg($this->projectRoot . '/' . $file);
        }, $this->phpFiles));

        $command = sprintf(
            '%s --standard=%s %s 2>&1',
            escapeshellarg($phpcsPath),
            escapeshellarg($configPath),
            $filesString
        );

        exec($command, $output, $exitCode);

        if ($exitCode !== 0) {
            foreach ($output as $line) {
                echo "  " . $line . "\n";
            }
            $this->errors[] = 'PHP';
            return true;
        }

        $this->printSuccess("✓ Todos los archivos PHP pasaron las validaciones");
        return false;
    }

    /**
     * Ejecuta ESLint en archivos JS
     */
    private function lintJsFiles(): bool
    {
        $this->printSection("Validando archivos JavaScript");

        $eslintPath = $this->projectRoot . '/node_modules/.bin/eslint';

        if (!file_exists($eslintPath)) {
            $this->printError("ESLint no está instalado. Ejecuta: npm install");
            return true;
        }

        $hasErrors = false;

        foreach ($this->jsFiles as $jsFile) {
            $fullPath = $this->projectRoot . '/' . $jsFile;
            $result = $this->lintJsFile($jsFile, $fullPath, $eslintPath);
            $hasErrors = $result || $hasErrors;
        }

        if (!$hasErrors) {
            $this->printSuccess("✓ Todos los archivos JS pasaron las validaciones");
        }

        return $hasErrors;
    }

    /**
     * Valida un archivo JS individual
     * Maneja archivos con <?php en el header
     */
    private function lintJsFile(string $relativePath, string $fullPath, string $eslintPath): bool
    {
        $content = file_get_contents($fullPath);
        $tempFile = null;
        $phpHeaderLines = 0;

        // Detectar si tiene header PHP
        if (preg_match('/^<\?php.*?\?>/s', $content, $matches)) {
            // Contar líneas del header PHP
            $phpHeaderLines = substr_count($matches[0], "\n");

            // Crear archivo temporal sin el header PHP
            $cleanContent = preg_replace('/^<\?php.*?\?>\s*/s', '', $content);
            $tempFile = tempnam(sys_get_temp_dir(), 'lint_js_');
            file_put_contents($tempFile, $cleanContent);

            $fileToLint = $tempFile;
            $this->printInfo("  → $relativePath (contiene <?php header, líneas PHP: " . ($phpHeaderLines + 1) . ")");
        } else {
            $fileToLint = $fullPath;
            $this->printInfo("  → $relativePath");
        }

        $configPath = $this->projectRoot . '/config/.eslintrc.json';
        $command = sprintf(
            '%s -c %s %s 2>&1',
            escapeshellarg($eslintPath),
            escapeshellarg($configPath),
            escapeshellarg($fileToLint)
        );

        exec($command, $output, $exitCode);

        // Limpiar archivo temporal
        if ($tempFile) {
            unlink($tempFile);
        }

        if ($exitCode !== 0) {
            // Ajustar números de línea si había header PHP
            foreach ($output as $line) {
                if ($tempFile && preg_match('/^.*?:(\d+)/', $line, $matches)) {
                    $originalLine = (int)$matches[1] + $phpHeaderLines + 1;
                    $line = preg_replace('/^(.*?:)\d+/', '$1' . $originalLine, $line);
                }
                echo "    " . $line . "\n";
            }

            $this->errors[] = 'JS: ' . $relativePath;
            return true;
        }

        return false;
    }

    /**
     * Imprime header del script
     */
    private function printHeader(): void
    {
        echo "\n";
        echo "╔════════════════════════════════════════╗\n";
        echo "║   Sistema de Linting Inteligente      ║\n";
        echo "║   Validación de archivos modificados   ║\n";
        echo "╚════════════════════════════════════════╝\n";
        echo "\n";
    }

    /**
     * Muestra los archivos que se van a validar
     */
    private function printFilesToLint(): void
    {
        if (!empty($this->phpFiles)) {
            echo "\n📝 Archivos PHP a validar (" . count($this->phpFiles) . "):\n";
            foreach ($this->phpFiles as $file) {
                echo "  - $file\n";
            }
        }

        if (!empty($this->jsFiles)) {
            echo "\n📝 Archivos JS a validar (" . count($this->jsFiles) . "):\n";
            foreach ($this->jsFiles as $file) {
                echo "  - $file\n";
            }
        }

        echo "\n";
    }

    /**
     * Imprime sección
     */
    private function printSection(string $title): void
    {
        echo "\n" . str_repeat("─", 50) . "\n";
        echo "  $title\n";
        echo str_repeat("─", 50) . "\n";
    }

    /**
     * Imprime mensaje de éxito
     */
    private function printSuccess(string $message): void
    {
        echo "\033[32m$message\033[0m\n";
    }

    /**
     * Imprime mensaje de error
     */
    private function printError(string $message): void
    {
        echo "\033[31m✗ $message\033[0m\n";
    }

    /**
     * Imprime mensaje de info
     */
    private function printInfo(string $message): void
    {
        echo "\033[36m$message\033[0m\n";
    }

    /**
     * Imprime resumen final
     */
    private function printSummary(bool $hasErrors): void
    {
        echo "\n";
        echo str_repeat("═", 50) . "\n";

        if ($hasErrors) {
            $this->printError("✗ LINTING FALLÓ");
            echo "\nArchivos con errores:\n";
            foreach ($this->errors as $error) {
                echo "  ✗ $error\n";
            }
            echo "\n";
            echo "Por favor corrige los errores antes de hacer commit.\n";
        } else {
            $this->printSuccess("✓ LINTING EXITOSO");
            echo "\nTodos los archivos modificados pasaron las validaciones.\n";
        }

        echo str_repeat("═", 50) . "\n";
        echo "\n";
    }
}

// Ejecutar el linter
$linter = new LintRunner();
exit($linter->run());
