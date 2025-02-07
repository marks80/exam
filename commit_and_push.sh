#!/bin/bash

# Define your GitHub repository URL
GITHUB_REPO="https://github.com/marks80/exam.git"

# Step 2: Initialize Git (if not already initialized)
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
else
    echo "Git is already initialized."
fi

# Step 3: Add GitHub remote (if not already added)
if git remote | grep -q "origin"; then
    echo "Remote 'origin' already exists."
else
    echo "Adding remote repository..."
    git remote add origin $GITHUB_REPO
fi

# Step 4: Add all files to Git tracking
echo "Staging all files..."
git add .

# Step 5: Commit the changes
echo "Committing changes..."
git commit -m "Deployed EKS with Atlantis - verified apply"

# Step 6: Push to the master branch
echo "Pushing code to GitHub..."
git push -u origin master

echo "Code successfully pushed to GitHub!"
