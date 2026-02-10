#!/bin/bash

# ╔════════════════════════════════════════╗
# ║   Sistema de Linting Inteligente      ║
# ║   Validación de archivos modificados   ║
# ╚════════════════════════════════════════╝
#
# Este script detecta archivos modificados o en stage y ejecuta
# los linters apropiados solo en esos archivos.
#
# Uso:
#   ./lint.sh           # Modo resumen (por defecto)
#   ./lint.sh --verbose # Modo detallado (muestra todo)
#   ./lint.sh -v        # Alias de --verbose

set -e  # Exit on error (except where we handle it)

# Parse arguments
VERBOSE=0
if [[ "$1" == "--verbose" ]] || [[ "$1" == "-v" ]]; then
    VERBOSE=1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHPCS_BIN="$PROJECT_ROOT/vendor/bin/phpcs"
ESLINT_BIN="$PROJECT_ROOT/node_modules/.bin/eslint"
CONFIG_PHPCS="$PROJECT_ROOT/config/phpcs.xml"
CONFIG_ESLINT="$PROJECT_ROOT/config/.eslintrc.json"

# Arrays para archivos
declare -a php_files
declare -a js_files

# Variables de control
has_errors=0
declare -a error_list

# ═══════════════════════════════════════════════════════════════
# FUNCIONES
# ═══════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Sistema de Linting Inteligente      ║"
    echo "║   Validación de archivos modificados   ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
}

