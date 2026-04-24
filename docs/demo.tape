Output docs/demo.mp4

Set Theme "Dracula"
Set FontSize 15
Set Width 900
Set Height 440
Set Shell "bash"
Set Padding 20
Set TypingSpeed 60ms
Set Framerate 60

# Silent setup: skip .bashrc, source dj.sh first so it sets its own DJLIST,
# then override with a throwaway temp file so real bookmarks are invisible
Hide
Type "shopt -s expand_aliases && source ./dj.sh && DJLIST=$(mktemp) && mkdir -p /tmp/dj-demo/projects /tmp/dj-demo/webapp /tmp/dj-demo/logs && PS1='$ ' && clear"
Enter
Sleep 800ms
Show

Sleep 600ms

# --- Bookmark from current directory ---
Type "cd /tmp/dj-demo/projects"
Enter
Sleep 700ms
Type "j -a proj"
Enter
Sleep 1.2s

# --- Bookmark with an explicit path (from anywhere) ---
Type "j -a web /tmp/dj-demo/webapp"
Enter
Sleep 1.4s

Type "j -a logs /tmp/dj-demo/logs"
Enter
Sleep 1.4s

# --- Go home, then list all bookmarks ---
Type "cd ~"
Enter
Sleep 700ms
Type "j"
Enter
Sleep 2.5s

# --- Jump between directories ---
Type "j proj"
Enter
Sleep 400ms
Type "pwd"
Enter
Sleep 1.5s

Type "j logs"
Enter
Sleep 400ms
Type "pwd"
Enter
Sleep 1.5s

# --- Get the raw path for use in other commands ---
Type "j -g proj"
Enter
Sleep 1.8s

# --- Rename an alias ---
Type "j -r web frontend"
Enter
Sleep 1s

# --- Show updated list ---
Type "j"
Enter
Sleep 2.5s

# --- Delete an alias ---
Type "j -d logs"
Enter
Sleep 800ms
Type "j"
Enter
Sleep 2.5s
