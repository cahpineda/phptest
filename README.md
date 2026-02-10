# Sistema de Linting Inteligente para Monolito PHP/JS

Este proyecto es una POC (Proof of Concept) que demuestra cómo implementar un sistema de linting inteligente para un monolito legacy que contiene código PHP y JavaScript mezclado.

## 🎯 Características

- ✅ **Linting selectivo**: Solo valida archivos modificados o en stage, no todo el código legacy
- ✅ **Detección automática**: Identifica qué archivos han cambiado usando git
- ✅ **Multi-lenguaje**: Soporta PHP (PHPCS/PSR-12) y JavaScript (ESLint)
- ✅ **Manejo de casos edge**: Procesa correctamente archivos JS con headers `<?php` (común en templates legacy)
- ✅ **Funciones globales**: Valida código con `window.globalFunction`
- ✅ **Reportes claros**: Muestra exactamente qué archivos tienen problemas
- ✅ **Integrable**: Puede usarse en pre-commit hooks o CI/CD

## 📁 Estructura del Proyecto

```
phptest/
├── config/
│   ├── .eslintrc.json      # Configuración ESLint
│   └── phpcs.xml            # Configuración PHPCS (PSR-12)
├── public/
│   ├── css/
│   │   └── styles.css
│   ├── js/
│   │   ├── app.js          # JS con <?php header + window.globalInit
│   │   ├── legacy.js       # JS con <?php header + funciones legacy
│   │   └── modern.js       # JS moderno + window.apiUtils
│   └── index.php           # Entry point
├── scripts/
│   └── lint.php            # Script principal de linting
├── src/
│   ├── Controllers/
│   │   ├── ProductController.php
│   │   └── UserController.php
│   ├── Models/
│   │   └── User.php
│   └── Utils/
│       └── helpers.php
├── composer.json           # Dependencias PHP
├── package.json            # Dependencias JS
└── README.md
```

## 🚀 Instalación

### Opción 1: Con Composer instalado

```bash
# Instalar dependencias PHP
composer install

# Instalar dependencias JavaScript
npm install
```

### Opción 2: Sin Composer (descarga manual de PHPCS)

```bash
# Crear directorio vendor si no existe
mkdir -p vendor/bin

# Descargar PHPCS
curl -L https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar -o vendor/bin/phpcs
curl -L https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar -o vendor/bin/phpcbf

# Hacer ejecutables
chmod +x vendor/bin/phpcs
chmod +x vendor/bin/phpcbf

# Instalar dependencias JavaScript
npm install
```

### Opción 3: Script de instalación automatizado

```bash
# Ejecutar script de instalación
php scripts/install.php
```

## 📝 Uso

### Ejecutar linting de archivos modificados

```bash
# Método 1: Directamente con PHP
php scripts/lint.php

# Método 2: Via npm script
npm run lint

# Método 3: Si lo hiciste ejecutable
./scripts/lint.php
```

### ¿Qué archivos se validan?

El script detecta automáticamente:

1. **Archivos modificados** (working directory): `git diff --name-only`
2. **Archivos en stage**: `git diff --cached --name-only`

Solo se validan archivos `.php` y `.js` que hayan sido agregados, modificados o renombrados.

## 🧪 Pruebas

### Probar el sistema sin cambios

```bash
php scripts/lint.php
```

**Resultado esperado**: "No hay archivos modificados para validar"

### Probar con un archivo PHP modificado

```bash
# Modificar un archivo
echo "<?php echo 'test';" >> src/Models/User.php

# Ejecutar linter
php scripts/lint.php
```

**Resultado esperado**: PHPCS ejecuta solo en `User.php`

### Probar con un archivo JS modificado

```bash
# Modificar un archivo JS
echo "console.log('test')" >> public/js/modern.js

# Ejecutar linter
php scripts/lint.php
```

**Resultado esperado**: ESLint ejecuta solo en `modern.js`

### Probar con archivo JS que tiene <?php header

```bash
# Modificar archivo con header PHP
git add public/js/app.js

# Ejecutar linter
php scripts/lint.php
```

**Resultado esperado**: El linter detecta el header `<?php`, lo elimina temporalmente, valida el JS puro y ajusta los números de línea en los errores.

### Restaurar archivos modificados

```bash
git checkout -- src/Models/User.php public/js/modern.js
```

