# 🎯 Demostración del Sistema de Linting Inteligente

Este documento muestra casos de uso prácticos del sistema de linting.

## Estado Actual

El repositorio contiene código legacy con problemas de estilo:
- `src/Controllers/UserController.php` - Código con mal formato (espacios, llaves, etc.)
- `src/Utils/helpers.php` - Funciones legacy sin seguir PSR-12

**Importante**: Este código legacy ya está en el repositorio y **NO se valida** a menos que lo modifiques.

## 🧪 Casos de Uso

### Caso 1: Sin cambios - Todo limpio

```bash
php scripts/lint.php
```

**Resultado**: ✅ "No hay archivos modificados para validar"

El linter no valida nada porque no hay cambios.

---

### Caso 2: Modificar código legacy

```bash
# Agregar una línea al archivo legacy con problemas
echo "    // Nuevo comentario" >> src/Controllers/UserController.php

# Ejecutar linter
php scripts/lint.php
```

**Resultado**: ❌ El linter detectará TODOS los errores de `UserController.php`

**Por qué?** Cuando modificas un archivo, el linter valida TODO el archivo.

**Solución**:
```bash
# Opción 1: Arreglar solo tu cambio
git diff src/Controllers/UserController.php  # Ver qué cambiaste
# ... corregir tu código ...

# Opción 2: Restaurar el archivo si solo estabas probando
git checkout -- src/Controllers/UserController.php
```

---

### Caso 3: Agregar nuevo método a un archivo limpio

```bash
# Modificar un archivo que ya sigue estándares
cat >> src/Models/User.php << 'EOF'

    public function activate(): void
    {
        $this->setStatus('active');
    }
EOF

# Ejecutar linter
php scripts/lint.php
```

**Resultado**: ✅ Pasa la validación (User.php ya sigue PSR-12)

**Limpiar**:
```bash
git checkout -- src/Models/User.php
```

---

### Caso 4: Modificar JavaScript con header PHP

```bash
# Modificar app.js que tiene <?php en el header
cat >> public/js/app.js << 'EOF'

// Nueva función global
window.newFeature = function() {
    console.log('Nueva característica')
};
EOF

# Ejecutar linter
php scripts/lint.php
```

**Resultado**: ✅ El linter:
1. Detecta el header `<?php ... ?>`
2. Lo elimina temporalmente
3. Valida solo el código JavaScript
4. Ajusta números de línea en errores

**Limpiar**:
```bash
git checkout -- public/js/app.js
```

---

### Caso 5: Agregar archivo al stage

```bash
# Modificar múltiples archivos
echo "// cambio 1" >> public/js/modern.js
echo "// cambio 2" >> public/js/legacy.js

# Agregar solo uno al stage
git add public/js/modern.js

# Ejecutar linter
php scripts/lint.php
```

**Resultado**: El linter valida:
- `modern.js` (staged)
- `legacy.js` (modified)

**Limpiar**:
```bash
git reset HEAD public/js/modern.js
git checkout -- public/js/modern.js public/js/legacy.js
```

---

### Caso 6: Crear un nuevo archivo limpio

```bash
# Crear nuevo controlador siguiendo PSR-12
cat > src/Controllers/OrderController.php << 'EOF'
<?php

namespace Controllers;

class OrderController
{
    public function list(): array
    {
        return [];
    }

    public function create(array $data): bool
    {
        return true;
    }
}
EOF

# Ejecutar linter
php scripts/lint.php
```

**Resultado**: ❌ El archivo aún no está rastreado por git

**Agregar y validar**:
```bash
git add src/Controllers/OrderController.php
php scripts/lint.php
```

**Resultado**: ✅ Pasa porque sigue PSR-12

**Limpiar**:
```bash
git reset HEAD src/Controllers/OrderController.php
rm src/Controllers/OrderController.php
```

---

### Caso 7: Introducir error de linting en JS

```bash
# Agregar código con error (falta semicolon)
cat >> public/js/modern.js << 'EOF'

window.testFunction = function() {
    var x = 5
    return x
};
EOF

# Ejecutar linter
php scripts/lint.php
```

