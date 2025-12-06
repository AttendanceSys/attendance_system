# My Flutter Project

kahor intaadan so clone garenin waxa doorata meesha laguu dhigi laha ee uu flutter-ka yaalo tusaale
cd C:\Users\YOUR_NAME\Downloads\flutter
marka aragtid meesha uu kuu yalo waxa so copy garesata mesha u yalo sida tusalaha kore waxa ka hor marisa cd kadib cloning-ka bilaaw ...

1. Clone repo-ga GitHub:

git clone https://github.com/AttendanceSys/attendance_system.git

kadib marka so clone garesid waxa lagaa raba ina u sameso new branch adoo ku dhex jirtid folder-ka 
ama tag folder-ka ado isticmaalaya 

cd attendance_system
kadib 

2. git checkout -b your_branch_name

your_branch_name ku badal magac cusub adoo ka dhigaya tusale login_page ama task lagu diray magaciisa.


## 🔧 How to run


1. Get packages:

    flutter pub get
2. Run
    flutter run
3. clean
    flutter clean

markaa shaqada soo dhamesid qaabka aad u soo push gareen laheed waa kanaa

4. this is how to Push it to GitHub


# 1. Add all project files
git add .

# 2. Commit the first version
git commit -m "waxa aad qabatay kuso qor inta"

# 3. Push branch-kaaga cusub GitHub
git push -u origin magac-branch-kaaga

### Cloud Functions

#### Cleanup Expired Sessions
This function marks sessions as inactive when their `expires_at` or `period_ends_at` timestamps are in the past. It ensures that stale sessions do not block new QR code generation.

**Deployment:**
1. Ensure Firebase CLI is installed and authenticated.
2. Run `firebase deploy --only functions` to deploy the function.
