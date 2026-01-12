#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

CSV_FILE=""
DRY_RUN=false
BACKUP_DIR="${PROJECT_ROOT}/.git-backup-$(date +%Y%m%d-%H%M%S)"
TEMP_DIR=""

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

cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <csv-file>

Rewrites Git author and committer information based on a CSV mapping file.

OPTIONS:
    -h, --help          Show this help message
    -n, --dry-run       Perform a dry run without modifying the repository
    -b, --backup DIR    Specify custom backup directory (default: .git-backup-TIMESTAMP)

CSV FORMAT:
    The CSV file must contain the following columns (with header row):
    - author_name_from      : Original author name to match
    - committer_name_from   : Original committer name to match
    - author_email_from     : Original author email to match
    - committer_email_from  : Original committer email to match
    - author_name_to        : New author name
    - committer_name_to     : New committer name
    - author_email_to       : New author email
    - committer_email_to    : New committer email

EXAMPLE CSV:
    author_name_from,committer_name_from,author_email_from,committer_email_from,author_name_to,committer_name_to,author_email_to,committer_email_to
    Old Name,Old Name,old@example.com,old@example.com,New Name,New Name,new@example.com,new@example.com

NOTES:
    - This script requires git-filter-repo to be installed
    - A backup of the .git directory will be created before making changes
    - The operation rewrites Git history and should be used with caution
    - After rewriting, force push may be required if the repository is shared

EOF
}

