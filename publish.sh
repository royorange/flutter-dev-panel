#!/bin/bash

# Flutter Dev Panel Publishing Script
# For publishing main package and all sub-packages to pub.dev

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Check for uncommitted changes
check_git_status() {
    if [[ -n $(git status -s) ]]; then
        print_error "Uncommitted changes detected. Please commit or stash them first"
        git status -s
        exit 1
    fi
}

# Function to publish a package (main package, runs in-place)
publish_package() {
    local package_path=$1
    local package_name=$2

    print_info "Preparing to publish $package_name..."

    cd "$package_path"

    # Run tests
    print_info "Running tests..."
    if flutter test > /dev/null 2>&1; then
        print_success "Tests passed"
    else
        print_error "Tests failed. Skipping $package_name"
        cd - > /dev/null
        return 1
    fi

    # Analyze code
    print_info "Analyzing code..."
    set +e
    dart analyze lib --no-fatal-warnings > /dev/null 2>&1
    local analyze_exit_code=$?
    set -e

    if [[ $analyze_exit_code -eq 0 ]]; then
        print_success "Code analysis passed"
    else
        local analyze_output=$(dart analyze lib 2>&1)
        if echo "$analyze_output" | grep -q "error"; then
            print_error "Code analysis failed (errors found)"
            echo "$analyze_output"
            cd - > /dev/null
            return 1
        else
            print_info "Code analysis passed (with warnings)"
        fi
    fi

    # Dry run check
    print_info "Running pre-publish check..."
    set +e
    local dry_run_output=$(flutter pub publish --dry-run 2>&1)
    local dry_run_exit_code=$?
    set -e

    echo "$dry_run_output" | grep "Total compressed" || true

    if echo "$dry_run_output" | grep -q "Package has.*error"; then
        print_error "Pre-publish check failed (errors found)"
        echo "$dry_run_output" | grep -A 10 "error"
        cd - > /dev/null
        return 1
    fi

    # Ask whether to publish
    echo ""
    read -p "Publish $package_name to pub.dev? [Y/n] " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Skipping $package_name"
    else
        print_info "Publishing $package_name..."
        echo "y" | flutter pub publish
        if [[ $? -eq 0 ]]; then
            print_success "$package_name published successfully!"
        else
            print_error "$package_name publishing failed"
            cd - > /dev/null
            return 1
        fi
    fi

    cd - > /dev/null
    echo ""
}

# Function to publish a sub-package via a temp standalone git repo.
# dart pub publish uses 'git ls-files' for the archive. In a monorepo
# the git root differs from the package root, producing an empty (<1 KB)
# archive. Copying into a fresh git repo fixes this.
publish_subpackage() {
    local package_path=$1
    local package_name=$2
    local main_version=$3

    print_info "Preparing to publish $package_name..."

    # Run tests in the original location first
    print_info "Running tests..."
    if (cd "$package_path" && flutter test > /dev/null 2>&1); then
        print_success "Tests passed"
    else
        print_error "Tests failed. Skipping $package_name"
        return 1
    fi

    # Analyze code in the original location
    print_info "Analyzing code..."
    set +e
    (cd "$package_path" && dart analyze lib --no-fatal-warnings > /dev/null 2>&1)
    local analyze_exit_code=$?
    set -e

    if [[ $analyze_exit_code -ne 0 ]]; then
        local analyze_output=$(cd "$package_path" && dart analyze lib 2>&1)
        if echo "$analyze_output" | grep -q "error"; then
            print_error "Code analysis failed (errors found)"
            echo "$analyze_output"
            return 1
        else
            print_info "Code analysis passed (with warnings)"
        fi
    else
        print_success "Code analysis passed"
    fi

    # Create temp directory with standalone git repo
    local tmp_dir=$(mktemp -d)
    print_info "Creating temp publish directory: $tmp_dir"
    cp -r "$package_path"/. "$tmp_dir/"

    # Replace path dependency with hosted version
    awk -v ver="^$main_version" '
    /flutter_dev_panel:$/ {
        getline next_line
        if (next_line ~ /path: \.\.\/\.\./) {
            print $0 " " ver
        } else {
            print
            print next_line
        }
        next
    }
    { print }
    ' "$tmp_dir/pubspec.yaml" > "$tmp_dir/pubspec.yaml.tmp"
    mv "$tmp_dir/pubspec.yaml.tmp" "$tmp_dir/pubspec.yaml"

    # Remove publish_to: none
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/publish_to: none/d' "$tmp_dir/pubspec.yaml"
    else
        sed -i '/publish_to: none/d' "$tmp_dir/pubspec.yaml"
    fi

    rm -f "$tmp_dir/pubspec_overrides.yaml"
    cp LICENSE "$tmp_dir/LICENSE" 2>/dev/null || true

    # Initialize as standalone git repo
    (cd "$tmp_dir" && git init --quiet && git add -A && git commit -m "publish" --quiet)

    # Dry run check
    print_info "Running pre-publish check..."
    set +e
    local dry_run_output=$(cd "$tmp_dir" && flutter pub publish --dry-run 2>&1)
    local dry_run_exit_code=$?
    set -e

    echo "$dry_run_output" | grep "Total compressed" || true

    if echo "$dry_run_output" | grep -q "Package has.*error"; then
        print_error "Pre-publish check failed (errors found)"
        echo "$dry_run_output" | grep -A 10 "error"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Ask whether to publish
    echo ""
    read -p "Publish $package_name to pub.dev? [Y/n] " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Skipping $package_name"
    else
        print_info "Publishing $package_name..."
        (cd "$tmp_dir" && echo "y" | flutter pub publish)
        if [[ $? -eq 0 ]]; then
            print_success "$package_name published successfully!"
        else
            print_error "$package_name publishing failed"
            rm -rf "$tmp_dir"
            return 1
        fi
    fi

    rm -rf "$tmp_dir"
    echo ""
}


