**** Push local files from local project to a remote GitHub repository
To push local files to a GitHub remote repository using the command line, you need to initialize a Git repository locally, commit your files, link the local repository to the remote one, and then push the changes.

PREREQUISITES:
1. A GitHub account.
2. Git installed on your local machine and configured with your username and email.
3. A newly created, empty GitHub repository (do not initialize it with a README, license, or .gitignore file to avoid conflicts).

Step-by-Step Guide:
1. Open your terminal or command prompt and navigate to the root directory of your local project using the cd command.
2. Initialize Git in your project folder:  
    bash  
        git init -b main  
    This command creates a hidden .git directory. The -b main flag ensures your initial branch is named "main", which is standard for newer Git versions.
3. Stage your files for the first commit:  
    bash  
        git add .  
    This command adds all files in the current directory to the staging area.
4. Commit the staged files to your local repository:  
    bash  
        git commit -m "First commit"  
    Replace "First commit" with a short, meaningful description of your changes.
5. Copy the remote repository URL from your GitHub repository's Quick Setup page. You'll find it by clicking the green "Code" button.
6. Add the remote repository as an "origin" for your local repository:  
    bash  
        git remote add origin <REMOTE_URL>  
    Replace <REMOTE_URL> with the URL you copied in the previous step. You can verify this with git remote -v.
7. Push your local commits to the remote repository:  
    bash  
        git push -u origin main --force  
    The -u flag sets the remote repository as the "upstream" for your local branch, allowing you to use git push and git pull without specifying the origin and branch name in the future.

Your local files are now pushed to your GitHub repository. For subsequent updates, you just need to stage, commit, and push the changes:   
    bash  
        git add .  
        git commit -m "Your update message"  
        git push  

To force remove an application:
When you try to remove an ArgoCD application from the WebUI, sometimes it gets stuck in deleting state because a finalizer cannot complete its work. To immediately remove the application, you can force-remove its finalizers:

kubectl patch application/APP_NAME --type json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]' -n argocd