#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(pwd)"

log_error "AGB: I never got this script to work. Use 'rewrite' and see the results there"
exit 1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

CSV_FILE=""

log_error() {
    printf "${RED}✗ ERROR:${NC} %s\n" "$1" >&2
}

log_warning() {
    printf "${YELLOW}⚠ WARNING:${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

log_info() {
    printf "${BLUE}ℹ${NC} %s\n" "$1"
}

log_step() {
    printf "${CYAN}▶${NC} %s\n" "$1"
}

log_detail() {
    printf "${MAGENTA}  ›${NC} %s\n" "$1"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <csv-file>

Verifies that all FROM author/committer identities in the CSV mapping file
have been successfully rewritten and no longer exist in the Git repository.

OPTIONS:
    -h, --help          Show this help message

CSV FORMAT:
    The CSV file must contain the following columns (with header row):
    - author_name_from      : Original author name to verify
    - committer_name_from   : Original committer name to verify
    - author_email_from     : Original author email to verify
    - committer_email_from  : Original committer email to verify

NOTES:
    - This script queries the entire Git history using git log --all
    - Exits with code 0 if verification succeeds (no FROM values found)
    - Exits with code 1 if verification fails (FROM values still exist)
    - Provides detailed error reporting including specific commits

EOF
}

check_dependencies() {
    log_step "Checking dependencies..."
    
    if ! command -v git > /dev/null 2>&1; then
        log_error "git is not installed or not in PATH"
        exit 1
    fi
    log_success "git found: $(git --version)"
    
    if [ ! -d "${PROJECT_ROOT}/.git" ]; then
        log_error "Not a git repository: ${PROJECT_ROOT}"
        exit 1
    fi
    log_success "Git repository found"
}

validate_csv_file() {
    log_step "Validating CSV file..."
    
    if [ ! -f "$CSV_FILE" ]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi
    log_success "CSV file found: $CSV_FILE"
    
    local header
    header=$(head -n 1 "$CSV_FILE")
    
    local required_columns="author_name_from committer_name_from author_email_from committer_email_from"
    
    for col in $required_columns; do
        if ! echo "$header" | grep -q "$col"; then
            log_error "Missing required column: $col"
            log_info "Expected columns: $required_columns"
            exit 1
        fi
    done
    log_success "CSV file has all required columns"
    
    local line_count
    line_count=$(wc -l < "$CSV_FILE" | tr -d ' ')
    
    if [ "$line_count" -lt 2 ]; then
        log_error "CSV file must contain at least one data row (plus header)"
        exit 1
    fi
    
    log_success "CSV file contains $((line_count - 1)) mapping(s)"
}

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

extract_from_values() {
    log_step "Extracting FROM values from CSV..."
    
    # Create temporary files to store unique values
    local temp_dir="$(mktemp -d)"
    local author_names_file="${temp_dir}/author_names"
    local author_emails_file="${temp_dir}/author_emails"
    local committer_names_file="${temp_dir}/committer_names"
    local committer_emails_file="${temp_dir}/committer_emails"
    
    touch "$author_names_file" "$author_emails_file" "$committer_names_file" "$committer_emails_file"
    
    local line_num=0
    while IFS=, read -r author_name_from committer_name_from author_email_from committer_email_from rest; do
        line_num=$((line_num + 1))
        
        if [ "$line_num" -eq 1 ]; then
            continue
        fi
        
        author_name_from=$(trim "$author_name_from")
        author_email_from=$(trim "$author_email_from")
        committer_name_from=$(trim "$committer_name_from")
        committer_email_from=$(trim "$committer_email_from")
        
        if [ -n "$author_name_from" ]; then
            echo "$author_name_from" >> "$author_names_file"
        fi
        
        if [ -n "$author_email_from" ]; then
            echo "$author_email_from" >> "$author_emails_file"
        fi
        
        if [ -n "$committer_name_from" ]; then
            echo "$committer_name_from" >> "$committer_names_file"
        fi
        
        if [ -n "$committer_email_from" ]; then
            echo "$committer_email_from" >> "$committer_emails_file"
        fi
    done < "$CSV_FILE"
    
    # Get unique counts and store back to temp files
    sort -u "$author_names_file" > "${author_names_file}.tmp" && mv "${author_names_file}.tmp" "$author_names_file"
    sort -u "$author_emails_file" > "${author_emails_file}.tmp" && mv "${author_emails_file}.tmp" "$author_emails_file"
    sort -u "$committer_names_file" > "${committer_names_file}.tmp" && mv "${committer_names_file}.tmp" "$committer_names_file"
    sort -u "$committer_emails_file" > "${committer_emails_file}.tmp" && mv "${committer_emails_file}.tmp" "$committer_emails_file"
    
    local author_names_count=$(wc -l < "$author_names_file" | tr -d ' ')
    local author_emails_count=$(wc -l < "$author_emails_file" | tr -d ' ')
    local committer_names_count=$(wc -l < "$committer_names_file" | tr -d ' ')
    local committer_emails_count=$(wc -l < "$committer_emails_file" | tr -d ' ')
    
    log_success "Extracted ${author_names_count} unique author name(s)"
    log_success "Extracted ${author_emails_count} unique author email(s)"
    log_success "Extracted ${committer_names_count} unique committer name(s)"
    log_success "Extracted ${committer_emails_count} unique committer email(s)"
    
    # Return temp_dir path via echo
    echo "$temp_dir"
}

query_git_repository() {
    log_step "Querying Git repository for all authors and committers..."
    
    cd "$PROJECT_ROOT"
    
    local temp_dir="$1"
    local repo_authors_file="${temp_dir}/repo_authors"
    local repo_committers_file="${temp_dir}/repo_committers"
    
    git log --all --format='%an|%ae' | sort -u > "$repo_authors_file"
    git log --all --format='%cn|%ce' | sort -u > "$repo_committers_file"
    
    local authors_count=$(wc -l < "$repo_authors_file" | tr -d ' ')
    local committers_count=$(wc -l < "$repo_committers_file" | tr -d ' ')
    
    log_success "Found ${authors_count} unique author identity/identities in repository"
    log_success "Found ${committers_count} unique committer identity/identities in repository"
}

check_in_file() {
    local search_value="$1"
    local file="$2"
    
    if grep -Fxq "$search_value" "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_for_old_identities() {
    local temp_dir="$1"
    local author_names_file="${temp_dir}/author_names"
    local author_emails_file="${temp_dir}/author_emails"
    local committer_names_file="${temp_dir}/committer_names"
    local committer_emails_file="${temp_dir}/committer_emails"
    local repo_authors_file="${temp_dir}/repo_authors"
    local repo_committers_file="${temp_dir}/repo_committers"
    
    log_step "Checking for old identities in repository..."
    
    local found_issues=false
    local issue_count=0
    
    while IFS='|' read -r name email; do
        local name_match=false
        local email_match=false
        
        if check_in_file "$name" "$author_names_file"; then
            name_match=true
        fi
        
        if check_in_file "$email" "$author_emails_file"; then
            email_match=true
        fi
        
        if [ "$name_match" = true ] || [ "$email_match" = true ]; then
            if [ "$found_issues" = false ]; then
                echo ""
                log_error "Found old author identities still present in repository!"
                echo ""
                found_issues=true
            fi
            
            issue_count=$((issue_count + 1))
            
            log_warning "Old author found: $name <$email>"
            
            local commits
            commits=$(git log --all --format='%H|%ai|%s' --author="$email" 2>/dev/null | head -n 10)
            
            if [ -n "$commits" ]; then
                log_info "Sample commits with this author:"
                echo "$commits" | while IFS='|' read -r hash date subject; do
                    local short_hash=$(echo "$hash" | cut -c1-8)
                    log_detail "$short_hash | $date | $subject"
                done
                echo ""
            fi
        fi
    done < "$repo_authors_file"
    
    while IFS='|' read -r name email; do
        local name_match=false
        local email_match=false
        
        if check_in_file "$name" "$committer_names_file"; then
            name_match=true
        fi
        
        if check_in_file "$email" "$committer_emails_file"; then
            email_match=true
        fi
        
        if [ "$name_match" = true ] || [ "$email_match" = true ]; then
            if [ "$found_issues" = false ]; then
                echo ""
                log_error "Found old committer identities still present in repository!"
                echo ""
                found_issues=true
            fi
            
            issue_count=$((issue_count + 1))
            
            log_warning "Old committer found: $name <$email>"
            
            local commits
            commits=$(git log --all --format='%H|%ci|%s' --committer="$email" 2>/dev/null | head -n 10)
            
            if [ -n "$commits" ]; then
                log_info "Sample commits with this committer:"
                echo "$commits" | while IFS='|' read -r hash date subject; do
                    local short_hash=$(echo "$hash" | cut -c1-8)
                    log_detail "$short_hash | $date | $subject"
                done
                echo ""
            fi
        fi
    done < "$repo_committers_file"
    
    if [ "$found_issues" = true ]; then
        echo ""
        log_error "Verification FAILED: Found $issue_count old identity/identities still in repository"
        log_info "The author/committer rewrite may not have completed successfully"
        log_info "Run the rewrite script again to fix these issues"
        return 1
    fi
    
    return 0
}

main() {
    echo "======================================"
    echo "  Git Author/Committer Verifier"
    echo "======================================"
    echo ""
    
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                CSV_FILE="$1"
                shift
                ;;
        esac
    done
    
    if [ -z "$CSV_FILE" ]; then
        log_error "CSV file argument is required"
        usage
        exit 1
    fi
    
    check_dependencies
    echo ""
    
    validate_csv_file
    echo ""
    
    local temp_dir
    temp_dir=$(extract_from_values)
    echo ""
    
    query_git_repository "$temp_dir"
    echo ""
    
    if check_for_old_identities "$temp_dir"; then
        echo ""
        log_success "Verification PASSED: No old identities found in repository"
        log_success "All author/committer rewrites have been successfully applied"
        rm -rf "$temp_dir"
        exit 0
    else
        rm -rf "$temp_dir"
        exit 1
    fi
}

main "$@"
