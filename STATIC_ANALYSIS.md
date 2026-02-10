# Análisis Estático Avanzado (Opcional)

## Problema

`lint.sh` detecta:
- ✅ Errores de sintaxis (`php -l`)
- ✅ Errores de estilo (PHPCS)
- ❌ Errores lógicos (como `$this->db - execute()`)

## Solución: PHPStan

PHPStan detecta errores lógicos que son sintácticamente válidos.

### Instalación

```bash
composer require --dev phpstan/phpstan
```

### Configuración

Crear `phpstan.neon`:

```neon
parameters:
    level: 5
    paths:
        - src
```

### Uso

```bash
# Ejecutar PHPStan
vendor/bin/phpstan analyse

# Con lint.sh (si lo integramos)
./lint.sh --phpstan
```

### Ejemplo de detección

```php
// Esto:
return $this->db - execute($query);

// PHPStan dirá:
ERROR: Call to undefined function execute()
ERROR: Operand types mixed - int
```

## Alternativa: Psalm

Similar a PHPStan pero con enfoque en tipos.

```bash
composer require --dev vimeo/psalm
vendor/bin/psalm --init
vendor/bin/psalm
```

## Recomendación

Para un proyecto real:
1. **Básico**: `php -l` + PHPCS (ya incluido en lint.sh)
2. **Intermedio**: + PHPStan level 5
3. **Avanzado**: + PHPStan level 8 + Psalm