print_section() {
    echo ""
    echo "──────────────────────────────────────────────────"
    echo "  $1"
    echo "──────────────────────────────────────────────────"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_info() {
    echo -e "${CYAN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# ═══════════════════════════════════════════════════════════════
# DETECCIÓN DE ARCHIVOS
# ═══════════════════════════════════════════════════════════════

get_modified_files() {
    # Archivos modificados no staged
    local unstaged
    unstaged=$(git diff --name-only --diff-filter=ACMR 2>/dev/null || true)

    # Archivos en stage
    local staged
    staged=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

    # Combinar y eliminar duplicados
    local combined="${unstaged}${staged:+$'\n'}${staged}"
    echo "$combined" | sort -u | grep -v '^[[:space:]]*$' || true
}

classify_files() {
    local files="$1"

    while IFS= read -r file; do
        # Skip empty lines
        [[ -z "$file" ]] && continue

        # Skip if file doesn't exist
        [[ ! -f "$PROJECT_ROOT/$file" ]] && continue

        # Classify by extension
        if [[ "$file" == *.php ]]; then
            php_files+=("$file")
        elif [[ "$file" == *.js ]]; then
            js_files+=("$file")
        fi
    done <<< "$files"
}

# ═══════════════════════════════════════════════════════════════
# LINTING PHP
# ═══════════════════════════════════════════════════════════════

lint_php_files() {
    print_section "Validando archivos PHP"

    # PASO 1: Validar sintaxis PHP primero
    echo ""
    print_info "🔍 Paso 1/3: Validando sintaxis PHP..."

    local syntax_errors=0
    for file in "${php_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        local syntax_output

        set +e
        syntax_output=$(php -l "$full_path" 2>&1)
        local syntax_code=$?
        set -e

        if [[ $syntax_code -ne 0 ]]; then
            syntax_errors=1
            has_errors=1

            print_error "  ✗ $file"
            echo ""
            # Extraer solo la línea del error
            echo "$syntax_output" | grep -E "(Parse error|Fatal error|syntax error)" | sed 's/^/     /'
            echo ""
        fi
    done

    if [[ $syntax_errors -eq 1 ]]; then
        error_list+=("PHP: Syntax errors")
        print_error "⚠️  Corrige los errores de sintaxis antes de validar estilo"
        return 1
    fi

    print_success "  ✓ Sintaxis correcta"
    echo ""

    # PASO 2: Validar con PHPStan (errores lógicos)
    print_info "🔍 Paso 2/3: Analizando código (funciones, métodos, tipos)..."
    echo ""

    local phpstan_bin="$PROJECT_ROOT/vendor/bin/phpstan"
    if [[ ! -f "$phpstan_bin" ]]; then
        print_warning "  ⚠️  PHPStan no instalado (opcional pero recomendado)"
        echo ""
    else
        # Build file list
        local file_list=""
        for file in "${php_files[@]}"; do
            file_list="$file_list $PROJECT_ROOT/$file"
        done

        # Run PHPStan
        local phpstan_output
        set +e
        phpstan_output=$("$phpstan_bin" analyse $file_list --memory-limit=256M --no-progress --error-format=raw 2>&1)
        local phpstan_code=$?
        set -e

        if [[ $phpstan_code -eq 0 ]]; then
            print_success "  ✓ Análisis estático correcto"
        else
            has_errors=1
            error_list+=("PHP: Static analysis errors")

            print_error "  ✗ Errores detectados por PHPStan"
            echo ""

            # Mostrar errores de PHPStan
            echo "$phpstan_output" | grep -E "^\s*-->" | head -10 | sed 's/^/     /'

            local error_count=$(echo "$phpstan_output" | grep -c "^\s*-->" || echo 0)
            if [[ $error_count -gt 10 ]]; then
                echo "     ... y $((error_count - 10)) errores más"
            fi
            echo ""
        fi
    fi
    echo ""

    # PASO 3: Validar estilo con PHPCS (OPCIONAL)
    if [[ "${SKIP_STYLE:-0}" == "0" ]]; then
        print_info "🔍 Paso 3/3: Validando estilo de código (PSR-12)..."
        echo ""

        # Check if PHPCS is installed
        if [[ ! -f "$PHPCS_BIN" ]]; then
            print_warning "  ⚠️  PHPCS no instalado (opcional)"
            echo ""
        else
            # Build file list
            local file_args=()
            for file in "${php_files[@]}"; do
                file_args+=("$PROJECT_ROOT/$file")
            done

            # Run PHPCS and capture output
            local output
            local exit_code
            set +e
            output=$("$PHPCS_BIN" --standard="$CONFIG_PHPCS" "${file_args[@]}" 2>&1)
            exit_code=$?
            set -e

            if [[ $exit_code -eq 0 ]]; then
                print_success "  ✓ Estilo de código correcto"
            else
                # Para estilo, solo mostramos warning, no error crítico
                print_warning "  ⚠️  Problemas de estilo detectados (no críticos)"

                if [[ $VERBOSE -eq 1 ]]; then
                    echo "$output"
                else
                    show_php_summary "$output"
                fi
            fi
        fi
    else
        print_info "⏭️  Paso 3/3: Validación de estilo deshabilitada (SKIP_STYLE=1)"
    fi
    echo ""

    if [[ $has_errors -eq 1 ]]; then
        return 1
    else
        print_success "✓ Todos los archivos PHP pasaron las validaciones críticas"
        return 0
    fi
}

show_php_summary() {
    local output="$1"

    echo ""
    print_warning "⚠️  Resumen de errores PHP:"
    echo ""

    # Extraer información de cada archivo
    while IFS= read -r line; do
        if [[ "$line" =~ FILE:.*/(.*) ]]; then
            local file="${BASH_REMATCH[1]}"
            echo "  📄 $file"
        elif [[ "$line" =~ FOUND[[:space:]]+([0-9]+)[[:space:]]+ERROR.*AFFECTING[[:space:]]+([0-9]+)[[:space:]]+LINE ]]; then
            local errors="${BASH_REMATCH[1]}"
            local lines="${BASH_REMATCH[2]}"
            echo "     ├─ $errors errores en $lines líneas"
        elif [[ "$line" =~ PHPCBF[[:space:]]+CAN[[:space:]]+FIX.*([0-9]+)[[:space:]]+MARKED ]]; then
            local fixable="${BASH_REMATCH[1]}"
            print_info "     └─ ✨ $fixable errores se pueden auto-arreglar"
        fi
    done <<< "$output"

    echo ""
    print_info "💡 Para ver detalles completos: ./lint.sh --verbose"
    print_info "💡 Para auto-arreglar: vendor/bin/phpcbf --standard=config/phpcs.xml <archivo>"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# LINTING JAVASCRIPT
# ═══════════════════════════════════════════════════════════════

lint_js_files() {
    print_section "Validando archivos JavaScript"

    # Check if ESLint is installed
    if [[ ! -f "$ESLINT_BIN" ]]; then
        print_error "✗ ESLint no está instalado. Ejecuta: npm install"
        has_errors=1
        error_list+=("JS: ESLint not installed")
        return 1
    fi

    local js_has_errors=0
    declare -a js_errors_summary

    for file in "${js_files[@]}"; do
        local file_output
        local file_exit_code

        set +e
        file_output=$(lint_single_js_file "$file" 2>&1)
        file_exit_code=$?
        set -e

        if [[ $file_exit_code -ne 0 ]]; then
            js_has_errors=1
            js_errors_summary+=("$file|||$file_output")
        fi
    done

    if [[ $js_has_errors -eq 0 ]]; then
        print_success "✓ Todos los archivos JS pasaron las validaciones"
        return 0
    else
        # Mostrar errores (tanto en verbose como en resumen)
        if [[ $VERBOSE -eq 1 ]]; then
            # En modo verbose, los errores ya se mostraron durante lint_single_js_file
            # Solo necesitamos mostrar el resumen
            echo ""
            print_error "✗ Errores encontrados en archivos JavaScript"
        else
            # En modo resumen, mostrar el resumen conciso
            show_js_summary "${js_errors_summary[@]}"
        fi
        return 1
    fi
}

show_js_summary() {
    echo ""
    print_warning "⚠️  Resumen de errores JavaScript:"
    echo ""

    if [[ $# -eq 0 ]]; then
        echo "  (no errors captured - bug in script)"
        return
    fi

    for entry in "$@"; do
        # Split por delimitador |||
        local file="${entry%%|||*}"
        local output="${entry#*|||}"

        echo "  📄 $file"
        echo "     │"

        # Mostrar el output tal cual
        if [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/     │  /'
        else
            echo "     │  (sin output capturado)"
        fi

        echo "     └─"
        echo ""
    done

    print_info "💡 Para ver detalles completos: ./lint.sh --verbose"
    echo ""
}

lint_single_js_file() {
    local file="$1"
    local full_path="$PROJECT_ROOT/$file"
    local temp_file=""
    local php_header_lines=0
    local file_to_lint="$full_path"

    # Check if file has PHP header
    local first_line
    first_line=$(head -n 1 "$full_path")

    if [[ "$first_line" =~ ^\<\?php ]]; then
        # File has PHP header - need to process it

        # Count PHP header lines
        php_header_lines=$(grep -n '?>' "$full_path" | head -1 | cut -d: -f1)

        # Create temp file without PHP header
        temp_file=$(mktemp)
        tail -n +$((php_header_lines + 1)) "$full_path" > "$temp_file"
        file_to_lint="$temp_file"

        if [[ $VERBOSE -eq 1 ]]; then
            print_info "  → $file (contiene <?php header, líneas PHP: $php_header_lines)"
        fi
    else
        if [[ $VERBOSE -eq 1 ]]; then
            print_info "  → $file"
        fi
    fi

    # Run ESLint and capture both output and exit code
    local output
    local exit_code

    output=$("$ESLINT_BIN" -c "$CONFIG_ESLINT" "$file_to_lint" 2>&1) && exit_code=0 || exit_code=$?

    # Clean up temp file if created
    [[ -n "$temp_file" ]] && rm -f "$temp_file"

    # Process output
    if [[ $exit_code -eq 0 ]]; then
        return 0
    else
        has_errors=1
        error_list+=("JS: $file")

        # Always print output (it will be captured by parent for summary)
        echo "$output"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

show_files_to_lint() {
    if [[ ${#php_files[@]} -gt 0 ]]; then
        echo ""
        echo "📝 Archivos PHP a validar (${#php_files[@]}):"
        for file in "${php_files[@]}"; do
            echo "  - $file"
        done
    fi

    if [[ ${#js_files[@]} -gt 0 ]]; then
        echo ""
        echo "📝 Archivos JS a validar (${#js_files[@]}):"
        for file in "${js_files[@]}"; do
            echo "  - $file"
        done
    fi

    echo ""
}

print_summary() {
    echo ""
    echo "══════════════════════════════════════════════════"

    if [[ $has_errors -eq 0 ]]; then
        print_success "✓ LINTING EXITOSO"
        echo ""
        echo "Todos los archivos modificados pasaron las validaciones."
    else
        print_error "✗ LINTING FALLÓ"
        echo ""
        echo "Archivos con errores:"
        for error in "${error_list[@]}"; do
            echo "  ✗ $error"
        done
        echo ""
        echo "Por favor corrige los errores antes de hacer commit."
    fi

    echo "══════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

main() {
    print_header

    # Get modified files
    local modified_files
    modified_files=$(get_modified_files)

    # Check if we have any files
    if [[ -z "$modified_files" ]] || [[ "$modified_files" =~ ^[[:space:]]*$ ]]; then
        print_info "✓ No hay archivos modificados para validar"
        return 0
    fi

    # Count files
    local file_count
    file_count=$(echo "$modified_files" | wc -l | tr -d ' ')

    print_info "Archivos detectados: $file_count"

    # Classify files
    classify_files "$modified_files"

    # Check if we have files to lint
    if [[ ${#php_files[@]} -eq 0 ]] && [[ ${#js_files[@]} -eq 0 ]]; then
        print_info "✓ No hay archivos PHP o JS modificados para validar"
        return 0
    fi

    # Show files to lint
    show_files_to_lint

    # Lint PHP files
    if [[ ${#php_files[@]} -gt 0 ]]; then
        lint_php_files || has_errors=1
    fi

    # Lint JS files
    if [[ ${#js_files[@]} -gt 0 ]]; then
        lint_js_files || has_errors=1
    fi

    # Print summary
    print_summary

    # Exit with appropriate code
    exit $has_errors
}

# Run main
main "$@"
