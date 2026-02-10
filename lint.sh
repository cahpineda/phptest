#!/bin/bash

# ╔════════════════════════════════════════╗
# ║   Sistema de Linting Inteligente      ║
# ║   Validación de archivos modificados   ║
# ╚════════════════════════════════════════╝
#
# Este script detecta archivos modificados o en stage y ejecuta
# los linters apropiados solo en esos archivos.
#
# Uso: ./lint.sh

set -e  # Exit on error (except where we handle it)

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

    # Check if PHPCS is installed
    if [[ ! -f "$PHPCS_BIN" ]]; then
        print_error "✗ PHPCS no está instalado. Ejecuta: composer install"
        has_errors=1
        error_list+=("PHP: PHPCS not installed")
        return 1
    fi

    # Build file list
    local file_args=()
    for file in "${php_files[@]}"; do
        file_args+=("$PROJECT_ROOT/$file")
    done

    # Run PHPCS
    if "$PHPCS_BIN" --standard="$CONFIG_PHPCS" "${file_args[@]}" 2>&1; then
        print_success "✓ Todos los archivos PHP pasaron las validaciones"
        return 0
    else
        has_errors=1
        error_list+=("PHP")
        return 1
    fi
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

    for file in "${js_files[@]}"; do
        lint_single_js_file "$file" || js_has_errors=1
    done

    if [[ $js_has_errors -eq 0 ]]; then
        print_success "✓ Todos los archivos JS pasaron las validaciones"
        return 0
    else
        return 1
    fi
}

lint_single_js_file() {
    local file="$1"
    local full_path="$PROJECT_ROOT/$file"
    local temp_file=""
    local php_header_lines=0

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

        print_info "  → $file (contiene <?php header, líneas PHP: $php_header_lines)"

        # Run ESLint on temp file
        if "$ESLINT_BIN" -c "$CONFIG_ESLINT" "$temp_file" 2>&1; then
            rm -f "$temp_file"
            return 0
        else
            local exit_code=$?
            # Adjust line numbers in error output
            # Note: This is simplified - full line number adjustment would be more complex
            rm -f "$temp_file"
            has_errors=1
            error_list+=("JS: $file")
            return $exit_code
        fi
    else
        # No PHP header - lint directly
        print_info "  → $file"

        if "$ESLINT_BIN" -c "$CONFIG_ESLINT" "$full_path" 2>&1; then
            return 0
        else
            has_errors=1
            error_list+=("JS: $file")
            return 1
        fi
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
        lint_php_files || true  # Don't exit, continue with JS
    fi

    # Lint JS files
    if [[ ${#js_files[@]} -gt 0 ]]; then
        lint_js_files || true  # Don't exit
    fi

    # Print summary
    print_summary

    # Exit with appropriate code
    exit $has_errors
}

# Run main
main "$@"