check_dependencies() {
    log_step "Checking dependencies..."
    
    if ! command -v git > /dev/null 2>&1; then
        log_error "git is not installed or not in PATH"
        exit 1
    fi
    log_success "git found: $(git --version)"
    
    if ! command -v git-filter-repo > /dev/null 2>&1; then
        log_error "git-filter-repo is not installed or not in PATH"
        log_info "Install it with: pip install git-filter-repo"
        log_info "Or visit: https://github.com/newren/git-filter-repo"
        exit 1
    fi
    log_success "git-filter-repo found"
    
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
    
    local required_columns="author_name_from committer_name_from author_email_from committer_email_from author_name_to committer_name_to author_email_to committer_email_to"
    
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

create_backup() {
    if [ "$DRY_RUN" = true ]; then
        log_info "Skipping backup creation (dry run mode)"
        return
    fi
    
    log_step "Creating backup of .git directory..."
    
    if [ -d "$BACKUP_DIR" ]; then
        log_error "Backup directory already exists: $BACKUP_DIR"
        exit 1
    fi
    
    mkdir -p "$BACKUP_DIR"
    log_detail "Backup location: $BACKUP_DIR"
    
    cp -r "${PROJECT_ROOT}/.git" "${BACKUP_DIR}/"
    log_success "Backup created successfully"
    
    local backup_size
    backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    log_detail "Backup size: $backup_size"
}

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

generate_mailmap() {
    local mailmap_file="$1"
    
    log_step "Generating mailmap file..."
    
    > "$mailmap_file"
    
    local line_num=0
    while IFS=, read -r author_name_from committer_name_from author_email_from committer_email_from author_name_to committer_name_to author_email_to committer_email_to; do
        line_num=$((line_num + 1))
        
        if [ "$line_num" -eq 1 ]; then
            continue
        fi
        
        author_name_from=$(trim "$author_name_from")
        author_email_from=$(trim "$author_email_from")
        author_name_to=$(trim "$author_name_to")
        author_email_to=$(trim "$author_email_to")
        
        if [ -n "$author_name_to" ] && [ -n "$author_email_to" ]; then
            echo "$author_name_to <$author_email_to> $author_name_from <$author_email_from>" >> "$mailmap_file"
            log_detail "Mapping: $author_name_from <$author_email_from> → $author_name_to <$author_email_to>"
        fi
    done < "$CSV_FILE"
    
    log_success "Mailmap file generated: $mailmap_file"
}

generate_callback_script() {
    local callback_file="$1"
    
    log_step "Generating filter-repo callback script..."
    
    cat > "$callback_file" <<'PYTHON_SCRIPT_START'
#!/usr/bin/env python3

import sys
import csv
import os

mappings = []

def load_mappings(csv_file):
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            mapping = {
                'author_name_from': row['author_name_from'].strip(),
                'author_email_from': row['author_email_from'].strip(),
                'committer_name_from': row['committer_name_from'].strip(),
                'committer_email_from': row['committer_email_from'].strip(),
                'author_name_to': row['author_name_to'].strip(),
                'author_email_to': row['author_email_to'].strip(),
                'committer_name_to': row['committer_name_to'].strip(),
                'committer_email_to': row['committer_email_to'].strip(),
            }
            mappings.append(mapping)

def rewrite_commit(commit, metadata):
    author_name = commit.author_name.decode('utf-8')
    author_email = commit.author_email.decode('utf-8')
    committer_name = commit.committer_name.decode('utf-8')
    committer_email = commit.committer_email.decode('utf-8')
    
    for mapping in mappings:
        author_match = (
            mapping['author_name_from'] == author_name and
            mapping['author_email_from'] == author_email
        )
        
        committer_match = (
            mapping['committer_name_from'] == committer_name and
            mapping['committer_email_from'] == committer_email
        )
        
        if author_match:
            commit.author_name = mapping['author_name_to'].encode('utf-8')
            commit.author_email = mapping['author_email_to'].encode('utf-8')
        
        if committer_match:
            commit.committer_name = mapping['committer_name_to'].encode('utf-8')
            commit.committer_email = mapping['committer_email_to'].encode('utf-8')

if __name__ == '__main__':
    import git_filter_repo as fr
    
    if len(sys.argv) < 2:
        print("Error: CSV file path required", file=sys.stderr)
        sys.exit(1)
    
    csv_file = sys.argv[1]
    load_mappings(csv_file)
    
    args = fr.FilteringOptions.parse_args(['--force'], error_on_empty=False)
    
    repo_filter = fr.RepoFilter(args, commit_callback=rewrite_commit)
    repo_filter.run()
PYTHON_SCRIPT_START
    
    chmod +x "$callback_file"
    log_success "Callback script generated: $callback_file"
}

display_mapping_summary() {
    log_step "Mapping Summary:"
    echo ""
    
    local line_num=0
    while IFS=, read -r author_name_from committer_name_from author_email_from committer_email_from author_name_to committer_name_to author_email_to committer_email_to; do
        line_num=$((line_num + 1))
        
        if [ "$line_num" -eq 1 ]; then
            continue
        fi
        
        author_name_from=$(trim "$author_name_from")
        author_email_from=$(trim "$author_email_from")
        committer_name_from=$(trim "$committer_name_from")
        committer_email_from=$(trim "$committer_email_from")
        author_name_to=$(trim "$author_name_to")
        author_email_to=$(trim "$author_email_to")
        committer_name_to=$(trim "$committer_name_to")
        committer_email_to=$(trim "$committer_email_to")
        
        printf "${CYAN}Mapping #%d:${NC}\n" $((line_num - 1))
        printf "  ${YELLOW}Author:${NC}\n"
        printf "    From: %s <%s>\n" "$author_name_from" "$author_email_from"
        printf "    To:   %s <%s>\n" "$author_name_to" "$author_email_to"
        printf "  ${YELLOW}Committer:${NC}\n"
        printf "    From: %s <%s>\n" "$committer_name_from" "$committer_email_from"
        printf "    To:   %s <%s>\n" "$committer_name_to" "$committer_email_to"
        echo ""
    done < "$CSV_FILE"
}

execute_rewrite() {
    log_step "Executing git filter-repo..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN MODE: Would execute rewrite operation with the mappings above"
        log_info "No changes will be made to the repository"
        return
    fi
    
    local callback_file="${TEMP_DIR}/callback.py"
    local mailmap_file="${TEMP_DIR}/mailmap"
    
    generate_mailmap "$mailmap_file"
    generate_callback_script "$callback_file"
    
    log_info "Running git-filter-repo (this may take a while for large repositories)..."
    
    cd "$PROJECT_ROOT"
    
    local output_file="${TEMP_DIR}/filter-repo-output.log"
    if python3 "$callback_file" "$CSV_FILE" > "$output_file" 2>&1; then
        log_success "Repository history rewritten successfully"
        if [ -s "$output_file" ]; then
            while IFS= read -r line; do
                log_detail "$line"
            done < "$output_file"
        fi
    else
        log_error "Failed to rewrite repository history"
        if [ -s "$output_file" ]; then
            while IFS= read -r line; do
                log_detail "$line"
            done < "$output_file"
        fi
        log_warning "You can restore from backup: $BACKUP_DIR"
        exit 1
    fi
}

verify_changes() {
    if [ "$DRY_RUN" = true ]; then
        return
    fi
    
    log_step "Verifying changes..."
    
    cd "$PROJECT_ROOT"
    
    local authors
    authors=$(git log --all --format='%an <%ae>' | sort -u)
    
    log_info "Current unique authors in repository:"
    echo "$authors" | while IFS= read -r author; do
        if [ -n "$author" ]; then
            log_detail "$author"
        fi
    done
    
    local committers
    committers=$(git log --all --format='%cn <%ce>' | sort -u)
    
    log_info "Current unique committers in repository:"
    echo "$committers" | while IFS= read -r committer; do
        if [ -n "$committer" ]; then
            log_detail "$committer"
        fi
    done
    
    log_success "Verification complete"
}

display_next_steps() {
    echo ""
    log_step "Next Steps:"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Run without --dry-run flag to execute the rewrite operation"
    else
        log_info "1. Review the changes with: git log --all --oneline"
        log_info "2. If everything looks correct, force push to remote: git push --force --all"
        log_info "3. Backup location (in case of issues): $BACKUP_DIR"
        log_warning "WARNING: Force pushing rewrites history. Coordinate with your team!"
        log_warning "All collaborators will need to re-clone or reset their local copies"
    fi
    
    echo ""
}

main() {
    echo "======================================"
    echo "  Git Author/Committer Rewriter"
    echo "======================================"
    echo ""
    
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -b|--backup)
                BACKUP_DIR="$2"
                shift 2
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
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
        echo ""
    fi
    
    check_dependencies
    echo ""
    
    validate_csv_file
    echo ""
    
    TEMP_DIR=$(mktemp -d)
    log_info "Using temporary directory: $TEMP_DIR"
    echo ""
    
    display_mapping_summary
    
    create_backup
    echo ""
    
    execute_rewrite
    echo ""
    
    verify_changes
    echo ""
    
    display_next_steps
    
    if [ "$DRY_RUN" = false ]; then
        log_success "Git history rewrite completed successfully!"
    else
        log_info "Dry run completed successfully"
    fi
}

main "$@"
