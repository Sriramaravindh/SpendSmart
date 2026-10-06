@echo off
set PATH=C:\Users\AravindhSekar\nodejs\node-v20.18.0-win-x64;%PATH%
echo.
echo === SpendSmart Firebase Setup ===
echo.
echo Step 1: Logging in to Firebase...
echo (A browser window will open - sign in with your Google account)
echo (If the browser doesn't open, copy the URL shown and paste it manually)
echo.
call firebase login --no-localhost
if errorlevel 1 (
    echo.
    echo Login failed. Trying again...
    call firebase login --no-localhost
)
echo.
echo Step 2: Listing your projects...
call firebase projects:list
echo.
set /p PROJECT_ID="Enter your Firebase Project ID (or type 'new' to create one): "
if "%PROJECT_ID%"=="new" (
    set /p PROJECT_NAME="Enter a project ID (lowercase, no spaces, e.g. spendsmart-app): "
    call firebase projects:create %PROJECT_NAME% --display-name "SpendSmart"
    set PROJECT_ID=%PROJECT_NAME%
)
echo.
echo Using project: %PROJECT_ID%
call firebase use %PROJECT_ID%
echo.
echo Step 3: Building web app...
call flutter build web --no-tree-shake-icons
echo.
echo Step 4: Deploying to Firebase Hosting...
call firebase deploy --only hosting
echo.
echo === DONE! ===
echo.
pause
