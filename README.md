# Sistema de Linting Inteligente para Monolito PHP/JS

POC de linting que valida **solo archivos modificados** enfocado en **prevenir código roto**, no en estilo.

## 🎯 Filosofía

En monolitos legacy:
- ❌ No forzamos estilo en código existente
- ✅ **Evitamos que se rompa el código**
- ✅ Detectamos errores de sintaxis
- ✅ Detectamos funciones/métodos inexistentes

## 🚀 Instalación

### Requisitos
- PHP >= 7.4
- Composer
- Node.js / npm
- Git

### Instalar dependencias
```bash
composer install
npm install
```

## 📝 Uso

### Linting normal (recomendado)
```bash
./lint.sh
```

**Valida 3 cosas:**
1. ✅ **Sintaxis** (crítico): `;`, `}`, `(`, typos
2. ✅ **Análisis estático** (crítico): funciones, métodos, clases inexistentes
3. ⚠️ **Estilo** (warning): PSR-12, no bloquea commit

### Solo validaciones críticas (sin estilo)
```bash
SKIP_STYLE=1 ./lint.sh
```

### Ver detalles completos
```bash
./lint.sh --verbose
```

## 🔍 ¿Qué detecta?

### ✅ CRÍTICO (bloquea commit):

| Error | Ejemplo | Detectado por |
|-------|---------|---------------|
| Sin `;` | `echo "test"` | php -l |
| Sin `}` | `if (true) { echo "hi";` | php -l |
| Typo en keyword | `<?ph` | php -l |
| Función inexistente | `foo()` | PHPStan |
| Clase inexistente | `new Bar()` | PHPStan |
| Método inexistente | `$obj->missing()` | PHPStan |

### ⚠️ WARNING (no bloquea):

| Error | Ejemplo |
|-------|---------|
| Espacios | `if($x==1){` |
| Sin namespace | `class Foo` |
| Llaves mal ubicadas | `function x(){` |

## 📁 Estructura

```
phptest/
├── lint.sh              ← Script principal (bash)
├── config/
│   ├── phpcs.xml        ← Configuración estilo (opcional)
│   └── .eslintrc.json   ← Configuración JS
├── phpstan.neon         ← Configuración análisis estático
├── src/                 ← Código PHP
├── public/              ← Archivos web
└── vendor/bin/
    ├── phpcs            ← Validador de estilo
    ├── phpcbf           ← Auto-fix estilo
    └── phpstan          ← Análisis estático
```

## 🧪 Ejemplos

### Sin errores
```bash
./lint.sh
# ✓ Sintaxis correcta
# ✓ Análisis estático correcto
# ⚠️ Problemas de estilo (no críticos)
# ✓ LINTING EXITOSO
```

### Con error de sintaxis
```bash
# Archivo con: echo "test"  (falta ;)
./lint.sh
# ✗ src/file.php
#    PHP Parse error: expecting ";"
# ✗ LINTING FALLÓ
```

### Con función inexistente
```bash
# Archivo con: noExiste();
./lint.sh
# ✗ Function noExiste() not found
# ✗ LINTING FALLÓ
```

## ⚙️ Configuración

### Deshabilitar validación de estilo permanentemente

Edita `.bashrc` o `.zshrc`:
```bash
export SKIP_STYLE=1
```

### Cambiar nivel de PHPStan

Edita `phpstan.neon`:
```neon
parameters:
    level: 1  # 0-9, donde 9 es más estricto
```

### Excluir archivos de PHPStan

Edita `phpstan.neon`:
```neon
parameters:
    excludePaths:
        - src/Legacy/*
```

## 🎓 Workflow

```bash
# 1. Hacer cambios
vim src/Controllers/UserController.php

# 2. Validar (solo crítico)
SKIP_STYLE=1 ./lint.sh

# 3. Si hay errores, corregir
# 4. Validar de nuevo
./lint.sh

# 5. Commit (sin hacer git add ni commit automático)
```

## 🔧 Herramientas

| Herramienta | Propósito | Nivel |
|-------------|-----------|-------|
| `php -l` | Sintaxis | Crítico ✅ |
| PHPStan | Funciones/tipos | Crítico ✅ |
| PHPCS | Estilo PSR-12 | Warning ⚠️ |
| ESLint | JS | Crítico ✅ |

## 📊 Comparación

| Aspecto | Antes | Ahora |
|---------|-------|-------|
| Valida todo el código | ❌ | ✅ Solo modificados |
| Bloquea por estilo | ❌ | ✅ Solo warnings |
| Detecta sintaxis | ❌ | ✅ php -l |
| Detecta funciones | ❌ | ✅ PHPStan |
| Output | Confuso | ✅ Resumen claro |

## 🤝 Contribuir

Para agregar más validaciones, edita `lint.sh` y agrega pasos en `lint_php_files()` o `lint_js_files()`.

## 📄 Licencia

MIT
