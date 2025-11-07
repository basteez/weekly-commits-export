# 🐿️ Weekly Commit Extractor

A tiny macOS shell script that exports all your **Git commits from the current work week (Monday → Friday)** into a neat text file.  
Perfect for writing weekly reports, standups, or just keeping track of what you’ve done. ✨

## 📦 Features

- ✅ Filters commits by **your Git email**  
- 🗓️ Includes commits **only from Monday to Friday** of the current week  
- 🕒 Adds the **date and time** before each commit  
- 🧹 Flattens multi-line commit messages into a single clean line  
- 💾 Saves everything to `commits-<today>.txt`

Example output:

```

04-11-2025 10:42 | feat: implement handling of decreased rates in RateReview component and related tests
05-11-2025 09:13 | refactor: remove unused prop
06-11-2025 14:28 | test: add new test data for rate decrease scenario
07-11-2025 11:02 | fix: pick location state correctly

````

## 🚀 Usage

1. Place `extract-weekly-commits.sh` in your local repository.  
2. Make it executable:
   ```bash
   chmod +x extract-weekly-commits.sh
   ```

3. Run it:

   ```bash
   ./extract-weekly-commits.sh
   ```
4. Find your exported commits in a file named:

   ```
   commits-YYYY-MM-DD.txt
   ```

## ⚙️ Requirements

* macOS (uses `date -v` syntax)
* A Git repository
* Your `user.email` set in Git:

  ```bash
  git config user.email "you@example.com"
  ```

## 💡 Tip

Want to include weekends too?
Just replace this line in the script:

```bash
FRIDAY=$(date -v +"$((5 - $DAY_OF_WEEK))"d +%Y-%m-%d)
```

with:

```bash
FRIDAY=$(date -v +"$((7 - $DAY_OF_WEEK))"d +%Y-%m-%d)
```

🪶 Simple. Useful. No extra tools required.
