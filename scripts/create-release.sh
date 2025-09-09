#!/bin/bash

# Create a new release for Time Tracker
# Usage: ./scripts/create-release.sh 1.0.0

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "❌ Please provide a version number"
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

echo "🚀 Creating release v$VERSION..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "❌ Not on main branch (currently on: $CURRENT_BRANCH)"
    echo "Please switch to main branch before creating a release"
    exit 1
fi

# Check if tag already exists
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "❌ Tag v$VERSION already exists"
    exit 1
fi

# Update version in SettingsView
echo "📝 Updating version to v$VERSION in SettingsView..."
SETTINGS_FILE="timetracker/timetracker/UI/Settings/SettingsView.swift"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "❌ SettingsView.swift not found at $SETTINGS_FILE"
    exit 1
fi

# Update the version string in SettingsView.swift
# This uses sed to replace the version line
sed -i '' "s/Text(\"Version [^\"]*\")/Text(\"Version $VERSION\")/g" "$SETTINGS_FILE"

# Check if the version was actually updated
if ! grep -q "Text(\"Version $VERSION\")" "$SETTINGS_FILE"; then
    echo "❌ Failed to update version in SettingsView.swift"
    echo "Expected to find: Text(\"Version $VERSION\")"
    echo "Current content:"
    grep "Text(\"Version" "$SETTINGS_FILE" || echo "No version line found"
    exit 1
fi

echo "✅ Version updated in SettingsView.swift"

# Commit the version update
echo "📝 Committing version update..."
git add "$SETTINGS_FILE"
git commit -m "Bump version to v$VERSION"

# Push the commit
echo "📝 Pushing version update commit..."
git push origin HEAD

# Create and push tag
echo "📝 Creating tag v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION"
git push origin "v$VERSION"

echo "✅ Tag v$VERSION created and pushed!"
echo ""
echo "The GitHub Actions workflow will now:"
echo "1. Build the app"
echo "2. Create a DMG"
echo "3. Create a GitHub release"
echo ""
echo "You can monitor progress at:"
echo "https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/]*\)\.git.*/\1/')/actions"