# Main process
main() {
    print_info "Flutter Dev Panel Publishing Script"
    echo "================================"
    
    # Check current directory
    if [[ ! -f "pubspec.yaml" ]] || [[ ! -d "packages" ]]; then
        print_error "Please run this script from flutter_dev_panel root directory"
        exit 1
    fi
    
    # Check Git status
    print_info "Checking Git status..."
    check_git_status
    print_success "Git status clean"
    
    # Get main package version
    MAIN_VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2)
    print_info "Main package version: $MAIN_VERSION"
    
    echo ""
    echo "Select publishing option:"
    echo "1. Publish all packages (main + sub-packages)"
    echo "2. Publish main package only"
    echo "3. Publish sub-packages only"
    echo "4. Publish specific package"
    echo "0. Exit"
    echo ""
    
    read -p "Enter your choice (0-4): " -r choice
    
    case $choice in
        1)
            # Publish all
            publish_main_package
            publish_all_subpackages
            ;;
        2)
            # Main package only
            publish_main_package
            ;;
        3)
            # Sub-packages only
            publish_all_subpackages
            ;;
        4)
            # Specific package
            publish_specific_package
            ;;
        0)
            print_info "Publishing cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Publishing process completed!"
}

# Function to publish main package
publish_main_package() {
    echo ""
    print_info "====== Publishing Main Package ======"
    publish_package "." "flutter_dev_panel"
}

# Function to publish all sub-packages
publish_all_subpackages() {
    echo ""
    read -p "Continue with sub-packages? [Y/n] " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Skipping sub-packages"
        return
    fi

    SUBPACKAGES=(
        "flutter_dev_panel_console"
        "flutter_dev_panel_network"
        "flutter_dev_panel_device"
        "flutter_dev_panel_performance"
    )

    for package in "${SUBPACKAGES[@]}"; do
        echo ""
        print_info "====== Processing $package ======"
        publish_subpackage "packages/$package" "$package" "$MAIN_VERSION" || true
    done
}

# Function to publish specific package
publish_specific_package() {
    echo ""
    echo "Available packages:"
    echo "1. flutter_dev_panel (main)"
    echo "2. flutter_dev_panel_console"
    echo "3. flutter_dev_panel_network"
    echo "4. flutter_dev_panel_device"
    echo "5. flutter_dev_panel_performance"
    echo "0. Back to main menu"
    echo ""
    
    read -p "Select package to publish (0-5): " -r pkg_choice
    
    case $pkg_choice in
        1)
            publish_main_package
            ;;
        2)
            publish_single_subpackage "flutter_dev_panel_console"
            ;;
        3)
            publish_single_subpackage "flutter_dev_panel_network"
            ;;
        4)
            publish_single_subpackage "flutter_dev_panel_device"
            ;;
        5)
            publish_single_subpackage "flutter_dev_panel_performance"
            ;;
        0)
            main
            ;;
        *)
            print_error "Invalid package selection"
            ;;
    esac
}

# Function to publish a single sub-package
publish_single_subpackage() {
    local package=$1

    echo ""
    print_info "====== Publishing $package ======"
    publish_subpackage "packages/$package" "$package" "$MAIN_VERSION"
}

# Run main process
main