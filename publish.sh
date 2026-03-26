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

# Function to publish a package
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
        return 1
    fi
    
    # Analyze code
    print_info "Analyzing code..."
    # Temporarily disable set -e to capture analysis result
    set +e
    dart analyze lib --no-fatal-warnings > /dev/null 2>&1
    local analyze_exit_code=$?
    set -e
    
    if [[ $analyze_exit_code -eq 0 ]]; then
        print_success "Code analysis passed"
    else
        # Show analysis results, but only fail on errors, warnings are ok
        local analyze_output=$(dart analyze lib 2>&1)
        if echo "$analyze_output" | grep -q "error"; then
            print_error "Code analysis failed (errors found)"
            echo "$analyze_output"
            return 1
        else
            print_info "Code analysis passed (with warnings)"
            print_info "Warnings don't block publishing, continuing..."
        fi
    fi
    
    # Dry run check
    print_info "Running pre-publish check..."
    local dry_run_output
    local dry_run_exit_code
    
    # Temporarily disable set -e to capture exit code
    set +e
    dry_run_output=$(flutter pub publish --dry-run 2>&1)
    dry_run_exit_code=$?
    set -e
    
    # Show package size info
    echo "$dry_run_output" | grep "Total compressed" || true
    
    # Check for real errors
    # Exit code 65 usually means warnings but publishable
    if echo "$dry_run_output" | grep -q "Package has.*error"; then
        print_error "Pre-publish check failed (errors found)"
        echo "$dry_run_output" | grep -A 10 "error"
        return 1
    elif echo "$dry_run_output" | grep -q "Package has.*warning"; then
        # Has warnings but publishable (common in monorepo)
        print_info "Pre-publish check passed (with warnings)"
        print_info "Warnings about gitignored files are normal in monorepo"
    elif [[ $dry_run_exit_code -eq 0 ]]; then
        # No issues at all
        print_success "Pre-publish check passed completely"
    else
        # Continue for other cases (as long as no explicit errors)
        print_info "Pre-publish check completed"
    fi
    
    # Ask whether to publish
    echo ""
    read -p "Publish $package_name to pub.dev? [Y/n] " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Skipping $package_name"
    else
        print_info "Publishing $package_name..."
        # Use echo "y" to auto-confirm the publishing prompt
        echo "y" | flutter pub publish
        if [[ $? -eq 0 ]]; then
            print_success "$package_name published successfully!"
        else
            print_error "$package_name publishing failed"
            return 1
        fi
    fi
    
    cd - > /dev/null
    echo ""
}

# Function to update sub-package dependencies
update_subpackage_dependencies() {
    local package_path=$1
    local main_version=$2

    print_info "Updating dependencies for $package_path..."

    # Backup original pubspec.yaml
    cp "$package_path/pubspec.yaml" "$package_path/pubspec.yaml.bak"

    # Temporarily remove pubspec_overrides.yaml (Melos generates this with path overrides)
    if [[ -f "$package_path/pubspec_overrides.yaml" ]]; then
        mv "$package_path/pubspec_overrides.yaml" "$package_path/pubspec_overrides.yaml.bak"
        print_info "Temporarily removed pubspec_overrides.yaml"
    fi

    # Update dependencies: replace multi-line path dependency with inline hosted version
    # Converts:
    #   flutter_dev_panel:
    #     path: ../..
    # To:
    #   flutter_dev_panel: ^VERSION
    local tmp_file="$package_path/pubspec.yaml.tmp"
    awk -v ver="^$main_version" '
    /flutter_dev_panel:$/ {
        # Read next line
        getline next_line
        if (next_line ~ /path: \.\.\/\.\./) {
            # Replace with inline version
            print $0 " " ver
        } else {
            print
            print next_line
        }
        next
    }
    { print }
    ' "$package_path/pubspec.yaml" > "$tmp_file"
    mv "$tmp_file" "$package_path/pubspec.yaml"

    # Remove publish_to: none
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/publish_to: none/d' "$package_path/pubspec.yaml"
    else
        sed -i '/publish_to: none/d' "$package_path/pubspec.yaml"
    fi

    print_success "Dependencies updated"
}

# Function to restore sub-package dependencies
restore_subpackage_dependencies() {
    local package_path=$1

    if [[ -f "$package_path/pubspec.yaml.bak" ]]; then
        mv "$package_path/pubspec.yaml.bak" "$package_path/pubspec.yaml"
        print_info "Restored original pubspec.yaml for $package_path"
    fi

    # Restore pubspec_overrides.yaml
    if [[ -f "$package_path/pubspec_overrides.yaml.bak" ]]; then
        mv "$package_path/pubspec_overrides.yaml.bak" "$package_path/pubspec_overrides.yaml"
        print_info "Restored pubspec_overrides.yaml for $package_path"
    fi
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
    
    # Sub-packages list
    SUBPACKAGES=(
        "flutter_dev_panel_console"
        "flutter_dev_panel_network"
        "flutter_dev_panel_device"
        "flutter_dev_panel_performance"
    )
    
    # Update and publish sub-packages
    for package in "${SUBPACKAGES[@]}"; do
        echo ""
        print_info "====== Processing $package ======"
        
        package_path="packages/$package"
        
        # Update dependencies
        update_subpackage_dependencies "$package_path" "$MAIN_VERSION"
        
        # Publish package
        if publish_package "$package_path" "$package"; then
            print_success "$package processed successfully"
        else
            print_error "$package processing failed"
            # Restore original configuration
            restore_subpackage_dependencies "$package_path"
        fi
    done
    
    # Ask whether to restore local development configuration
    echo ""
    read -p "Restore local development configuration (path dependencies)? [Y/n] " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        for package in "${SUBPACKAGES[@]}"; do
            restore_subpackage_dependencies "packages/$package"
        done
        print_success "Local development configuration restored"
    fi
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
    local package_path="packages/$package"
    
    echo ""
    print_info "====== Publishing $package ======"
    
    # Update dependencies
    update_subpackage_dependencies "$package_path" "$MAIN_VERSION"
    
    # Publish package
    if publish_package "$package_path" "$package"; then
        print_success "$package published successfully"
        
        # Ask whether to restore local development configuration
        echo ""
        read -p "Restore local development configuration for $package? [Y/n] " -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            restore_subpackage_dependencies "$package_path"
            print_success "Local development configuration restored for $package"
        fi
    else
        print_error "$package publishing failed"
        # Restore original configuration
        restore_subpackage_dependencies "$package_path"
    fi
}

# Run main process
main