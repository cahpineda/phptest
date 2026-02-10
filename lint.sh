#!/bin/bash

# ╔════════════════════════════════════════╗
# ║   Smart Linting System                ║
# ║   Validates only modified files       ║
# ╚════════════════════════════════════════╝
#
# This script detects modified or staged files and runs
# the appropriate linters only on those files.
#
# Usage:
#   ./lint.sh           # Summary mode (default)
#   ./lint.sh --verbose # Detailed mode (shows everything)
#   ./lint.sh -v        # Alias for --verbose
#   ./lint.sh --fix     # Auto-fix errors when possible

set -e  # Exit on error (except where we handle it)

# Parse arguments
VERBOSE=0
FIX_MODE=0

for arg in "$@"; do
    case "$arg" in
        --verbose|-v)
            VERBOSE=1
            ;;
        --fix|-f)
            FIX_MODE=1
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show all details"
            echo "  -f, --fix        Auto-fix errors when possible"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Environment variables:"
            echo "  SKIP_STYLE=1     Skip style validation"
            exit 0
            ;;
    esac
done

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

# File arrays
declare -a php_files
declare -a js_files

# Control variables
has_errors=0
declare -a error_list

# ═══════════════════════════════════════════════════════════════
# FUNCIONES
# ═══════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Smart Linting System                ║"
    echo "║   Validates only modified files       ║"
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
    # Unstaged modified files
    local unstaged
    unstaged=$(git diff --name-only --diff-filter=ACMR 2>/dev/null || true)

    # Staged files
    local staged
    staged=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

    # Combine and remove duplicates
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
    print_section "Validating files PHP"

    # STEP 1: Validate PHP syntax first
    echo ""
    print_info "🔍 Step 1/3: Validating PHP syntax..."

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
        print_error "⚠️  Fix syntax errors before continuing"
        return 1
    fi

    print_success "  ✓ Correct syntax"
    echo ""

    # STEP 2: Validate with PHPStan (logical errors)
    print_info "🔍 Step 2/3: Analyzing code (functions, methods, types)..."
    echo ""

    local phpstan_bin="$PROJECT_ROOT/vendor/bin/phpstan"
    if [[ ! -f "$phpstan_bin" ]]; then
        print_warning "  ⚠️  PHPStan not installed (optional but recommended)"
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
            print_success "  ✓ Static analysis passed"
        else
            has_errors=1
            error_list+=("PHP: Static analysis errors")

            print_error "  ✗ Errors detected by PHPStan"
            echo ""

            # Mostrar errores de PHPStan
            echo "$phpstan_output" | grep -E "^\s*-->" | head -10 | sed 's/^/     /'

            local error_count=$(echo "$phpstan_output" | grep -c "^\s*-->" || echo 0)
            if [[ $error_count -gt 10 ]]; then
                echo "     ... y $((error_count - 10)) more errors"
            fi
            echo ""
        fi
    fi
    echo ""

    # STEP 3: Validate style with PHPCS (OPTIONAL)
    if [[ "${SKIP_STYLE:-0}" == "0" ]]; then
        print_info "🔍 Step 3/3: Validating code style (PSR-12)..."
        echo ""

        local phpcbf_bin="$PROJECT_ROOT/vendor/bin/phpcbf"

        # Check if PHPCS/PHPCBF is installed
        if [[ ! -f "$PHPCS_BIN" ]]; then
            print_warning "  ⚠️  PHPCS not installed (optional)"
            echo ""
        else
            # Build file list
            local file_args=()
            for file in "${php_files[@]}"; do
                file_args+=("$PROJECT_ROOT/$file")
            done

            if [[ $FIX_MODE -eq 1 ]] && [[ -f "$phpcbf_bin" ]]; then
                # Fix mode: use phpcbf to auto-fix
                print_info "  🔧 Auto-fixing style..."
                local output
                set +e
                output=$("$phpcbf_bin" --standard="$CONFIG_PHPCS" "${file_args[@]}" 2>&1)
                local exit_code=$?
                set -e

                if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
                    # Exit code 1 significa que se hicieron cambios
                    print_success "  ✓ Style fixed automatically"
                    echo "$output" | grep "PHPCBF" | sed 's/^/     /'
                else
                    print_warning "  ⚠️  Some issues could not be auto-fixed"
                fi
            else
                # Normal mode: just validate with phpcs
                local output
                local exit_code
                set +e
                output=$("$PHPCS_BIN" --standard="$CONFIG_PHPCS" "${file_args[@]}" 2>&1)
                exit_code=$?
                set -e

                if [[ $exit_code -eq 0 ]]; then
                    print_success "  ✓ Code style is correct"
                else
                    # Para estilo, solo mostramos warning, no error crítico
                    print_warning "  ⚠️  Style issues detected (non-critical)"

                    if [[ $VERBOSE -eq 1 ]]; then
                        echo "$output"
                    else
                        show_php_summary "$output"
                    fi
                fi
            fi
        fi
    else
        print_info "⏭️  Step 3/3: Style validation disabled (SKIP_STYLE=1)"
    fi
    echo ""

    if [[ $has_errors -eq 1 ]]; then
        return 1
    else
        print_success "✓ All PHP files passed critical validations"
        return 0
    fi
}