## 🔧 Configuración

### PHP (PHPCS)

Archivo: `config/phpcs.xml`

- Estándar: PSR-12
- Directorios: `src/`, `public/`

Para cambiar el estándar, modifica la línea:
```xml
<rule ref="PSR12"/>
```

### JavaScript (ESLint)

Archivo: `config/.eslintrc.json`

- Entorno: browser, ES6
- Reglas: semi, quotes, indent, etc.
- Globals: `window` (readonly)

## 📋 Ejemplos de Código

### Archivos JS con <?php header

El proyecto incluye archivos como `public/js/app.js`:

```javascript
<?php /* Template file */ ?>
window.globalInit = function() {
    console.log('App initialized');
};
```

El linter maneja esto automáticamente:
1. Detecta el header `<?php ... ?>`
2. Crea un archivo temporal sin el header
3. Ejecuta ESLint en el archivo limpio
4. Ajusta los números de línea en los errores reportados

### Funciones globales en window

El proyecto usa funciones globales como en monolitos reales:

```javascript
// En app.js
window.globalInit = function() { ... }
window.handleError = function(error) { ... }

// En legacy.js
window.legacyAjax = function(url, callback) { ... }
window.legacyUtils = { ... }

// En modern.js
window.apiUtils = { ... }
window.appState = { ... }
```

## 🎨 Características del Linter

### Detección Inteligente

- Usa `git diff` para detectar cambios
- Filtra solo archivos `.php` y `.js`
- Ignora archivos borrados
- No valida archivos que no fueron modificados

### Manejo de Edge Cases

- **JS con PHP**: Elimina temporalmente headers `<?php ... ?>`
- **Números de línea**: Ajusta líneas si hay headers PHP
- **Archivos grandes**: Solo valida lo modificado, no todo el archivo
- **Funciones globales**: ESLint configurado para reconocer `window`

### Reportes

```
╔════════════════════════════════════════╗
║   Sistema de Linting Inteligente      ║
║   Validación de archivos modificados   ║
╚════════════════════════════════════════╝

Archivos detectados: 2

📝 Archivos PHP a validar (1):
  - src/Controllers/UserController.php

📝 Archivos JS a validar (1):
  - public/js/app.js

──────────────────────────────────────────────────
  Validando archivos PHP
──────────────────────────────────────────────────
✓ Todos los archivos PHP pasaron las validaciones

──────────────────────────────────────────────────
  Validando archivos JavaScript
──────────────────────────────────────────────────
  → public/js/app.js (contiene <?php header, líneas PHP: 1)
✓ Todos los archivos JS pasaron las validaciones

══════════════════════════════════════════════════
✓ LINTING EXITOSO

Todos los archivos modificados pasaron las validaciones.
══════════════════════════════════════════════════
```

## 🔗 Integración con Git Hooks

Para ejecutar automáticamente antes de cada commit:

```bash
# Crear pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
php scripts/lint.php
if [ $? -ne 0 ]; then
    echo "Linting falló. Corrige los errores antes de hacer commit."
    exit 1
fi
EOF

# Hacer ejecutable
chmod +x .git/hooks/pre-commit
```

## 🐛 Problemas Comunes

### "PHPCS no está instalado"

```bash
composer install
# O descarga manual (ver Opción 2 en Instalación)
```

### "ESLint no está instalado"

```bash
npm install
```

### "command not found: composer"

Usa la Opción 2 o 3 de instalación (descarga manual o script automatizado)

## 🎓 Por qué este enfoque

En un monolito legacy grande:

- ❌ **Mal**: Validar todo el código en cada commit = PRs enormes e imposibles de revisar
- ✅ **Bien**: Validar solo cambios = PRs manejables, mejora incremental

Este sistema simula exactamente eso: valida calidad en código nuevo sin forzar refactor completo del legacy.

## 📚 Tecnologías

- **PHP**: >=7.4
- **PHPCS**: 3.7+ (PSR-12)
- **ESLint**: 8.56+
- **Git**: Para detección de cambios

## 🤝 Contribuir

Este es un proyecto de prueba. Puedes modificar:

- Reglas de linting en `config/phpcs.xml` y `config/.eslintrc.json`
- Script principal en `scripts/lint.php`
- Agregar más archivos de ejemplo

## 📄 Licencia

MIT
