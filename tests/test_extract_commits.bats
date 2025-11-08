#!/usr/bin/env bats

# Test suite for extract-weekly-commits.sh

# Load test helpers
load helpers/test_helpers

# Setup and teardown
setup() {
    # Create temporary directory for tests
    export BATS_TMPDIR="${BATS_TMPDIR:-$(mktemp -d)}"
    export ORIGINAL_DIR="$(pwd)"
    
    # Copy script to test directory
    cp "${BATS_TEST_DIRNAME}/../extract-weekly-commits.sh" "${BATS_TMPDIR}/"
    cd "${BATS_TMPDIR}"
    
    # Setup test git config
    mock_git_config "test@example.com"
}

teardown() {
    cd "${ORIGINAL_DIR}"
    cleanup_test_env
}

# Test: Script fails when config file is missing
@test "script fails when repos.conf is missing" {
    run bash extract-weekly-commits.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file 'repos.conf' not found" ]]
}

# Test: Script fails when git user.email is not set
@test "script fails when git user.email is not set" {
    setup_test_config "repos.conf" "/tmp" "test:main"
    
    # Save current git configuration
    save_git_config
    
    # Unset git email (global and local)
    git config --global --unset user.email || true
    git config --unset user.email || true
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Git user.email not set" ]]
    
    # Restore original git configuration
    restore_git_config
}

# Test: Configuration parsing - BASE_PATH
@test "correctly parses BASE_PATH from config" {
    local test_base="/tmp/test_base"
    setup_test_config "repos.conf" "$test_base" "test:main"
    
    # Mock the rest of the script to just show config parsing
    sed -i.bak '/^# Get the email from git config/,$d' extract-weekly-commits.sh
    echo 'echo "BASE_PATH: $BASE_PATH"' >> extract-weekly-commits.sh
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "BASE_PATH: $test_base" ]]
}

# Test: Configuration parsing - COMMIT_DETAIL
@test "correctly parses COMMIT_DETAIL from config" {
    setup_test_config "repos.conf" "/tmp" "test:main" "title"
    
    # Mock the rest of the script to just show config parsing
    sed -i.bak '/^# Get the email from git config/,$d' extract-weekly-commits.sh
    echo 'echo "COMMIT_DETAIL: $COMMIT_DETAIL"' >> extract-weekly-commits.sh
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "COMMIT_DETAIL: title" ]]
}

# Test: Repository existence check
@test "warns when repository doesn't exist" {
    local nonexistent_repo="${BATS_TMPDIR}/nonexistent"
    setup_test_config "repos.conf" "${BATS_TMPDIR}" "nonexistent:main"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]  # Script continues even if some repos are missing
    [[ "$output" =~ "Repository not found: $nonexistent_repo" ]]
}

# Test: Git repository validation
@test "warns when directory is not a git repository" {
    local fake_repo="${BATS_TMPDIR}/fake_repo"
    mkdir -p "$fake_repo"
    setup_test_config "repos.conf" "${BATS_TMPDIR}" "fake_repo:main"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Not a git repository: $fake_repo" ]]
}

# Test: Branch existence check
@test "warns when branch doesn't exist" {
    local test_repo=$(setup_test_repo "test_repo")
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "test_repo:nonexistent_branch"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Branch 'nonexistent_branch' not found" ]]
}

# Test: Successful commit extraction
@test "successfully extracts commits from current week" {
    # Setup test repository with commits
    local test_repo=$(setup_test_repo "test_repo")
    local default_branch=$(get_default_branch "$test_repo")
    
    # Go to test repository and create commits in current week
    cd "$test_repo"
    eval $(get_test_week_dates)
    create_commit_with_date "Test commit 1" "${MONDAY} 10:00:00"
    create_commit_with_date "Test commit 2" "${FRIDAY} 15:30:00"
    
    # Setup config to point to our test repo
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "test_repo:${default_branch}"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found 2 commits" ]]
    
    # Check that report file was created
    [ -f "reports/$(date +%Y-%m-%d)/test_repo.txt" ]
}

# Test: Multiple repositories processing
@test "processes multiple repositories" {
    # Setup two test repositories with master branch
    local test_repo1=$(setup_test_repo "repo1" "master")
    eval $(get_test_week_dates)
    cd "$test_repo1"
    create_commit_with_date "Repo1 commit" "${MONDAY} 09:00:00"
    
    local test_repo2=$(setup_test_repo "repo2" "master")
    cd "$test_repo2"
    create_commit_with_date "Repo2 commit" "${TUESDAY} 14:00:00"
    
    # Setup config with both repos
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "repo1:master"$'\n'"repo2:master"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Processing: ${BATS_TMPDIR}/test_repos/repo1" ]]
    [[ "$output" =~ "Processing: ${BATS_TMPDIR}/test_repos/repo2" ]]
    
    # Check both report files were created
    [ -f "reports/$(date +%Y-%m-%d)/repo1.txt" ]
    [ -f "reports/$(date +%Y-%m-%d)/repo2.txt" ]
}

# Test: Multiple branches processing
@test "processes multiple branches from same repository" {
    # Setup test repository with master branch
    local test_repo=$(setup_test_repo "test_repo" "master")
    
    # Create a second branch with commits
    cd "$test_repo"
    eval $(get_test_week_dates)
    git checkout -b develop
    create_commit_with_date "Develop commit" "${MONDAY} 11:00:00"
    
    git checkout master
    create_commit_with_date "Master commit" "${TUESDAY} 12:00:00"
    
    # Setup config with multiple branches
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "test_repo:master,develop"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Checking branch: master" ]]
    [[ "$output" =~ "Checking branch: develop" ]]
    
    # Check report contains both branches
    local report_file="reports/$(date +%Y-%m-%d)/test_repo.txt"
    [ -f "$report_file" ]
    grep -q "Branch: master" "$report_file"
    grep -q "Branch: develop" "$report_file"
}

# Test: Commit detail levels
@test "respects commit detail level setting - title only" {
    # Setup test repository with master branch
    local test_repo=$(setup_test_repo "test_repo" "master")
    cd "$test_repo"
    eval $(get_test_week_dates)
    create_commit_with_date "Short title"$'\n\n'"Long body description"$'\n'"with multiple lines" "${MONDAY} 10:00:00"
    
    # Setup config with title-only detail
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "test_repo:master" "title"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    
    # Check report contains only title
    local report_file="reports/$(date +%Y-%m-%d)/test_repo.txt"
    [ -f "$report_file" ]
    grep -q "Short title" "$report_file"
    ! grep -q "Long body description" "$report_file"
}

# Test: Report file structure
@test "creates properly structured report files" {
    # Setup test repository with master branch
    local test_repo=$(setup_test_repo "test_repo" "master")
    cd "$test_repo"
    eval $(get_test_week_dates)
    create_commit_with_date "Test commit" "${MONDAY} 10:00:00"
    
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "test_repo:master"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    
    # Check report file structure
    local report_file="reports/$(date +%Y-%m-%d)/test_repo.txt"
    [ -f "$report_file" ]
    
    # Verify header content
    grep -q "# Weekly Commits Report" "$report_file"
    grep -q "Repository: test_repo" "$report_file"
    grep -q "Author: test@example.com" "$report_file"
    grep -q "## Branch: master" "$report_file"
}