**Resultado**: ❌ ESLint reportará errores de semicolons faltantes

**Ver detalles**:
```bash
# Los errores muestran línea y columna exacta
# Ejemplo: "52:14  error  Missing semicolon  semi"
```

**Corregir**:
```bash
git checkout -- public/js/modern.js
```

---

### Caso 8: Workflow completo de desarrollo

```bash
# 1. Crear nueva feature en archivo limpio
cat >> src/Models/User.php << 'EOF'

    public function deactivate(): void
    {
        $this->setStatus('inactive');
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }
EOF

# 2. Validar cambios
php scripts/lint.php
# ✅ Pasa

# 3. Agregar al stage
git add src/Models/User.php

# 4. Validar antes de commit
php scripts/lint.php
# ✅ Sigue pasando

# 5. Hacer commit
git commit -m "Add user activation methods"

# 6. Ahora el archivo ya está en el historial
# Si lo vuelves a ejecutar sin cambios:
php scripts/lint.php
# ✅ "No hay archivos modificados"
```

---

## 🎓 Lecciones Aprendidas

### ✅ Ventajas del sistema

1. **Solo valida cambios**: No te obliga a refactorizar todo el legacy
2. **Detecta archivos staged**: Útil para validar antes de commit
3. **Maneja edge cases**: Archivos JS con PHP, funciones globales, etc.
4. **Feedback inmediato**: Sabes exactamente qué está mal y dónde
5. **Integrable**: Puedes usarlo en git hooks o CI/CD

### ⚠️ Consideraciones

1. **Archivos legacy**: Si modificas un archivo legacy, tendrás que lidiar con TODOS sus errores
2. **Estrategia recomendada**:
   - Crear nuevos archivos siguiendo estándares
   - Refactorizar archivos legacy solo cuando los modifiques significativamente
   - Usar `.gitignore` o configuración del linter para excluir archivos problemáticos temporalmente

### 🔧 Configuración Avanzada

#### Excluir archivos legacy problemáticos

Edita `config/phpcs.xml`:

```xml
<exclude-pattern>src/Controllers/UserController.php</exclude-pattern>
<exclude-pattern>src/Utils/helpers.php</exclude-pattern>
```

O edita `config/.eslintrc.json`:

```json
{
  "ignorePatterns": ["public/js/legacy.js"]
}
```

#### Usar en pre-commit hook

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "🔍 Ejecutando linter..."
php scripts/lint.php
if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Linting falló. Opciones:"
    echo "   1. Corrige los errores"
    echo "   2. Usa 'git commit --no-verify' para saltarte el hook (NO RECOMENDADO)"
    exit 1
fi
echo "✅ Linting exitoso"
EOF

chmod +x .git/hooks/pre-commit
```

---

## 📊 Métricas del Proyecto

Para ver estadísticas del código:

```bash
# Total de archivos PHP
find src public -name "*.php" | wc -l

# Total de archivos JS
find public -name "*.js" | wc -l

# Archivos con problemas de estilo (ejecutar en todo el proyecto)
vendor/bin/phpcs --standard=config/phpcs.xml src public 2>/dev/null | grep "FILE:"

# Líneas de código
find src public -name "*.php" -o -name "*.js" | xargs wc -l
```

---

## 🎬 Video de Demostración

Para una demo completa, ejecuta:

```bash
# 1. Estado inicial
php scripts/lint.php

# 2. Modificar archivo legacy
echo "// test" >> src/Utils/helpers.php
php scripts/lint.php

# 3. Ver errores
git diff src/Utils/helpers.php

# 4. Restaurar
git checkout -- src/Utils/helpers.php
php scripts/lint.php
```

---

## 🤝 Contribuir

Para agregar más archivos de ejemplo:

1. Crea el archivo
2. NO lo agregues a git inmediatamente
3. Ejecuta `php scripts/lint.php` (no lo detectará)
4. Agrégalo: `git add <archivo>`
5. Ejecuta `php scripts/lint.php` (ahora sí lo valida)
6. Corrige errores si hay
7. Commit

¡Disfruta del linting inteligente! 🚀