show_php_summary() {
    local output="$1"

    echo ""
    print_warning "⚠️  PHP errors summary:"
    echo ""

    # Extraer información de cada archivo
    while IFS= read -r line; do
        if [[ "$line" =~ FILE:.*/(.*) ]]; then
            local file="${BASH_REMATCH[1]}"
            echo "  📄 $file"
        elif [[ "$line" =~ FOUND[[:space:]]+([0-9]+)[[:space:]]+ERROR.*AFFECTING[[:space:]]+([0-9]+)[[:space:]]+LINE ]]; then
            local errors="${BASH_REMATCH[1]}"
            local lines="${BASH_REMATCH[2]}"
            echo "     ├─ $errors errors in $lines lines"
        elif [[ "$line" =~ PHPCBF[[:space:]]+CAN[[:space:]]+FIX.*([0-9]+)[[:space:]]+MARKED ]]; then
            local fixable="${BASH_REMATCH[1]}"
            print_info "     └─ ✨ $fixable errors can be auto-fixed"
        fi
    done <<< "$output"

    echo ""
    print_info "💡 To see full details: ./lint.sh --verbose"
    print_info "💡 To auto-fix: vendor/bin/phpcbf --standard=config/phpcs.xml <archivo>"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# LINTING JAVASCRIPT
# ═══════════════════════════════════════════════════════════════

lint_js_files() {
    print_section "Validating JavaScript files"

    # Check if ESLint is installed
    if [[ ! -f "$ESLINT_BIN" ]]; then
        print_error "✗ ESLint not installed. Run: npm install"
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
        print_success "✓ All JS files passed validations"
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
    print_warning "⚠️  JavaScript errors summary:"
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

    print_info "💡 To see full details: ./lint.sh --verbose"
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
            print_info "  → $file (contiene <?php header, lines PHP: $php_header_lines)"
        fi
    else
        if [[ $VERBOSE -eq 1 ]]; then
            print_info "  → $file"
        fi
    fi

    # Run ESLint and capture both output and exit code
    local output
    local exit_code
    local eslint_flags="-c $CONFIG_ESLINT"

    # Agregar --fix si está en modo fix
    if [[ $FIX_MODE -eq 1 ]]; then
        eslint_flags="$eslint_flags --fix"
    fi

    output=$("$ESLINT_BIN" $eslint_flags "$file_to_lint" 2>&1) && exit_code=0 || exit_code=$?

    # Si estamos en modo fix y el archivo temporal fue modificado, copiar cambios de vuelta
    if [[ $FIX_MODE -eq 1 ]] && [[ -n "$temp_file" ]] && [[ $exit_code -eq 0 ]]; then
        # Copiar archivo arreglado de vuelta (preservando header PHP)
        local first_lines
        first_lines=$(head -n "$php_header_lines" "$full_path")
        echo "$first_lines" > "$full_path"
        cat "$temp_file" >> "$full_path"
    fi

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
        echo "📝 PHP files to validate (${#php_files[@]}):"
        for file in "${php_files[@]}"; do
            echo "  - $file"
        done
    fi

    if [[ ${#js_files[@]} -gt 0 ]]; then
        echo ""
        echo "📝 JS files to validate (${#js_files[@]}):"
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
        print_success "✓ LINTING PASSED"
        echo ""
        echo "All modified files passed validations."
    else
        print_error "✗ LINTING FAILED"
        echo ""
        echo "Files with errors:"
        for error in "${error_list[@]}"; do
            echo "  ✗ $error"
        done
        echo ""
        echo "Please fix errors before committing."
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
        print_info "✓ No modified files to validate"
        return 0
    fi

    # Count files
    local file_count
    file_count=$(echo "$modified_files" | wc -l | tr -d ' ')

    print_info "Files detected: $file_count"

    # Classify files
    classify_files "$modified_files"

    # Check if we have files to lint
    if [[ ${#php_files[@]} -eq 0 ]] && [[ ${#js_files[@]} -eq 0 ]]; then
        print_info "✓ No modified PHP or JS files to validate"
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
